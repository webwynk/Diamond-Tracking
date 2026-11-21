import 'package:flutter/material.dart';

import '../../../shared/ds/ds_field.dart';

/// The three password rules as ticks that turn green while typing (design
/// v2, Choose your password). The full check, with its message, is
/// passwordProblem in credentials.dart; this only shows progress.
class PasswordRules extends StatelessWidget {
  const PasswordRules({
    required this.controller,
    required this.userCode,
    super.key,
  });

  final TextEditingController controller;
  final String userCode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final String p = controller.text;
        final bool long = p.length >= 8 && p.length <= 72;
        final bool mixed =
            RegExp('[A-Za-z]').hasMatch(p) && RegExp('[0-9]').hasMatch(p);
        final bool notId =
            p.isNotEmpty &&
            (userCode.isEmpty ||
                !p.toLowerCase().contains(userCode.toLowerCase()));
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            DsRuleTick(label: '8+ characters', met: long),
            DsRuleTick(label: 'Letter and digit', met: mixed),
            DsRuleTick(label: 'Not your user ID', met: notId),
          ],
        );
      },
    );
  }
}
