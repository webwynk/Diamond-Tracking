import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/auth_status.dart';
import '../../auth/domain/credentials.dart';
import '../application/users_providers.dart';
import '../data/users_repository.dart';
import '../domain/profile.dart';
import '../domain/temp_pin.dart';
import 'pin_dialog.dart';

/// The country code shown in front of the phone field.
const String phonePrefix = '+91';

/// The phone as typed, saved with +91 in front unless it already has a
/// country code. Empty stays empty.
String phoneToSave(String typed) {
  final String s = typed.replaceAll(RegExp(r'[\s-]'), '');
  if (s.isEmpty || s.startsWith('+')) return s;
  return '$phonePrefix$s';
}

/// A saved phone for the field: without the +91 shown in front of it.
String phoneToEdit(String? saved) {
  final String s = (saved ?? '').trim();
  return s.startsWith(phonePrefix) ? s.substring(phonePrefix.length) : s;
}

/// "Create user" or "Edit details" (design v2). Creating gives a temporary
/// PIN, shown once afterwards.
class UserFormPage extends ConsumerWidget {
  const UserFormPage({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = userId;
    if (id == null) return const _UserForm(initial: null);
    final AsyncValue<Profile?> user = ref.watch(userByIdProvider(id));
    final Profile? p = user.value;
    if (p != null) return _UserForm(key: ValueKey<String>(p.id), initial: p);
    return Scaffold(
      backgroundColor: DsColors.surface,
      appBar: AppBar(backgroundColor: DsColors.surface),
      body: user.hasError
          ? DsErrorState(
              title: "Couldn't load this person",
              message: 'Check the internet and try again.',
              onRetry: () => ref.invalidate(userByIdProvider(id)),
            )
          : user.isLoading
          ? const Center(child: CircularProgressIndicator())
          : DsEmptyState(
              title: 'Not found',
              message: AuthFailure.userNotFound.message,
              icon: DsIcons.profile,
            ),
    );
  }
}

class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({required this.initial, super.key});

  final Profile? initial;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  late final TextEditingController _userCode;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late String _pin;
  late AppRole _role;
  late bool _active;
  bool _busy = false;
  AuthFailure? _failure;

  /// Problems by field: user_code, full_name, phone, contact_email,
  /// temp_pin. Local checks first, then what the server said.
  Map<String, String> _errors = const <String, String>{};

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
    _phone = TextEditingController(text: phoneToEdit(p?.phone));
    _email = TextEditingController(text: p?.contactEmail ?? '');
    _pin = generateTempPin();
    _role = p?.role ?? AppRole.employee;
    _active = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _userCode.dispose();
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  ProfileDraft get _draft => ProfileDraft(
    userCode: _userCode.text.trim(),
    fullName: _name.text.trim(),
    phone: phoneToSave(_phone.text),
    contactEmail: _email.text.trim(),
    role: _role,
    isActive: _active,
  );

  bool _validate() {
    final Map<String, String> e = <String, String>{
      if (_isNew)
        if (userCodeProblem(_userCode.text) case final String m) 'user_code': m,
      if (_isNew && _codeTaken(_userCode.text))
        'user_code': AuthFailure.userCodeTaken.message,
      if (nameProblem(_name.text) case final String m) 'full_name': m,
      if (phoneProblem(phoneToSave(_phone.text)) case final String m)
        'phone': m,
      if (emailProblem(_email.text) case final String m) 'contact_email': m,
      if (_isNew)
        if (pinProblem(_pin) case final String m) 'temp_pin': m,
    };
    setState(() => _errors = e);
    return e.isEmpty;
  }

