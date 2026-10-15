import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/user_profile.dart';
import '../../admin/dashboard/presentation/admin_dashboard_page.dart';
import '../../map/presentation/employee_map_page.dart';
import 'controllers/auth_controller.dart';
import 'controllers/auth_state.dart';
import 'employee_login_page.dart';
import 'pin_change_page.dart';

/// Screen 01: Splash Screen.
///
/// Displays official brand identity, initializes session state, and routes
/// to the appropriate flow (Login, PIN Change, or Home).
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
    });
  }

  Future<void> _initSession() async {
    // Deliberate brief branding pause (800ms) before checking and routing
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    await ref.read(authControllerProvider.notifier).checkSession();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (!mounted) return;
      if (next is AuthUnauthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmployeeLoginPage()),
        );
      } else if (next is AuthMustChangePin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinChangePage()),
        );
      } else if (next is AuthAuthenticated) {
        if (next.profile.role == UserRole.admin) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const EmployeeMapPage()),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.primary600,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Centered Branding
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Geometric Diamond Logo (88x88 dp)
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CustomPaint(
                      painter: _DiamondLogoPainter(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Diamond Agritech',
                    style: AppTypography.h2.copyWith(
                      color: AppColors.neutral0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Field Tracking',
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral0.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Version Indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Text(
                'v1.0.0',
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral0.withValues(alpha: 0.5),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering the geometric Diamond Agritech mark matching Screen 01 reference.
class _DiamondLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Outer diamond
    final outerPaint = Paint()
      ..color = AppColors.neutral0
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final outerPath = Path()
      ..moveTo(w / 2, 5)
      ..lineTo(w - 5, h / 2)
      ..lineTo(w / 2, h - 5)
      ..lineTo(5, h / 2)
      ..close();
    canvas.drawPath(outerPath, outerPaint);

    // Inner diamond (35% opacity)
    final innerPaint = Paint()
      ..color = AppColors.neutral0.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final innerPath = Path()
      ..moveTo(w / 2, 22)
      ..lineTo(w - 22, h / 2)
      ..lineTo(w / 2, h - 22)
      ..lineTo(22, h / 2)
      ..close();
    canvas.drawPath(innerPath, innerPaint);

    // Cross lines (20% opacity)
    final crossPaint = Paint()
      ..color = AppColors.neutral0.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(w / 2, 5), Offset(w / 2, h - 5), crossPaint);
    canvas.drawLine(Offset(5, h / 2), Offset(w - 5, h / 2), crossPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
