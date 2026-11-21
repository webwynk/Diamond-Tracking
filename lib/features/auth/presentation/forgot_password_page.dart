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

enum _Step { enterUserId, enterCode, done }

/// Forgotten password: a 6-digit code goes to the email on the user's
/// profile, then the user sets a new password with it.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _userCode = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  _Step _step = _Step.enterUserId;
  bool _busy = false;
  AuthFailure? _failure;
  String? _note;

  @override
  void dispose() {
    _userCode.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
      _note = null;
    });
    try {
      await action();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
      await ref.read(authRepositoryProvider).requestResetCode(_userCode.text);
      if (!mounted) return;
      setState(() {
        _step = _Step.enterCode;
        _note =
            'If this user ID has an email, a code is on its way. It works '
            'for 15 minutes. You can ask for up to 5 codes a day.';
      });
    });
  }

  Future<void> _reset() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .resetWithCode(
            userCode: _userCode.text,
            code: _code.text,
            newPassword: _password.text,
          );
      if (mounted) setState(() => _step = _Step.done);
    });
  }

  void _toLogin() =>
      context.canPop() ? context.pop() : context.go(Routes.login);

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: switch (_step) {
        _Step.enterUserId => 'Forgot password',
        _Step.enterCode => 'Enter the code',
        _Step.done => 'Password changed',
      },
      subtitle: switch (_step) {
        _Step.enterUserId =>
          'We will email a code to the address your admin saved for you. '
              'No email saved? Ask your admin to reset your password.',
        _Step.enterCode => 'Check your email for a 6-digit code.',
        _Step.done =>
          'Sign in with your new password. Any phone that was signed in has '
              'been signed out.',
      },
      onBack: _busy ? null : _toLogin,
      child: Form(key: _form, child: _body()),
    );
  }

  Widget _body() {
    final List<Widget> messages = <Widget>[
      if (_note != null) ...<Widget>[
        FormMessage.success(_note!),
        const SizedBox(height: AppSpacing.x4),
      ],
      if (_failure != null) ...<Widget>[
        FormMessage.error(_failure!.message),
        const SizedBox(height: AppSpacing.x4),
      ],
    ];
    switch (_step) {
      case _Step.enterUserId:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _userCode,
              decoration: const InputDecoration(labelText: 'User ID'),
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendCode(),
              validator: (String? v) => userCodeProblem(v ?? ''),
            ),
            const SizedBox(height: AppSpacing.x4),
            ...messages,
            AppButton(
              label: 'Send code',
              loadingLabel: 'Sending',
              isLoading: _busy,
              isFullWidth: true,
              onPressed: _sendCode,
            ),
          ],
        );
      case _Step.enterCode:
        return AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(labelText: '6-digit code'),
                keyboardType: TextInputType.number,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textInputAction: TextInputAction.next,
                validator: (String? v) =>
                    RegExp(r'^[0-9]{6}$').hasMatch(v ?? '')
                    ? null
                    : 'Enter the 6 digits from the email',
              ),
              const SizedBox(height: AppSpacing.x4),
              PasswordField(
                controller: _password,
                label: 'New password',
                helperText: 'At least 8 characters, with a letter and a digit.',
                autofillHints: const <String>[AutofillHints.newPassword],
                validator: (String? v) =>
                    passwordProblem(v ?? '', userCode: _userCode.text.trim()),
              ),
              const SizedBox(height: AppSpacing.x4),
              PasswordField(
                controller: _confirm,
                label: 'Repeat new password',
                autofillHints: const <String>[AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _reset(),
                validator: (String? v) =>
                    v == _password.text ? null : 'The passwords do not match',
              ),
              const SizedBox(height: AppSpacing.x4),
              ...messages,
              AppButton(
                label: 'Set new password',
                loadingLabel: 'Saving',
                isLoading: _busy,
                isFullWidth: true,
                onPressed: _reset,
              ),
              const SizedBox(height: AppSpacing.x2),
              AppButton(
                label: 'Send a new code',
                variant: AppButtonVariant.tertiary,
                isFullWidth: true,
                onPressed: _busy ? null : _sendCode,
              ),
            ],
          ),
        );
      case _Step.done:
        return AppButton(
          label: 'Back to sign in',
          isFullWidth: true,
          onPressed: _toLogin,
        );
    }
  }
}
