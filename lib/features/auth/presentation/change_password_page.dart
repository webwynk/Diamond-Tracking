import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/ds_icons.dart';
import '../../../shared/ds/ds_auth_frame.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../application/auth_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';

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
  String? _passwordError;
  String? _confirmError;
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
    final String? passwordError = _password.text == _current.text
        ? 'The new password must be different'
        : passwordProblem(_password.text, userCode: userCode);
    final String? confirmError = _confirm.text == _password.text
        ? null
        : 'The passwords do not match';
    setState(() {
      _currentError = currentError;
      _passwordError = passwordError;
      _confirmError = confirmError;
      _failure = null;
    });
    if (currentError != null || passwordError != null || confirmError != null) {
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password changed')));
      context.pop();
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

  @override
  Widget build(BuildContext context) {
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
              DsTextField(
                label: 'New password',
                controller: _password,
                hint: '8+ characters, a letter and a digit',
                icon: DsIcons.lock,
                password: true,
                error: _passwordError,
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              DsTextField(
                label: 'Repeat new password',
                controller: _confirm,
                icon: DsIcons.lock,
                password: true,
                error: _confirmError,
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
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
