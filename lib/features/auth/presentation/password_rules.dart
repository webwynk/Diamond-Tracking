import 'package:flutter/material.dart';

import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_field.dart';
import '../domain/credentials.dart';

/// What is still wrong with a new password and its repeat, or nulls when
/// both are fine. [extra] is a page's own rule, checked after the shared
/// ones (Change password: not the same as the current one).
({String? password, String? confirm}) newPasswordProblems(
  String password,
  String confirm, {
  required String userCode,
  String? Function(String password)? extra,
}) => (
  password:
      passwordProblem(password, userCode: userCode) ?? extra?.call(password),
  confirm: confirm == password ? null : "Passwords don't match",
);

/// The new password and its repeat, with the rules as live ticks (design
/// v2, Choose your password, 2026-11-23):
/// - while typing the field is blue and each rule turns green when met;
/// - when every rule is met the field turns green, and the repeat turns
///   green with "Passwords match" once it is the same;
/// - red only after Save ([tried]) for what is still wrong; the page clears
///   [tried] on the next edit ([onEdited]), so the red never lingers.
class NewPasswordFields extends StatelessWidget {
  const NewPasswordFields({
    required this.password,
    required this.confirm,
    required this.userCode,
    required this.tried,
    required this.onEdited,
    this.showExample = true,
    this.extra,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController password;
  final TextEditingController confirm;
  final String userCode;

  /// Save was pressed and the fields have not been edited since.
  final bool tried;
  final VoidCallback onEdited;

  /// The line "Use 8 or more characters ... Example: Mango@2025" under the
  /// field (first sign-in). Elsewhere the example is the field's hint.
  final bool showExample;
  final String? Function(String password)? extra;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[password, confirm]),
      builder: (BuildContext context, Widget? _) {
        final String p = password.text;
        final String c = confirm.text;
        final PasswordChecks checks = PasswordChecks(p, userCode: userCode);
        final ({String? password, String? confirm}) problems =
            newPasswordProblems(p, c, userCode: userCode, extra: extra);
        final bool passwordOk = p.isNotEmpty && problems.password == null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            DsTextField(
              label: 'New password',
              controller: password,
              hint: showExample ? null : 'Example: $passwordExample',
              icon: DsIcons.lock,
              password: true,
              valid: passwordOk,
              error: tried ? problems.password : null,
              autofillHints: const <String>[AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onChanged: (_) => onEdited(),
            ),
            const SizedBox(height: 10),
            if (showExample) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text.rich(
                  TextSpan(
                    text:
                        'Use 8 or more characters with a letter, a digit and '
                        'a symbol. Example: ',
                    children: <InlineSpan>[
                      TextSpan(
                        text: passwordExample,
                        style: DsText.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  style: DsText.caption,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                DsRuleTick(
                  label: '8+ characters',
                  met: checks.long,
                  failed: tried,
                ),
                DsRuleTick(
                  label: 'A letter',
                  met: checks.letter,
                  failed: tried,
                ),
                DsRuleTick(label: 'A digit', met: checks.digit, failed: tried),
                DsRuleTick(
                  label: r'A symbol like @ # $ !',
                  met: checks.symbol,
                  failed: tried,
                ),
                DsRuleTick(
                  label: 'Not your user ID',
                  met: checks.notUserId,
                  failed: tried,
                ),
              ],
            ),
            const SizedBox(height: 14),
            DsTextField(
              label: 'Repeat new password',
              controller: confirm,
              icon: DsIcons.lock,
              password: true,
              valid: passwordOk && c.isNotEmpty && problems.confirm == null,
              validNote: 'Passwords match',
              error: tried ? problems.confirm : null,
              autofillHints: const <String>[AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onChanged: (_) => onEdited(),
              onSubmitted: onSubmitted,
            ),
          ],
        );
      },
    );
  }
}
