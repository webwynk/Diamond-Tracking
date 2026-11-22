import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_icons.dart';
import '../../../shared/ds/ds_auth_frame.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../application/auth_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_status.dart';
import 'password_done_dialog.dart';
import 'password_rules.dart';

/// A signed-in user changes their password, confirming the current one
/// (design v2, Change password). Used by employees and admins.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  String? _currentError;

  /// Save was pressed; cleared on the next edit (see NewPasswordFields).
  bool _tried = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final String userCode =
        ref.read(authRepositoryProvider).currentUserCode ?? '';
    final String? currentError = _current.text.isEmpty
        ? 'Enter your current password'
        : null;
    final ({String? password, String? confirm}) problems = newPasswordProblems(
      _password.text,
      _confirm.text,
      userCode: userCode,
      extra: _differentFromCurrent,
    );
    setState(() {
      _currentError = currentError;
      _tried = true;
      _failure = null;
    });
    if (currentError != null ||
        problems.password != null ||
        problems.confirm != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      setState(() => _busy = false);
      await showPasswordDone(context, PasswordDone.changed);
      if (!mounted) return;
      context.go(_admin ? Routes.adminDashboard : Routes.userHome);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        if (failure == AuthFailure.invalidCredentials) {
          // Shown on the field it is about (design v2).
          _currentError = "That's not your current password.";
        } else {
          _failure = failure;
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _differentFromCurrent(String password) =>
      password == _current.text ? 'The new password must be different' : null;

  void _edited() {
    if (_tried || _failure != null) {
      setState(() {
        _tried = false;
        _failure = null;
      });
    }
  }

  /// Admins go home to the dashboard. Watched in build, so it is known by
  /// the time the password is changed.
  bool _admin = false;

  @override
  Widget build(BuildContext context) {
    final AuthStatus status = ref.watch(authStatusProvider);
    _admin = status is SignedIn && status.role == AppRole.admin;
    final String userCode =
        ref.read(authRepositoryProvider).currentUserCode ?? '';
    return DsAuthFrame(
      title: 'Change password.',
      accent: 'Keep your account safe.',
      subtitle: 'Confirm the old one, then pick a new one.',
      onBack: _busy ? null : () => context.pop(),
      footer: const Text('Forgot it? Log out and use "Forgot password?"'),
      children: <Widget>[
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DsTextField(
                label: 'Current password',
                controller: _current,
                icon: DsIcons.lock,
                password: true,
                error: _currentError,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              NewPasswordFields(
                password: _password,
                confirm: _confirm,
                userCode: userCode,
                tried: _tried,
                onEdited: _edited,
                showExample: false,
                extra: _differentFromCurrent,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        if (_failure != null)
          DsBanner(kind: DsBannerKind.danger, title: _failure!.message),
        DsButton(
          label: 'Change password',
          busyLabel: 'Saving',
          busy: _busy,
          arrow: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}
