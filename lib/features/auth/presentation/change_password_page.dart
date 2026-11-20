import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/form_message.dart';
import '../../../shared/widgets/password_field.dart';
import '../application/auth_providers.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';

/// A signed-in user changes their password, confirming the current one.
class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _current.dispose();
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
      if (mounted) {
        setState(
          () => _failure = failure == AuthFailure.invalidCredentials
              ? AuthFailure.wrongCurrentPassword
              : failure,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userCode =
        ref.read(authRepositoryProvider).currentUserCode ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.x5),
          child: AutofillGroup(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  PasswordField(
                    controller: _current,
                    label: 'Current password',
                    validator: (String? v) => (v ?? '').isEmpty
                        ? 'Enter your current password'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  PasswordField(
                    controller: _password,
                    label: 'New password',
                    helperText:
                        'At least 8 characters, with a letter and a digit.',
                    autofillHints: const <String>[AutofillHints.newPassword],
                    validator: (String? v) {
                      final String value = v ?? '';
                      if (value == _current.text) {
                        return 'The new password must be different';
                      }
                      return passwordProblem(value, userCode: userCode);
                    },
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  PasswordField(
                    controller: _confirm,
                    label: 'Repeat new password',
                    autofillHints: const <String>[AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (String? v) => v == _password.text
                        ? null
                        : 'The passwords do not match',
                  ),
                  const SizedBox(height: AppSpacing.x4),
                  if (_failure != null) ...<Widget>[
                    FormMessage.error(_failure!.message),
                    const SizedBox(height: AppSpacing.x4),
                  ],
                  AppButton(
                    label: 'Change password',
                    loadingLabel: 'Saving',
                    isLoading: _busy,
                    isFullWidth: true,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