  /// The user ID is already used (any letter case), from the team list.
  bool _codeTaken(String code) {
    final String c = code.trim().toLowerCase();
    if (c.isEmpty) return false;
    return (ref.read(usersListProvider).value ?? const <Profile>[]).any(
      (Profile p) => p.userCode.toLowerCase() == c,
    );
  }

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
      if (mounted) {
        setState(() {
          _errors = e.fields;
          if (e.fields.isEmpty) _failure = AuthFailure.unknown;
        });
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          if (failure == AuthFailure.userCodeTaken) {
            _errors = <String, String>{'user_code': failure.message};
          } else {
            _failure = failure;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<void> _save() async {
    if (_busy || !_validate()) return;
    if (_isNew) {
      final String pin = _pin;
      Profile? created;
      final bool ok = await _run((UsersRepository repo) async {
        created = await repo.create(_draft, tempPin: pin);
      });
      if (!ok || !mounted) return;
      ref.invalidate(usersListProvider);
      final Profile c = created!;
      await showPinDialog(
        context,
        title: '${c.fullName} added',
        message:
            'Give these to ${firstNameOf(c.fullName) ?? 'them'}. On first '
            'sign-in they choose their own password.',
        userCode: c.userCode,
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

  @override
  Widget build(BuildContext context) {
    final bool self = !_isNew && _isSelf;
    final Profile? p = widget.initial;
    // Keeps the team list loaded for the "Free / Taken" check.
    if (_isNew) ref.watch(usersListProvider);
    final String first = firstNameOf(_name.text) ?? 'they';
    return Scaffold(
      backgroundColor: DsColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DsSpace.gutter,
                  DsSpace.md,
                  DsSpace.gutter,
                  DsSpace.xl,
                ),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      DsIconButton(
                        icon: DsIcons.close,
                        label: _isNew
                            ? 'Close without creating'
                            : 'Close without saving',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Semantics(
                              header: true,
                              child: Text(
                                _isNew ? 'Create user' : 'Edit details',
                                style: DsText.title,
                              ),
                            ),
                            if (_isNew)
                              const Text(
                                'They get a temporary PIN to sign in',
                                style: DsText.caption,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_isNew)
                    _Section(
                      title: 'Sign-in ID',
                      children: <Widget>[
                        _UserIdField(
                          controller: _userCode,
                          error: _errors['user_code'],
                          taken: _codeTaken(_userCode.text),
                          onChanged: (_) => setState(
                            () =>
                                _errors = Map<String, String>.of(_errors)
                                  ..remove('user_code'),
                          ),
                        ),
                      ],
                    )
                  else
                    _Who(profile: p!),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Personal details',
                    children: <Widget>[
                      DsTextField(
                        label: 'Full name',
                        controller: _name,
                        icon: DsIcons.profile,
                        hint: 'For example Bikash Halder',
                        error: _errors['full_name'],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      DsTextField(
                        label: 'Phone',
                        optional: true,
                        controller: _phone,
                        prefixText: phonePrefix,
                        hint: '10-digit mobile',
                        keyboardType: TextInputType.phone,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+ -]'),
                          ),
                        ],
                        error: _errors['phone'],
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      DsTextField(
                        label: 'Email',
                        optional: true,
                        controller: _email,
                        icon: DsIcons.mail,
                        hint: 'name@example.com',
                        keyboardType: TextInputType.emailAddress,
                        error: _errors['contact_email'],
                        helper: _isNew
                            ? 'Lets them reset a forgotten password by email.'
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (!_isNew &&
                          _email.text.trim().isEmpty &&
                          _errors['contact_email'] == null) ...<Widget>[
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            const Icon(
                              DsIcons.error,
                              size: 14,
                              color: DsColors.warningText,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Add it so $first can reset a forgotten '
                                'password.',
                                style: DsText.caption.copyWith(
                                  color: DsColors.warningText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  _Section(
                    title: 'Role',
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: _RoleCard(
                              icon: DsIcons.pin,
                              label: 'Employee',
                              help: 'Duty on, map and dealer visits',
                              selected: _role == AppRole.employee,
                              onTap: self || _busy
                                  ? null
                                  : () => setState(
                                      () => _role = AppRole.employee,
                                    ),
                            ),
                          ),
                          const SizedBox(width: DsSpace.sm),
                          Expanded(
                            child: _RoleCard(
                              icon: DsIcons.admin,
                              label: 'Admin',
                              help: 'Manages team, requests and reports',
                              selected: _role == AppRole.admin,
                              onTap: self || _busy
                                  ? null
                                  : () => setState(() => _role = AppRole.admin),
                            ),
                          ),
                        ],
                      ),
                      if (self) ...<Widget>[
                        const SizedBox(height: DsSpace.sm),
                        const Text(
                          'You cannot change your own role.',
                          style: DsText.caption,
                        ),
                      ],
                    ],
                  ),
                  if (!_isNew) ...<Widget>[
                    const SizedBox(height: 14),
                    _AccountSwitch(
                      on: _active,
                      self: self,
                      onChanged: self || _busy
                          ? null
                          : (bool v) => setState(() => _active = v),
                    ),
                  ],
                  if (_isNew) ...<Widget>[
                    const SizedBox(height: 14),
                    _PinCard(
                      pin: _pin,
                      error: _errors['temp_pin'],
                      onNew: _busy
                          ? null
                          : () => setState(() => _pin = generateTempPin()),
                    ),
                  ],
                  if (_failure case final AuthFailure f) ...<Widget>[
                    const SizedBox(height: 14),
                    DsBanner(kind: DsBannerKind.danger, title: f.message),
                  ],
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                DsSpace.gutter,
                12,
                DsSpace.gutter,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: const BoxDecoration(
                color: DsColors.white,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0F0F172A),
                    blurRadius: 24,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 110,
                    child: DsButton(
                      label: 'Cancel',
                      kind: DsButtonKind.secondary,
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DsButton(
                      label: _isNew ? 'Create user' : 'Save changes',
                      icon: _isNew ? DsIcons.add : DsIcons.check,
                      busy: _busy,
                      busyLabel: 'Saving…',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DsSpace.lg),
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            style: DsText.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: DsSpace.md),
        ...children,
      ],
    ),
  );
}

/// The user ID, big, with "Free" or "Taken" on the right.
class _UserIdField extends StatelessWidget {
  const _UserIdField({
    required this.controller,
    required this.error,
    required this.taken,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? error;
  final bool taken;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool ok =
        controller.text.trim().isNotEmpty &&
        userCodeProblem(controller.text) == null;
    final String? e = error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          height: 56,
          padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
          decoration: BoxDecoration(
            color: DsColors.surface,
            borderRadius: DsRadius.medium,
            border: e == null
                ? null
                : Border.all(color: DsColors.dangerText, width: 1.5),
          ),
          child: Row(
            children: <Widget>[
              const Icon(DsIcons.idCard, size: 18, color: DsColors.text2),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  label: 'User ID',
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9_-]'),
                      ),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    style: DsText.section.copyWith(letterSpacing: 0.6),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      filled: false,
                      hintText: 'For example EMP025',
                    ),
                  ),
                ),
              ),
              if (ok)
                DsStatusPillLite(
                  label: taken ? 'Taken' : 'Free',
                  status: taken ? DsStatus.absent : DsStatus.present,
                  icon: taken ? DsIcons.close : DsIcons.check,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (e != null)
          Text(e, style: DsText.caption.copyWith(color: DsColors.dangerText))
        else
          Text.rich(
            const TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: 'Used to sign in. 2–20 letters, digits, - or _. ',
                ),
                TextSpan(
                  text: "It can't be changed later.",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
            style: DsText.caption.copyWith(height: 1.4),
          ),
      ],
    );
  }
}

