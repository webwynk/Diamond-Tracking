import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_auth_frame.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/credentials.dart';
import 'password_done_dialog.dart';
import 'password_rules.dart';

enum _Step { enterUserId, enterCode, done }

/// Forgotten password, in 3 steps (design v2, Forgot password): the user ID,
/// then the 6-digit code from the email with a new password, then done.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  /// The server sends at most one code a minute per user.
  static const Duration resendAfter = Duration(seconds: 60);

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final TextEditingController _userCode = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  _Step _step = _Step.enterUserId;
  bool _busy = false;
  AuthFailure? _failure;
  String? _userCodeError;
  String? _codeError;

  /// Set new password was pressed; cleared on the next edit.
  bool _tried = false;
  int _resendIn = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _userCode.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startResendWait() {
    _ticker?.cancel();
    setState(() => _resendIn = ForgotPasswordPage.resendAfter.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
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
    final String? problem = userCodeProblem(_userCode.text);
    setState(() => _userCodeError = problem);
    if (problem != null) return;
    await _run(() async {
      await ref.read(authRepositoryProvider).requestResetCode(_userCode.text);
      if (!mounted) return;
      setState(() {
        _step = _Step.enterCode;
        _code.clear();
      });
      _startResendWait();
    });
  }

  Future<void> _reset() async {
    final String? codeError = RegExp(r'^[0-9]{6}$').hasMatch(_code.text)
        ? null
        : 'Enter the 6 digits from the email';
    final ({String? password, String? confirm}) problems = newPasswordProblems(
      _password.text,
      _confirm.text,
      userCode: _userCode.text.trim(),
    );
    setState(() {
      _codeError = codeError;
      _tried = true;
    });
    if (codeError != null ||
        problems.password != null ||
        problems.confirm != null) {
      return;
    }
    final AuthRepository auth = ref.read(authRepositoryProvider);
    final AuthStatusNotifier status = ref.read(authStatusProvider.notifier);
    // Held so the app stays here until "Go to Home": signing in would
    // otherwise move it to Home at once, under the popup.
    await _run(
      () => status.holdWhile(() async {
        await auth.resetWithCode(
          userCode: _userCode.text,
          code: _code.text,
          newPassword: _password.text,
        );
        _ticker?.cancel();
        try {
          // The reset signed every phone out and freed the phone lock, so
          // this phone can sign in with the new password straight away.
          await auth.signIn(loginId: _userCode.text, password: _password.text);
        } on AuthFailure {
          // Reset, but not signed in (no internet): sign in by hand.
          if (mounted) setState(() => _step = _Step.done);
          return;
        }
        if (!mounted) return;
        setState(() => _busy = false);
        await showPasswordDone(context, PasswordDone.reset);
      }),
    );
  }

  void _toLogin() =>
      context.canPop() ? context.pop() : context.go(Routes.login);

  void _back() {
    if (_step == _Step.enterCode) {
      _ticker?.cancel();
      setState(() {
        _step = _Step.enterUserId;
        _failure = null;
      });
    } else {
      _toLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userCode = _userCode.text.trim();
    return switch (_step) {
      _Step.enterUserId => DsAuthFrame(
        title: 'Forgot password?',
        accent: 'We will email a code.',
        subtitle: 'It goes to the email your admin saved for you.',
        step: 1,
        onBack: _busy ? null : _back,
        backLabel: 'Back to sign in',
        footer: const Text('No email saved? Ask your admin.'),
        children: <Widget>[
          DsTextField(
            label: 'User ID',
            controller: _userCode,
            hint: 'EMP007',
            icon: DsIcons.profile,
            error: _userCodeError,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendCode(),
          ),
          if (_failure != null)
            DsBanner(kind: DsBannerKind.danger, title: _failure!.message),
          DsButton(
            label: 'Send code',
            busyLabel: 'Sending',
            busy: _busy,
            arrow: true,
            onPressed: _sendCode,
          ),
        ],
      ),
      _Step.enterCode => DsAuthFrame(
        title: 'Check your email.',
        accent: 'Enter the 6-digit code.',
        subtitle:
            'If $userCode has an email saved, the code is on its way. It '
            'works for 15 minutes.',
        step: 2,
        onBack: _busy ? null : _back,
        backLabel: 'Back',
        footer: const Text('No email saved? Ask your admin.'),
        children: <Widget>[
          _codeField(),
          AutofillGroup(
            child: NewPasswordFields(
              password: _password,
              confirm: _confirm,
              userCode: userCode,
              tried: _tried,
              onEdited: () {
                if (_tried) setState(() => _tried = false);
              },
              showExample: false,
              onSubmitted: (_) => _reset(),
            ),
          ),
          if (_failure != null)
            DsBanner(kind: DsBannerKind.danger, title: _failure!.message),
          DsButton(
            label: 'Set new password',
            busyLabel: 'Saving',
            busy: _busy,
            arrow: true,
            onPressed: _reset,
          ),
        ],
      ),
      _Step.done => DsAuthFrame(
        title: 'Password changed.',
        accent: 'Sign in with it now.',
        subtitle: 'Any phone that was signed in has been signed out.',
        step: 3,
        children: <Widget>[
          DsButton(label: 'Back to sign in', arrow: true, onPressed: _toLogin),
        ],
      ),
    };
  }

  Widget _codeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Code', style: DsText.label),
        ),
        DsCodeBoxes(controller: _code, error: _codeError != null),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _codeError ?? 'Not there? Check spam.',
                  style: DsText.caption.copyWith(
                    color: _codeError == null
                        ? DsColors.text2
                        : DsColors.dangerText,
                  ),
                ),
              ),
              if (_resendIn > 0)
                Text(
                  'Resend in 0:${_resendIn.toString().padLeft(2, '0')}',
                  style: DsText.caption.copyWith(
                    color: DsColors.text2,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                DsTextLink(
                  label: 'Send a new code',
                  onPressed: _busy ? null : _sendCode,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
