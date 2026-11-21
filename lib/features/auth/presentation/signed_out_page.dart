import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../application/auth_providers.dart';

/// Shown when the app was signed out without the user asking (design v2,
/// Signed out): the admin reset the account or released the phone, or it
/// was used on another phone. Wording kept general, as the app cannot tell
/// which (owner's decision, 2026-11-21).
class SignedOutPage extends ConsumerWidget {
  const SignedOutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: DsColors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: top + 220,
            padding: EdgeInsets.only(top: top),
            decoration: const BoxDecoration(
              color: DsColors.deep,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/image/white-logo.png',
              width: 132,
              semanticLabel: 'Diamond Agritech',
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 16),
                    child: Column(
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text.rich(
                            const TextSpan(
                              text: 'You were signed out.\n',
                              children: <InlineSpan>[
                                TextSpan(
                                  text: 'Sign in to keep going.',
                                  style: TextStyle(color: DsColors.primary),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: DsText.title.copyWith(height: 1.15),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'Your admin reset your account or released this '
                            'phone, or the account was used on another phone. '
                            'One account works on one phone at a time.',
                            textAlign: TextAlign.center,
                            style: DsText.body.copyWith(color: DsColors.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(DsSpace.lg),
                          decoration: const BoxDecoration(
                            color: DsColors.surface,
                            borderRadius: DsRadius.large,
                          ),
                          child: const Column(
                            children: <Widget>[
                              _Point(
                                number: '1',
                                lead: 'Was it you?',
                                text: 'Sign in again to use this phone.',
                              ),
                              SizedBox(height: DsSpace.md),
                              _Point(
                                number: '2',
                                lead: 'Not you?',
                                text: 'Tell your admin right away.',
                                danger: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        DsButton(
                          label: 'Sign in again',
                          arrow: true,
                          onPressed: () => ref
                              .read(authStatusProvider.notifier)
                              .acknowledgeSignOut(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              DsSpace.md,
              22,
              26 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Text(
              'Questions? Ask your admin.',
              textAlign: TextAlign.center,
              style: DsText.label.copyWith(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.number,
    required this.lead,
    required this.text,
    this.danger = false,
  });

  final String number;
  final String lead;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: danger ? DsColors.dangerTint : DsColors.primaryTint,
          ),
          child: Text(
            number,
            style: DsText.label.copyWith(
              fontWeight: FontWeight.w700,
              color: danger ? DsColors.dangerText : DsColors.primary,
            ),
          ),
        ),
        const SizedBox(width: DsSpace.md),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '$lead ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: text),
              ],
            ),
            style: DsText.body,
          ),
        ),
      ],
    );
  }
}
