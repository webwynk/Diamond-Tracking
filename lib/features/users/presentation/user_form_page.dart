import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_error_view.dart';
import '../../../shared/widgets/form_message.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/auth_status.dart';
import '../../auth/domain/credentials.dart';
import '../application/users_providers.dart';
import '../data/users_repository.dart';
import '../domain/profile.dart';
import '../domain/temp_pin.dart';
import 'pin_dialog.dart';

/// Add a user (with a temporary PIN), or edit one when [userId] is set.
class UserFormPage extends ConsumerWidget {
  const UserFormPage({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = userId;
    if (id == null) return const _UserForm(initial: null);
    return ref
        .watch(userByIdProvider(id))
        .when(
          data: (Profile? user) => user == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: Center(child: Text(AuthFailure.userNotFound.message)),
                )
              : _UserForm(initial: user),
          error: (_, _) => Scaffold(
            appBar: AppBar(),
            body: AppErrorView(
              onRetry: () => ref.invalidate(userByIdProvider(id)),
            ),
          ),
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
        );
  }
}

class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({required this.initial});

  final Profile? initial;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _userCode;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _pin;
  late AppRole _role;
  late bool _active;
  bool _busy = false;
  AuthFailure? _failure;
  Map<String, String> _serverErrors = const <String, String>{};

  bool get _isNew => widget.initial == null;

  bool get _isSelf {
    final AuthStatus status = ref.watch(authStatusProvider);
    return status is SignedIn && status.userId == widget.initial?.id;
  }

  @override
  void initState() {
    super.initState();
    final Profile? p = widget.initial;
    _userCode = TextEditingController(text: p?.userCode ?? '');
    _name = TextEditingController(text: p?.fullName ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.contactEmail ?? '');
    _pin = TextEditingController(text: generateTempPin());
    _role = p?.role ?? AppRole.employee;
    _active = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _userCode.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _pin.dispose();
    super.dispose();
  }

  ProfileDraft get _draft => ProfileDraft(
    userCode: _userCode.text,
    fullName: _name.text,
    phone: _phone.text,
    contactEmail: _email.text,
    role: _role,
    isActive: _active,
  );

  /// Runs [action]; returns false (and shows why) when it fails.
  Future<bool> _run(Future<void> Function(UsersRepository repo) action) async {
    if (_busy) return false;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action(ref.read(usersRepositoryProvider));
      return true;
    } on FieldErrors catch (e) {
      _showServerErrors(e.fields);
    } on AuthFailure catch (failure) {
      if (failure == AuthFailure.userCodeTaken) {
        _showServerErrors(<String, String>{'user_code': failure.message});
      } else if (mounted) {
        setState(() => _failure = failure);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  void _showServerErrors(Map<String, String> fields) {
    if (!mounted) return;
    _serverErrors = fields;
    _form.currentState?.validate();
    if (fields.isEmpty) setState(() => _failure = AuthFailure.unknown);
  }

  /// The field's own check first, then what the server said about it.
  FormFieldValidator<String> _check(
    String key,
    FormFieldValidator<String> local,
  ) =>
      (String? v) => local(v) ?? _serverErrors[key];

  bool _validate() {
    _serverErrors = const <String, String>{};
    return _form.currentState?.validate() ?? false;
  }

  Future<void> _save() async {
    if (_busy || !_validate()) return;
    if (_isNew) {
      final String pin = _pin.text;
      Profile? created;
      final bool ok = await _run((UsersRepository repo) async {
        created = await repo.create(_draft, tempPin: pin);
      });
      if (!ok || !mounted) return;
      ref.invalidate(usersListProvider);
      await showPinDialog(
        context,
        title: 'User added',
        userCode: created!.userCode,
        pin: pin,
      );
      if (mounted) context.pop();
    } else {
      final String id = widget.initial!.id;
      final bool ok = await _run(
        (UsersRepository repo) => repo.update(id, _draft),
      );
      if (!ok || !mounted) return;
      ref
        ..invalidate(usersListProvider)
        ..invalidate(userByIdProvider(id));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
      context.pop();
    }
  }

  Future<void> _resetPassword() async {
    final Profile user = widget.initial!;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Reset password for ${user.fullName}?'),
        content: const Text(
          'Their phone is signed out, and they sign in again with a new '
          'temporary PIN. Use this when they forgot their password or changed '
          'phones.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    final String pin = generateTempPin();
    final bool done = await _run(
      (UsersRepository repo) => repo.resetPin(user.id, tempPin: pin),
    );
    if (!done || !mounted) return;
    await showPinDialog(
      context,
      title: 'Password reset',
      userCode: user.userCode,
      pin: pin,
    );
    // Refreshes "signed in on a phone" after the dialog closes.
    ref
      ..invalidate(usersListProvider)
      ..invalidate(userByIdProvider(user.id));
  }

  String? _optionalPhone(String? v) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(s)
        ? null
        : 'Use 7 to 15 digits, with + in front if needed';
  }

  String? _optionalEmail(String? v) {
    final String s = (v ?? '').trim();
    if (s.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) && s.length <= 120
        ? null
        : 'Enter a valid email';
  }

  @override
  Widget build(BuildContext context) {
    final bool self = !_isNew && _isSelf;
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Add user' : 'Edit user')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _userCode,
                  enabled: _isNew,
                  decoration: InputDecoration(
                    labelText: 'User ID',
                    helperText: _isNew
                        ? 'Used to sign in. It cannot be changed later.'
                        : 'The user ID cannot be changed.',
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  validator: _check(
                    'user_code',
                    (String? v) => _isNew ? userCodeProblem(v ?? '') : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  textCapitalization: TextCapitalization.words,
                  validator: _check('full_name', (String? v) {
                    final int n = (v ?? '').trim().length;
                    return n < 1 || n > 80 ? 'Enter a name (up to 80)' : null;
                  }),
                ),
                const SizedBox(height: AppSpacing.x4),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: _check('phone', _optionalPhone),
                ),
                const SizedBox(height: AppSpacing.x4),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    helperText:
                        'Needed to reset a forgotten password by email.',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: _check('contact_email', _optionalEmail),
                ),
                const SizedBox(height: AppSpacing.x5),
                const Text('Role', style: AppTypography.label),
                const SizedBox(height: AppSpacing.x2),
                SegmentedButton<AppRole>(
                  segments: const <ButtonSegment<AppRole>>[
                    ButtonSegment<AppRole>(
                      value: AppRole.employee,
                      label: Text('Employee'),
                      icon: Icon(Icons.person_rounded),
                    ),
                    ButtonSegment<AppRole>(
                      value: AppRole.admin,
                      label: Text('Admin'),
                      icon: Icon(Icons.admin_panel_settings_rounded),
                    ),
                  ],
                  selected: <AppRole>{_role},
                  onSelectionChanged: self || _busy
                      ? null
                      : (Set<AppRole> s) => setState(() => _role = s.first),
                ),
                if (!_isNew) ...<Widget>[
                  const SizedBox(height: AppSpacing.x2),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Account on'),
                    subtitle: Text(
                      self
                          ? 'You cannot turn off your own account.'
                          : 'When off, the user cannot sign in.',
                    ),
                    value: _active,
                    onChanged: self || _busy
                        ? null
                        : (bool v) => setState(() => _active = v),
                  ),
                ],
                if (_isNew) ...<Widget>[
                  const SizedBox(height: AppSpacing.x5),
                  TextFormField(
                    controller: _pin,
                    decoration: InputDecoration(
                      labelText: 'Temporary PIN',
                      helperText:
                          'The user signs in with this once, then chooses a '
                          'password.',
                      suffixIcon: IconButton(
                        tooltip: 'New PIN',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: () =>
                            setState(() => _pin.text = generateTempPin()),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    validator: _check(
                      'temp_pin',
                      (String? v) => pinProblem(v ?? ''),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.x5),
                if (_failure != null) ...<Widget>[
                  FormMessage.error(_failure!.message),
                  const SizedBox(height: AppSpacing.x4),
                ],
                AppButton(
                  label: _isNew ? 'Add user' : 'Save',
                  loadingLabel: 'Saving',
                  isLoading: _busy,
                  isFullWidth: true,
                  onPressed: _save,
                ),
                if (!_isNew && !self) ...<Widget>[
                  const SizedBox(height: AppSpacing.x8),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    widget.initial!.hasPhoneSignedIn
                        ? 'Signed in on a phone now.'
                        : 'Not signed in on any phone.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  AppButton(
                    label: 'Reset password',
                    variant: AppButtonVariant.secondary,
                    icon: const Icon(Icons.lock_reset_rounded, size: 18),
                    isFullWidth: true,
                    onPressed: _busy ? null : _resetPassword,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
