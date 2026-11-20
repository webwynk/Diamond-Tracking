import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../shared/widgets/password_field.dart';
import '../application/auth_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';
import 'widgets/auth_scaffold.dart';

/// After signing in with a temporary PIN, the user picks their own password.
class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      // On success the app moves on to the home screen by itself.
      await ref.read(authRepositoryProvider).setFirstPassword(_password.text);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userCode =
        ref.read(authRepositoryProvider).currentUserCode ?? '';
    return AuthScaffold(
      title: 'Choose your password',
      subtitle:
          'You signed in with a temporary PIN. Choose your own password to '
          'continue.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PasswordField(
                controller: _password,
                label: 'New password',
                helperText: 'At least 8 characters, with a letter and a digit.',
                autofillHints: const <String>[AutofillHints.newPassword],
                validator: (String? v) =>
                    passwordProblem(v ?? '', userCode: userCode),
              ),
              const SizedBox(height: AppSpacing.x4),
              PasswordField(
                controller: _confirm,
                label: 'Repeat new password',
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (String? v) =>
                    v == _password.text ? null : 'The passwords do not match',
              ),
              const SizedBox(height: AppSpacing.x4),
              if (_failure != null) ...<Widget>[
                FormMessage.error(_failure!.message),
                const SizedBox(height: AppSpacing.x4),
              ],
              AppButton(
                label: 'Save password',
                loadingLabel: 'Saving',
                isLoading: _busy,
                isFullWidth: true,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.x2),
              AppButton(
                label: 'Log out',
                variant: AppButtonVariant.tertiary,
                isFullWidth: true,
                onPressed: _busy
                    ? null
                    : () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
