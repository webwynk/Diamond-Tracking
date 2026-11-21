import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../shared/ds/ds_auth_frame.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../application/auth_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';

/// Sign in with user ID and password (design v2, Sign in). The first admin,
/// whose account was made in Supabase, types their email instead. Admins
/// added in the app use their user ID; their contact email is not a sign-in
/// name.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _loginId = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _idError;
  String? _passwordError;
  AuthFailure? _failure;

  @override
  void dispose() {
    _loginId.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final String? idError = loginIdProblem(_loginId.text);
    final String? passwordError = _password.text.isEmpty
        ? 'Enter your password or PIN'
        : null;
    setState(() {
      _idError = idError;
      _passwordError = passwordError;
      _failure = null;
    });
    if (idError != null || passwordError != null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authStatusProvider.notifier)
          .holdWhile(
            () => ref
                .read(authRepositoryProvider)
                .signIn(loginId: _loginId.text, password: _password.text),
          );
      TextInput.finishAutofillContext();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DsAuthFrame(
      title: 'Good to see you.',
      accent: "Let's start the day.",
      subtitle: 'Sign in with the user ID from your admin.',
      footer: const _OnePhone(),
      children: <Widget>[
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DsTextField(
                label: 'User ID',
                controller: _loginId,
                hint: 'EMP007',
                icon: DsIcons.profile,
                error: _idError,
                autofillHints: const <String>[AutofillHints.username],
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_idError != null) setState(() => _idError = null);
                },
              ),
              const SizedBox(height: 14),
              DsTextField(
                label: 'Password or PIN',
                controller: _password,
                hint: 'First time? Your temporary PIN',
                icon: DsIcons.lock,
                password: true,
                error: _passwordError,
                autofillHints: const <String>[AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: DsTextLink(
            label: 'Forgot password?',
            onPressed: _busy ? null : () => context.push(Routes.forgotPassword),
          ),
        ),
        if (_failure != null)
          DsBanner(kind: DsBannerKind.danger, title: _failure!.message),
        DsButton(
          label: 'Sign in',
          busyLabel: 'Signing in',
          busy: _busy,
          arrow: true,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _OnePhone extends StatelessWidget {
  const _OnePhone();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: DsColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        const Text('One phone per account'),
      ],
    );
  }
}
