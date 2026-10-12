import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_typography.dart';

/// A gallery of every design token, rendered.
///
/// **Temporary and development-only.** It exists so Phase 0 Step 2 can actually
/// be verified against docs/03-DESIGN-SYSTEM.md rather than assumed correct,
/// and so generated screen designs can be compared against the real rendered
/// tokens. Replaced by real routing in Phase 1; delete this file then.
class ThemePreviewPage extends StatelessWidget {
  const ThemePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme preview'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x4),
            child: Center(
              child: Text(
                'Phase 0 · Step 2',
                style: AppTypography.caption.withColor(AppColors.neutral0),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x6,
        ),
        children: const <Widget>[
          _Section('TYPE SCALE'),
          _TypeRow('display 32/40', AppTypography.display),
          _TypeRow('h1 28/36', AppTypography.h1),
          _TypeRow('h2 24/32', AppTypography.h2),
          _TypeRow('h3 20/28', AppTypography.h3),
          _TypeRow('title 18/26', AppTypography.title),
          _TypeRow('bodyLarge 16/24', AppTypography.bodyLarge),
          _TypeRow('body 14/20', AppTypography.body),
          _TypeRow('label 13/18', AppTypography.label),
          _TypeRow('caption 12/16', AppTypography.caption),
          _TypeRow('OVERLINE 11/16', AppTypography.overline),

          SizedBox(height: AppSpacing.x8),
          _Section('TABULAR FIGURES'),
          _TabularCheck(),

          SizedBox(height: AppSpacing.x8),
          _Section('BRAND RAMP'),
          _Swatches(<_Sw>[
            _Sw('50', AppColors.primary50),
            _Sw('100', AppColors.primary100),
            _Sw('200', AppColors.primary200),
            _Sw('300', AppColors.primary300),
            _Sw('400', AppColors.primary400),
            _Sw('500', AppColors.primary500),
            _Sw('600', AppColors.primary600, isBrand: true),
            _Sw('700', AppColors.primary700),
            _Sw('800', AppColors.primary800),
            _Sw('900', AppColors.primary900),
          ]),

          SizedBox(height: AppSpacing.x6),
          _Section('NEUTRALS'),
          _Swatches(<_Sw>[
            _Sw('0', AppColors.neutral0),
            _Sw('50', AppColors.neutral50),
            _Sw('100', AppColors.neutral100),
            _Sw('200', AppColors.neutral200),
            _Sw('300', AppColors.neutral300),
            _Sw('400', AppColors.neutral400),
            _Sw('500', AppColors.neutral500),
            _Sw('600', AppColors.neutral600),
            _Sw('700', AppColors.neutral700),
            _Sw('800', AppColors.neutral800),
            _Sw('900', AppColors.neutral900),
          ]),

          SizedBox(height: AppSpacing.x6),
          _Section('SEMANTIC'),
          _Swatches(<_Sw>[
            _Sw('success', AppColors.success),
            _Sw('warning', AppColors.warning),
            _Sw('error', AppColors.error),
            _Sw('info', AppColors.info),
          ]),

          SizedBox(height: AppSpacing.x8),
          _Section('DUTY STATUS — colour PLUS label, never colour alone'),
          _StatusPills(),

          SizedBox(height: AppSpacing.x8),
          _Section('BUTTONS — 48 dp tall, 12 radius'),
          _Buttons(),

          SizedBox(height: AppSpacing.x8),
          _Section('INPUT — label above the field, never placeholder-only'),
          _Inputs(),

          SizedBox(height: AppSpacing.x8),
          _Section('RADIUS'),
          _RadiusRow(),

          SizedBox(height: AppSpacing.x12),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Text(label.toUpperCase(), style: AppTypography.overline),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow(this.name, this.style);

  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: AppTypography.caption),
          Text('Ramesh Kumar 47.3 km', style: style),
        ],
      ),
    );
  }
}

/// Proves tabular figures line up. The two rows must align character for
/// character; if they do not, the font feature is not being applied.
class _TabularCheck extends StatelessWidget {
  const _TabularCheck();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('111.1 km', style: AppTypography.display.tabular),
        Text('888.8 km', style: AppTypography.display.tabular),
        const SizedBox(height: AppSpacing.x1),
        const Text(
          'These two must align exactly. If they do not, tabular figures are '
          'not applied and live counters will jitter.',
          style: AppTypography.caption,
        ),
      ],
    );
  }
}

class _Sw {
  const _Sw(this.label, this.colour, {this.isBrand = false});

  final String label;
  final Color colour;
  final bool isBrand;
}

class _Swatches extends StatelessWidget {
  const _Swatches(this.swatches);

  final List<_Sw> swatches;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: <Widget>[
        for (final _Sw s in swatches)
          Column(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: s.colour,
                  borderRadius: AppRadius.smAll,
                  border: Border.all(
                    color: s.isBrand ? AppColors.neutral900 : AppColors.border,
                    width: s.isBrand ? 2 : 1,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(s.label, style: AppTypography.caption),
            ],
          ),
      ],
    );
  }
}

class _StatusPills extends StatelessWidget {
  const _StatusPills();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: <Widget>[
        for (final String key in AppStatusColors.labels.keys)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3,
              vertical: AppSpacing.x2,
            ),
            decoration: BoxDecoration(
              color: AppStatusColors.backgrounds[key],
              borderRadius: AppRadius.fullAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppStatusColors.colours[key],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Text(
                  AppStatusColors.labels[key]!,
                  style: AppTypography.label.withColor(
                    AppStatusColors.colours[key]!,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ElevatedButton(onPressed: () {}, child: const Text('Primary')),
        const SizedBox(height: AppSpacing.x3),
        OutlinedButton(onPressed: () {}, child: const Text('Secondary')),
        const SizedBox(height: AppSpacing.x3),
        TextButton(onPressed: () {}, child: const Text('Tertiary')),
        const SizedBox(height: AppSpacing.x3),
        const ElevatedButton(onPressed: null, child: Text('Disabled')),
      ],
    );
  }
}

class _Inputs extends StatelessWidget {
  const _Inputs();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Employee ID', style: AppTypography.label),
        SizedBox(height: AppSpacing.x1),
        TextField(decoration: InputDecoration(hintText: 'DA-014')),
        SizedBox(height: AppSpacing.x4),
        Text('PIN', style: AppTypography.label),
        SizedBox(height: AppSpacing.x1),
        TextField(
          decoration: InputDecoration(
            hintText: '6 digits',
            errorText: 'Incorrect PIN. 3 attempts remaining.',
          ),
        ),
      ],
    );
  }
}

class _RadiusRow extends StatelessWidget {
  const _RadiusRow();

  @override
  Widget build(BuildContext context) {
    const Map<String, double> radii = <String, double>{
      'sm 8': AppRadius.sm,
      'md 12': AppRadius.md,
      'lg 16': AppRadius.lg,
      'xl 24': AppRadius.xl,
      'full': AppRadius.full,
    };
    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: <Widget>[
        for (final MapEntry<String, double> e in radii.entries)
          Column(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(e.value),
                  border: Border.all(color: AppColors.primary200),
                ),
              ),
              const SizedBox(height: AppSpacing.x1),
              Text(e.key, style: AppTypography.caption),
            ],
          ),
      ],
    );
  }
}
