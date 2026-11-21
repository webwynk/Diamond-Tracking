import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_version.dart';
import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../shared/ds/ds_auth_frame.dart';

/// Shown only while the stored session is read at startup (design v2,
/// Splash): the logo, the name, a moving bar and the app's version.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? version = ref.watch(appVersionProvider).value;
    return Scaffold(
      backgroundColor: DsColors.deep,
      body: SizedBox.expand(
        child: CustomPaint(
          painter: const DsDeepBackdropPainter(routeLow: true),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                const Spacer(flex: 3),
                const SizedBox(height: 188, child: DsLogoMark(size: 144)),
                const SizedBox(height: DsSpace.xl),
                Text(
                  'Diamond Agritech',
                  style: DsText.title.copyWith(color: DsColors.white),
                ),
                const SizedBox(height: DsSpace.xs),
                Text(
                  'FIELD TEAM TRACKING',
                  style: DsText.label.copyWith(
                    color: DsColors.sky,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(flex: 4),
                const _LoadingBar(),
                const SizedBox(height: 36),
                SizedBox(
                  height: 16,
                  child: version == null
                      ? null
                      : Text(
                          'Version $version',
                          style: DsText.caption.copyWith(
                            color: DsColors.skyText,
                          ),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short sky-blue bar sliding along a faint track.
class _LoadingBar extends StatefulWidget {
  const _LoadingBar();

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ClipRRect(
        borderRadius: DsRadius.pill,
        child: Container(
          width: 120,
          height: 4,
          color: DsColors.white.withValues(alpha: 0.15),
          child: AnimatedBuilder(
            animation: _run,
            builder: (BuildContext context, Widget? child) {
              final double t = Curves.easeInOut.transform(_run.value);
              // From fully left of the track to past its right end.
              return Transform.translate(
                offset: Offset(-48 + t * 168, 0),
                child: child,
              );
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 48,
                decoration: const BoxDecoration(
                  color: DsColors.sky,
                  borderRadius: DsRadius.pill,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
