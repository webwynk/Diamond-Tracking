import 'package:flutter/material.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_frame.dart';
import '../data/phone_setup.dart';
import '../domain/phone_maker.dart';

/// "Xiaomi phone settings" (design: Phone settings sheet): the maker's
/// steps, each with Open settings, then "I've done these" or Later.
/// True when the employee tapped "I've done these" (saved on the phone).
Future<bool> showPhoneSetupSheet(
  BuildContext context, {
  required PhoneMaker maker,
  required PhoneSetup setup,
}) async {
  final bool done =
      await showDsSheet<bool>(
        context: context,
        builder: (BuildContext context) =>
            PhoneSetupSheet(maker: maker, onOpen: setup.open),
      ) ??
      false;
  if (done) await setup.markDone();
  return done;
}

class PhoneSetupSheet extends StatelessWidget {
  const PhoneSetupSheet({required this.maker, required this.onOpen, super.key});

  final PhoneMaker maker;
  final Future<void> Function(PhoneSettingsPage page) onOpen;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: DsColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              DsIcons.smartphone,
              size: 24,
              color: DsColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(maker.title, style: DsText.section),
                const SizedBox(height: 2),
                Text(maker.intro, style: DsText.caption),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: DsSpace.lg),
      for (int i = 0; i < maker.steps.length; i++) ...<Widget>[
        _StepCard(number: i + 1, step: maker.steps[i], onOpen: onOpen),
        const SizedBox(height: DsSpace.sm),
      ],
      const SizedBox(height: DsSpace.xs),
      const Text(
        'Names differ a little between phone models. If a page looks '
        'different, look for the same words.',
        style: DsText.caption,
      ),
      const SizedBox(height: DsSpace.lg),
      DsButton(
        label: "I've done these",
        onPressed: () => Navigator.pop(context, true),
      ),
      const SizedBox(height: DsSpace.xs),
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Later'),
      ),
    ],
  );
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.step,
    required this.onOpen,
  });

  final int number;
  final PhoneStep step;
  final Future<void> Function(PhoneSettingsPage page) onOpen;

  @override
  Widget build(BuildContext context) {
    final PhoneSettingsPage? page = step.page;
    return Container(
      padding: const EdgeInsets.all(DsSpace.md),
      decoration: const BoxDecoration(
        color: DsColors.surface,
        borderRadius: DsRadius.large,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: DsColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: DsText.caption.copyWith(
                color: DsColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.title,
                  style: DsText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontVariations: const <FontVariation>[
                      FontVariation('wght', 700),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(step.how, style: DsText.caption),
                if (page != null) ...<Widget>[
                  const SizedBox(height: DsSpace.sm),
                  DsSmallButton(
                    label: 'Open settings',
                    onPressed: () => onOpen(page),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
