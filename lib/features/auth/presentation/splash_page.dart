import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'auth_navigation.dart';
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
        AuthNavigation.goToLanding(Navigator.of(context), next.profile);
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
                  // Official Brand Logo (88x88 dp)
                  Image.asset(
                    'assets/image/white-logo.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
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
