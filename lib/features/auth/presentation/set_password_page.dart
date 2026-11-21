import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_icons.dart';
import '../../../shared/ds/ds_auth_frame.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';
import 'password_rules.dart';

/// After signing in with a temporary PIN, the user picks their own password
/// (design v2, Choose your password).
class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  String? _passwordError;
  String? _confirmError;
  AuthFailure? _failure;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(String userCode) async {
    if (_busy) return;
    final String? passwordError = passwordProblem(
      _password.text,
      userCode: userCode,
    );
    final String? confirmError = _confirm.text == _password.text
        ? null
        : 'The passwords do not match';
    setState(() {
      _passwordError = passwordError;
      _confirmError = confirmError;
      _failure = null;
    });
    if (passwordError != null || confirmError != null) return;
    setState(() => _busy = true);
    try {
      // On success the app moves on to the home screen by itself.
      await ref.read(authRepositoryProvider).setFirstPassword(_password.text);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logOut() => ref
      .read(authStatusProvider.notifier)
      .signOutWith(() => ref.read(authRepositoryProvider).signOut());

  @override
  Widget build(BuildContext context) {
    final AuthRepository auth = ref.read(authRepositoryProvider);
    final String userCode = auth.currentUserCode ?? '';
    final String? name = auth.currentFirstName;
    return DsAuthFrame(
      title: name == null ? 'Welcome.' : 'Welcome, $name.',
      accent: 'Choose your password.',
      subtitle: 'Pick one only you know.',
      footer: DsTextLink(
        label: 'Not you? Log out',
        onPressed: _busy ? null : _logOut,
      ),
      children: <Widget>[
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
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
              const SizedBox(height: 10),
              PasswordRules(controller: _password, userCode: userCode),
              const SizedBox(height: 14),
              DsTextField(
                label: 'Repeat new password',
                controller: _confirm,
                icon: DsIcons.lock,
                password: true,
                error: _confirmError,
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(userCode),
              ),
            ],
          ),
        ),
        if (_failure != null)
          DsBanner(kind: DsBannerKind.danger, title: _failure!.message),
        DsButton(
          label: 'Save and continue',
          busyLabel: 'Saving',
          busy: _busy,
          arrow: true,
          onPressed: () => _submit(userCode),
        ),
      ],
    );
  }
}
