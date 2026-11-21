import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/design/ds_colors.dart';
import '../../core/design/ds_icons.dart';
import '../../core/design/ds_layout.dart';
import '../../core/design/ds_text.dart';
import 'ds_button.dart';

/// The frame of the sign-in screens (design v2: Sign in, Forgot password,
/// Choose your password, Change password): a deep header with rings, a
/// dotted route and the logo, a two-line title, and the form on a white
/// sheet with rounded top corners.
///
/// When the keyboard opens the header shrinks to the title alone (no logo
/// or subtitle), so the
/// fields and the main button stay in view on small phones. The form
/// scrolls; [footer] sits at the bottom of the sheet, hidden while typing.
class DsAuthFrame extends StatelessWidget {
  const DsAuthFrame({
    required this.title,
    required this.accent,
    required this.children,
    this.subtitle,
    this.footer,
    this.onBack,
    this.backLabel = 'Back',
    this.step,
    this.steps = 3,
    super.key,
  });

  /// First title line, white ("Good to see you.").
  final String title;

  /// Second title line, sky blue ("Let's start the day.").
  final String accent;

  /// A small line under the title.
  final String? subtitle;

  /// The form, top to bottom. Spaced 14 apart.
  final List<Widget> children;

  /// At the bottom of the sheet.
  final Widget? footer;

  /// Shows a glass back button when set.
  final VoidCallback? onBack;
  final String backLabel;

