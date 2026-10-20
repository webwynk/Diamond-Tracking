import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// Shimmer effect matching docs/03-DESIGN-SYSTEM.md section 7 & Screen 30.
///
/// Features:
/// - Base colour: [AppColors.neutral100] (#F1F5F9).
/// - Highlight colour: [AppColors.neutral300] (#CBD5E1).
/// - 1.5 s loop duration ([AppMotion.shimmer]).
/// - Sweeps smoothly from lower left to upper right.
/// - **Accessibility respect:** falls back to static fill when system
///   reduce-motion or accessible navigation is enabled.
class AppShimmer extends StatefulWidget {
  const AppShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.shimmer)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect system reduced-motion settings
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    final bool disableAnimations =
        media?.disableAnimations ??
        false || (media?.accessibleNavigation ?? false);

    if (disableAnimations) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            final double value = _controller.value;
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.neutral100,
                AppColors.neutral300,
                AppColors.neutral100,
              ],
              stops: const <double>[0.1, 0.5, 0.9],
              transform: _SlidingGradientTransform(slidePercent: value),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}
