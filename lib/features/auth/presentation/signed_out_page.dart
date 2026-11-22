import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
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
    final EdgeInsets inset = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: DsColors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: inset.top + 28),
            child: Text(
              'Diamond Agritech',
              textAlign: TextAlign.center,
              style: DsText.label.copyWith(
                color: DsColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: DsColors.primaryTint,
                      ),
                      child: const ExcludeSemantics(
                        child: Icon(
                          DsIcons.smartphone,
                          size: 40,
                          color: DsColors.deep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Semantics(
                      header: true,
                      child: Text(
                        'You were signed out',
                        textAlign: TextAlign.center,
                        style: DsText.title.copyWith(height: 1.15),
                      ),
                    ),
                    const SizedBox(height: DsSpace.sm),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        'Your admin reset your account or released this '
                        'phone, or you signed in on another phone. One '
                        'account works on one phone at a time.',
                        textAlign: TextAlign.center,
                        style: DsText.body.copyWith(color: DsColors.text2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: _NotYouCard(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22, DsSpace.lg, 22, 22 + inset.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DsButton(
                  label: 'Sign in again',
                  arrow: true,
                  onPressed: () => ref
                      .read(authStatusProvider.notifier)
                      .acknowledgeSignOut(),
                ),
                const SizedBox(height: 10),
                Text(
                  'Use your user ID and password',
                  textAlign: TextAlign.center,
                  style: DsText.caption.copyWith(color: DsColors.text3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Not you?": a signed-out phone can mean someone else signed in.
class _NotYouCard extends StatelessWidget {
  const _NotYouCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: DsColors.surface,
        borderRadius: DsRadius.medium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DsColors.dangerTint,
            ),
            child: const ExcludeSemantics(
              child: Icon(
                DsIcons.shieldAlert,
                size: 20,
                color: DsColors.dangerText,
              ),
            ),
          ),
          const SizedBox(width: DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Not you?',
                  style: DsText.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tell your admin right away. They can reset your password '
                  'and release this phone.',
                  style: DsText.label.copyWith(
                    fontWeight: FontWeight.w500,
                    color: DsColors.text2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
