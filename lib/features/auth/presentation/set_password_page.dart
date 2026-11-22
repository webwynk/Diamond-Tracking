import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/ds/ds_auth_frame.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../application/auth_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'password_done_dialog.dart';
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

  /// Save was pressed; cleared on the next edit (see NewPasswordFields).
  bool _tried = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit(String userCode) async {
    if (_busy) return;
    final ({String? password, String? confirm}) problems = newPasswordProblems(
      _password.text,
      _confirm.text,
      userCode: userCode,
    );
    setState(() {
      _tried = true;
      _failure = null;
    });
    if (problems.password != null || problems.confirm != null) return;
    setState(() => _busy = true);
    final AuthRepository auth = ref.read(authRepositoryProvider);
    final AuthStatusNotifier status = ref.read(authStatusProvider.notifier);
    final String? name = auth.currentFirstName;
    try {
      // Held so the app stays here: the server ends this session, the
      // repository signs in again, and only "Go to Home" moves on.
      await status.holdWhile(() async {
        try {
          await auth.setFirstPassword(_password.text);
        } on AuthFailure catch (failure) {
          if (failure != AuthFailure.passwordSavedSignIn) rethrow;
          // Saved, but signing in again failed (no internet): go to the
          // sign-in screen and say so, rather than "You were signed out".
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(failure.message)));
          }
          await status.signOutWith(auth.signOut);
          return;
        }
        if (!mounted) return;
        setState(() => _busy = false);
        await showPasswordDone(context, PasswordDone.saved, firstName: name);
      });
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edited() {
    if (_tried || _failure != null) {
      setState(() {
        _tried = false;
        _failure = null;
      });
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
          child: NewPasswordFields(
            password: _password,
            confirm: _confirm,
            userCode: userCode,
            tried: _tried,
            onEdited: _edited,
            onSubmitted: (_) => _submit(userCode),
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
