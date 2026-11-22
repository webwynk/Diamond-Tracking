import 'package:flutter/material.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';

/// Which password flow just finished.
enum PasswordDone {
  /// The first password, after the temporary PIN.
  saved,

  /// Change password, from Profile or My account.
  changed,

  /// Forgot password, with the emailed code.
  reset,
}

/// "Password saved" (design v2, 2026-11-23): a big green tick, a line, and
/// Go to Home. It closes only with that button (not the back key or a tap
/// outside), so the app moves on to Home only when the user is ready.
Future<void> showPasswordDone(
  BuildContext context,
  PasswordDone kind, {
  String? firstName,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: DsColors.scrim,
  builder: (BuildContext context) =>
      PopScope(canPop: false, child: _PasswordDoneDialog(kind, firstName)),
);

class _PasswordDoneDialog extends StatelessWidget {
  const _PasswordDoneDialog(this.kind, this.firstName);

  final PasswordDone kind;
  final String? firstName;

  @override
  Widget build(BuildContext context) {
    final String? name = firstName;
    final (String title, String message) = switch (kind) {
      PasswordDone.saved => (
        'Password saved',
        "You're all set${name == null ? '' : ', $name'}. Use this password "
            'every time you sign in.',
      ),
      PasswordDone.changed => (
        'Password changed',
        'Your new password is saved. Use it the next time you sign in.',
      ),
      PasswordDone.reset => (
        'Password reset',
        "You're signed in with your new password. Use it the next time you "
            'sign in.',
      ),
    };
    return Dialog(
      backgroundColor: DsColors.white,
      insetPadding: const EdgeInsets.all(DsSpace.xl),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpace.xl,
          28,
          DsSpace.xl,
          DsSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: DsColors.successTint,
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: DsColors.successDot,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  DsIcons.check,
                  size: 30,
                  color: DsColors.white,
                ),
              ),
            ),
            const SizedBox(height: DsSpace.lg),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: DsText.title,
              ),
            ),
            const SizedBox(height: DsSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DsText.body.copyWith(color: DsColors.text2),
            ),
            const SizedBox(height: DsSpace.xl),
            DsButton(
              label: 'Go to Home',
              arrow: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
