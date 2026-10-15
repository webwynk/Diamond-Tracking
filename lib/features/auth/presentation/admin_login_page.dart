import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../../admin/dashboard/presentation/admin_dashboard_page.dart';
import 'controllers/auth_controller.dart';
import 'controllers/auth_state.dart';

/// Screen 03: Administrator Login Page.
///
/// Restricted authentication entry point for office staff and system administrators.
class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAdminLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Please enter both administrator email and password.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signInAdmin(
          email: email,
          password: password,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage =
        authState is AuthUnauthenticated ? authState.errorMessage : null;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (!mounted) return;
      if (next is AuthAuthenticated) {
        AppSnackbar.show(
          context,
          message: 'Authenticated as Admin: ${next.profile.fullName}',
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
          (route) => false,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Teal Header Container (140 dp, rounded-b 24 dp)
              Container(
                height: 140,
                decoration: const BoxDecoration(
                  color: AppColors.primary600,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.xl),
                    bottomRight: Radius.circular(AppRadius.xl),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.neutral0,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: AppSpacing.x3),
                        // Diamond logo (36x36 dp)
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.neutral0,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.diamond_outlined,
                            color: AppColors.neutral0,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x3),
                        Text(
                          'Admin Login',
                          style: AppTypography.h3.copyWith(
                            color: AppColors.neutral0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: Text(
                        'ENTERPRISE TELEMETRY SYSTEM',
                        style: AppTypography.overline.copyWith(
                          color: AppColors.neutral0.withValues(alpha: 0.9),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Overlapping Card Container (-24 dp overlap)
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.x5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Field 1: Email
                      Text(
                        'Email',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Container(
                        height: AppSizes.controlHeight,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.neutral300,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x3,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.mail_outline_rounded,
                              color: AppColors.statusOff,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.x3),
                            Expanded(
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'name@diamondagritech.in',
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.x4),

                      // Field 2: Password
                      Text(
                        'Password',
                        style: AppTypography.label.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x1),
                      Container(
                        height: AppSizes.controlHeight,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: errorMessage != null
                                ? AppColors.error
                                : AppColors.neutral300,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x3,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.statusOff,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.x3),
                            Expanded(
                              child: TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Enter password',
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.statusOff,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      // Error message strip
                      if (errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x3,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.x6),

                      // Sign In Primary Button
                      AppButton(
                        label: 'Sign In',
                        onPressed: isLoading ? null : _handleAdminLogin,
                        isLoading: isLoading,
                      ),

                      const SizedBox(height: AppSpacing.x4),

                      // Back to Employee Login Link
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Back to Employee Login',
                            style: AppTypography.label.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
