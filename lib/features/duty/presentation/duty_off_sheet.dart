import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_status.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/rules/duty_rules.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_chips.dart';
import '../../../shared/ds/ds_frame.dart';
import '../domain/duty_day.dart';
import 'duty_card.dart' show dayVisitCount, kmText;

/// "End your duty?" (design v2): what today looks like before duty off.
/// True when the employee chose Yes, duty off.
Future<bool> showDutyOffSheet(
  BuildContext context, {
  required DutyDay day,
  required DateTime now,
}) async =>
    await showDsSheet<bool>(
      context: context,
      builder: (BuildContext context) => DutyOffSheet(day: day, now: now),
    ) ??
    false;

class DutyOffSheet extends ConsumerWidget {
  const DutyOffSheet({required this.day, required this.now, super.key});

  final DutyDay day;

  /// The trusted time when the sheet opened.
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime on = day.dutyOnAt!;
    final Duration worked = now.difference(on);
    final Duration left = DutyRules.minimumDuty - worked;
    final bool short = left > Duration.zero;
    final double share = (worked.inSeconds / DutyRules.minimumDuty.inSeconds)
        .clamp(0, 1)
        .toDouble();
    final int visits = dayVisitCount(ref, day.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: DsColors.dangerTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                DsIcons.dutyOff,
                size: 22,
                color: DsColors.dangerText,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('End your duty?', style: DsText.title),
                  SizedBox(height: 2),
                  Text('Your route stops recording now.', style: DsText.label),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DsSpace.lg),
        Container(
          padding: const EdgeInsets.all(DsSpace.lg),
          decoration: const BoxDecoration(
            color: DsColors.surface,
            borderRadius: DsRadius.large,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('Worked today', style: DsText.caption),
                        Text(
                          IstFormat.hoursMinutes(worked),
                          style: DsText.display,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: DsSpace.xs),
                    child: short
                        ? DsTag(
                            label: '${IstFormat.hoursMinutes(left)} short',
                            status: DsStatus.waiting,
                          )
                        : const DsTag(
                            label: '10 h done',
                            status: DsStatus.present,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpace.md),
              Semantics(
                label: 'Hours toward 10 hour goal',
                value: '${(share * 100).floor()}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 10,
                    child: Stack(
                      children: <Widget>[
                        const Positioned.fill(
                          child: ColoredBox(color: DsColors.line),
                        ),
                        FractionallySizedBox(
                          widthFactor: share,
                          child: Container(
                            decoration: BoxDecoration(
                              color: short
                                  ? DsColors.warningDot
                                  : DsColors.successDot,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TimeLabel(
                      bold: IstFormat.time(on),
                      after: ' start',
                    ),
                  ),
                  _TimeLabel(before: 'now ', bold: IstFormat.time(now)),
                  const Expanded(
                    child: Text(
                      '10 h goal',
                      textAlign: TextAlign.end,
                      style: DsText.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpace.md),
              Row(
                children: <Widget>[
                  _Fact(icon: DsIcons.map, text: kmText(day.distanceM)),
                  const SizedBox(width: DsSpace.sm),
                  _Fact(
                    icon: DsIcons.camera,
                    text: '$visits ${visits == 1 ? 'visit' : 'visits'}',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: DsSpace.lg),
        if (short) ...<Widget>[
          const _Note(
            icon: DsIcons.warning,
            status: DsStatus.waiting,
            bold: "Won't count for attendance",
            text:
                ' unless the admin approves. The admin will decide: present, '
                'half day or absent.',
          ),
          const SizedBox(height: 10),
        ],
        const _Note(
          icon: DsIcons.lock,
          status: DsStatus.off,
          text: "You can't turn duty on again today.",
        ),
        const SizedBox(height: DsSpace.lg),
        DsButton(
          label: 'Yes, duty off',
          kind: DsButtonKind.danger,
          icon: DsIcons.dutyOff,
          onPressed: () => Navigator.pop(context, true),
        ),
        const SizedBox(height: 6),
        Center(
          child: DsTextLink(
            label: 'Keep working',
            onPressed: () => Navigator.pop(context, false),
          ),
        ),
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.bold, this.before = '', this.after = ''});

  final String before;
  final String bold;
  final String after;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: <TextSpan>[
        TextSpan(text: before),
        TextSpan(
          text: bold,
          style: const TextStyle(
            color: DsColors.ink,
            fontWeight: FontWeight.w700,
            fontVariations: <FontVariation>[FontVariation('wght', 700)],
          ),
        ),
        TextSpan(text: after),
      ],
    ),
    style: DsText.caption,
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.md, vertical: 10),
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: DsRadius.medium,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: DsColors.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: DsText.body.copyWith(
                fontWeight: FontWeight.w700,
                fontVariations: const <FontVariation>[
                  FontVariation('wght', 700),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.status,
    required this.text,
    this.bold,
  });

  final IconData icon;
  final DsStatus status;
  final String? bold;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Color color = status == DsStatus.off ? DsColors.text2 : status.text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: status.tint, shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text.rich(
              TextSpan(
                children: <TextSpan>[
                  if (bold != null)
                    TextSpan(
                      text: bold,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontVariations: <FontVariation>[
                          FontVariation('wght', 700),
                        ],
                      ),
                    ),
                  TextSpan(text: text),
                ],
              ),
              style: DsText.label.copyWith(color: color),
            ),
          ),
        ),
      ],
    );
  }
}