  /// Shows a "2/3" step chip when set (1 based).
  final int? step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool keyboard = media.viewInsets.bottom > 0;
    final double top = media.padding.top;
    // The sheet's rounded top sits on the deep background, where the
    // design overlaps the header by 24.
    final double headerHeight =
        math.max(top + 300, math.min(media.size.height * 0.46, 420)) -
        DsSpace.xl;
    final Widget header = _Header(
      title: title,
      accent: accent,
      subtitle: subtitle,
      compact: keyboard,
      onBack: onBack,
      backLabel: backLabel,
      step: step,
      steps: steps,
    );
    return Scaffold(
      backgroundColor: DsColors.deep,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // While typing the header is only as tall as its title.
          if (keyboard)
            header
          else
            SizedBox(height: headerHeight, child: header),
          Expanded(
            child: _Sheet(footer: footer, children: children),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.children, this.footer});

  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // The footer is a quiet note: hidden while typing, to leave the room to
    // the fields.
    final bool keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    Widget limit(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: child,
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DsColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  DsSpace.xl,
                  28,
                  DsSpace.xl,
                  DsSpace.lg,
                ),
                child: limit(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int i = 0; i < children.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(height: 14),
                        children[i],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (footer != null && !keyboard)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpace.xl,
                  DsSpace.sm,
                  DsSpace.xl,
                  DsSpace.xl,
                ),
                child: limit(
                  DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: DsText.label.copyWith(fontWeight: FontWeight.w400),
                    child: Center(child: footer),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.accent,
    required this.subtitle,
    required this.compact,
    required this.onBack,
    required this.backLabel,
    required this.step,
    required this.steps,
  });

  final String title;
  final String accent;
  final String? subtitle;
  final bool compact;
  final VoidCallback? onBack;
  final String backLabel;
  final int? step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return ClipRect(
      child: CustomPaint(
        painter: const DsDeepBackdropPainter(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            DsSpace.lg,
            top + DsSpace.sm,
            DsSpace.lg,
            20,
          ),
          child: Column(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            children: <Widget>[
              SizedBox(
                height: 46,
                child: Row(
                  children: <Widget>[
                    if (onBack != null)
                      DsIconButton(
                        icon: DsIcons.back,
                        label: backLabel,
                        kind: DsIconButtonKind.glass,
                        onPressed: onBack,
                      ),
                    const Spacer(),
                    if (step != null) DsStepChip(step: step!, steps: steps),
                  ],
                ),
              ),
              if (compact)
                const SizedBox(height: DsSpace.md)
              else
                const Expanded(child: Center(child: DsLogoMark())),
              Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    text: '$title\n',
                    children: <InlineSpan>[
                      TextSpan(
                        text: accent,
                        style: const TextStyle(color: DsColors.sky),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: DsText.title.copyWith(
                    color: DsColors.white,
                    height: 1.2,
                  ),
                ),
              ),
              if (subtitle != null && !compact) ...<Widget>[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: DsText.label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: DsColors.skyText,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo in a glass circle with a soft halo and faint rings around it.
/// Shrinks to the space it gets, and hides when there is too little.
class DsLogoMark extends StatelessWidget {
  const DsLogoMark({this.size = 128, super.key});

  /// Diameter of the glass circle at full size.
  final double size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        // The halo reaches 22 beyond the circle on each side.
        final double room = math.min(box.maxHeight, box.maxWidth) - 44;
        final double d = math.min(size, room);
        if (d < 64) return const SizedBox.shrink();
        return CustomPaint(
          painter: _RingsPainter(d / 2),
          child: SizedBox.square(
            dimension: d + 44,
            child: Center(
              child: Container(
                width: d + 44,
                height: d + 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DsColors.sky.withValues(alpha: 0.10),
                  border: Border.all(
                    color: DsColors.sky.withValues(alpha: 0.22),
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DsColors.white.withValues(alpha: 0.10),
                    border: Border.all(
                      color: DsColors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/image/white-logo.png',
                    width: d * 0.66,
                    semanticLabel: 'Diamond Agritech',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Three faint rings around the logo, as in the design.
class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = DsColors.white.withValues(alpha: 0.06);
    final Offset c = size.center(Offset.zero);
    for (final double r in <double>[radius + 46, radius + 96, radius + 146]) {
      canvas.drawCircle(c, r, ring);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.radius != radius;
}

/// The deep background: a primary glow in the middle and a dotted route
/// line in sky blue (design v2 sign-in and splash).
class DsDeepBackdropPainter extends CustomPainter {
  const DsDeepBackdropPainter({this.routeLow = false});

  /// The splash draws its route lower and across the whole width.
  final bool routeLow;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas
      ..drawRect(all, Paint()..color = DsColors.deep)
      ..drawRect(
        all,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.16),
            radius: 0.65,
            colors: <Color>[
              DsColors.primary,
              DsColors.deep.withValues(alpha: 0),
            ],
          ).createShader(all),
      );
    final double w = size.width;
    final double h = size.height;
    final Path route = routeLow
        ? (Path()
            ..moveTo(-0.05 * w, 0.76 * h)
            ..cubicTo(
              0.18 * w,
              0.71 * h,
              0.33 * w,
              0.78 * h,
              0.54 * w,
              0.72 * h,
            )
            ..cubicTo(
              0.75 * w,
              0.66 * h,
              0.85 * w,
              0.62 * h,
              1.05 * w,
              0.64 * h,
            ))
        : (Path()
            ..moveTo(-0.03 * w, 0.75 * h)
            ..cubicTo(
              0.15 * w,
              0.68 * h,
              0.28 * w,
              0.75 * h,
              0.41 * w,
              0.66 * h,
            )
            ..cubicTo(
              0.55 * w,
              0.56 * h,
              0.62 * w,
              0.48 * h,
              0.59 * w,
              0.38 * h,
            ));
    final Paint dot = Paint()
      ..color = DsColors.sky.withValues(alpha: 0.32)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final PathMetric metric in route.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 11) {
        final Path seg = metric.extractPath(d, d + 2);
        canvas.drawPath(seg, dot);
      }
    }
  }

  @override
  bool shouldRepaint(DsDeepBackdropPainter old) => old.routeLow != routeLow;
}

/// "2/3" with a bar per step, on a deep header.
class DsStepChip extends StatelessWidget {
  const DsStepChip({required this.step, required this.steps, super.key});

  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $step of $steps',
      excludeSemantics: true,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: DsColors.white.withValues(alpha: 0.10),
          borderRadius: DsRadius.pill,
          border: Border.all(color: DsColors.white.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 1; i <= steps; i++) ...<Widget>[
              if (i > 1) const SizedBox(width: 6),
              Container(
                width: i <= step ? 24 : 12,
                height: 6,
                decoration: BoxDecoration(
                  color: i <= step
                      ? DsColors.white
                      : DsColors.white.withValues(alpha: 0.25),
                  borderRadius: DsRadius.pill,
                ),
              ),
            ],
            const SizedBox(width: 10),
            Text(
              '$step/$steps',
              style: DsText.caption.copyWith(
                color: DsColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