/// A small tinted pill with an icon: "✓ Free", "✕ Taken".
class DsStatusPillLite extends StatelessWidget {
  const DsStatusPillLite({
    required this.label,
    required this.status,
    required this.icon,
    super.key,
  });

  final String label;
  final DsStatus status;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: status.tint, borderRadius: DsRadius.pill),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: status.text),
        const SizedBox(width: 4),
        Text(
          label,
          style: DsText.caption.copyWith(
            color: status.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

/// Edit: initials, name and "EMP003 · user ID can't change".
class _Who extends StatelessWidget {
  const _Who({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DsStatus.present.tint,
            shape: BoxShape.circle,
          ),
          child: Text(
            initialsOf(profile.fullName),
            style: DsText.section.copyWith(color: DsStatus.present.text),
          ),
        ),
        const SizedBox(width: DsSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                profile.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsText.section,
              ),
              const SizedBox(height: DsSpace.xs),
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFEEF2F6),
                  borderRadius: DsRadius.pill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      DsIcons.lock,
                      size: 12,
                      color: Color(0xFF334155),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        "${profile.userCode} · user ID can't change",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DsText.caption.copyWith(
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.help,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String help;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    selected: selected,
    enabled: onTap != null,
    label: '$label. $help',
    excludeSemantics: true,
    child: Opacity(
      opacity: onTap == null && !selected ? 0.55 : 1,
      child: Material(
        color: selected ? DsColors.primaryTint : DsColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: DsRadius.large,
          side: selected
              ? const BorderSide(color: DsColors.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected ? DsColors.primary : DsColors.white,
                        borderRadius: DsRadius.medium,
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: selected ? DsColors.white : DsColors.text2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(help, style: DsText.caption.copyWith(height: 1.35)),
                  ],
                ),
                if (selected)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: DsColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        DsIcons.check,
                        size: 12,
                        color: DsColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Edit: "Account on" with a green switch.
class _AccountSwitch extends StatelessWidget {
  const _AccountSwitch({
    required this.on,
    required this.self,
    required this.onChanged,
  });

  final bool on;
  final bool self;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final DsStatus t = on ? DsStatus.present : DsStatus.absent;
    return Container(
      padding: const EdgeInsets.all(DsSpace.lg),
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.large,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: t.tint,
              borderRadius: DsRadius.medium,
            ),
            child: Icon(DsIcons.dayDone, size: 20, color: t.text),
          ),
          const SizedBox(width: DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Account on',
                  style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  self
                      ? 'You cannot turn off your own account.'
                      : on
                      ? 'Can sign in and do duty on'
                      : "Can't sign in until turned back on",
                  style: DsText.caption.copyWith(
                    color: self ? DsColors.text2 : t.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Account on',
            child: Switch(
              value: on,
              activeTrackColor: DsColors.successDot,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Create: the temporary PIN as six boxes, with "New PIN".
class _PinCard extends StatelessWidget {
  const _PinCard({required this.pin, required this.error, required this.onNew});

  final String pin;
  final String? error;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DsSpace.lg),
    decoration: const BoxDecoration(
      color: DsColors.primaryTint,
      borderRadius: DsRadius.large,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Temporary PIN',
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DsColors.deep,
                  ),
                ),
              ),
            ),
            Semantics(
              container: true,
              button: true,
              label: 'New PIN',
              excludeSemantics: true,
              child: Material(
                color: DsColors.white,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onNew,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          DsIcons.retry,
                          size: 14,
                          color: DsColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'New PIN',
                          style: DsText.caption.copyWith(
                            color: DsColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.md),
        PinBoxes(pin: pin, boxColour: DsColors.white),
        const SizedBox(height: DsSpace.md),
        Text(
          error ??
              'They sign in with this once, then choose their own password. '
                  "You'll see it again on the next screen to copy.",
          style: DsText.caption.copyWith(
            height: 1.4,
            color: error == null ? DsColors.deep : DsColors.dangerText,
          ),
        ),
      ],
    ),
  );
}
