import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../shared/widgets/password_field.dart';
import '../application/auth_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';
import 'widgets/auth_scaffold.dart';

/// Sign in with user ID and password. The first admin, whose account was made
/// in Supabase, types their email instead. Admins added in the app use their
/// user ID; their contact email is not a sign-in name.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _loginId = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _loginId.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
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
    return AuthScaffold(
      title: 'Sign in',
      subtitle: 'Use the user ID your admin gave you.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _loginId,
                decoration: const InputDecoration(labelText: 'User ID'),
                autofillHints: const <String>[AutofillHints.username],
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                validator: (String? v) => loginIdProblem(v ?? ''),
              ),
              const SizedBox(height: AppSpacing.x4),
              PasswordField(
                controller: _password,
                label: 'Password',
                helperText: 'First time? Use the temporary PIN.',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (String? v) =>
                    (v ?? '').isEmpty ? 'Enter your password' : null,
              ),
              const SizedBox(height: AppSpacing.x4),
              if (_failure != null) ...<Widget>[
                FormMessage.error(_failure!.message),
                const SizedBox(height: AppSpacing.x4),
              ],
              AppButton(
                label: 'Sign in',
                loadingLabel: 'Signing in',
                isLoading: _busy,
                isFullWidth: true,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.x2),
              AppButton(
                label: 'Forgot password?',
                variant: AppButtonVariant.tertiary,
                isFullWidth: true,
                onPressed: _busy
                    ? null
                    : () => context.push(Routes.forgotPassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
