import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import 'admin_login_page.dart';
import 'controllers/auth_controller.dart';
import 'controllers/auth_state.dart';
import 'pin_change_page.dart';

/// Screen 02: Employee Login Page.
///
/// Primary entry point for field staff using Employee Code and 6-digit PIN.
/// Implements overlapping card layout matching Screen 02 design reference.
class EmployeeLoginPage extends ConsumerStatefulWidget {
  const EmployeeLoginPage({super.key});

  @override
  ConsumerState<EmployeeLoginPage> createState() => _EmployeeLoginPageState();
}

class _EmployeeLoginPageState extends ConsumerState<EmployeeLoginPage> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _obscurePin = true;

  @override
  void dispose() {
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final code = _codeController.text.trim();
    final pin = _pinController.text.trim();

    if (code.isEmpty || pin.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Please enter both your Employee ID and PIN.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signInEmployee(
          employeeCode: code,
          pin: pin,
        );
  }

  void _showForgotPinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Forgot PIN?',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Please contact your Diamond Agritech office administrator to request a PIN reset. Once reset, you will create a new PIN on your next login.',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Understood',
              style: AppTypography.label.copyWith(
                color: AppColors.primary600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
      if (next is AuthMustChangePin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinChangePage()),
        );
      } else if (next is AuthAuthenticated) {
        // Successful login
        AppSnackbar.show(
          context,
          message: 'Welcome back, ${next.profile.fullName}!',
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Header Block (160 dp, rounded-b 24 dp)
                  Container(
                    height: 160,
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Vector diamond logo (40x40 dp)
                        Container(
                          width: 40,
                          height: 40,
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
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x3),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diamond Agritech',
                              style: AppTypography.h3.copyWith(
                                color: AppColors.neutral0,
                              ),
                            ),
                            Text(
                              'Employee Login',
                              style: AppTypography.body.copyWith(
                                color: AppColors.neutral0.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. Overlapping Login Card (-24 dp overlap)
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
                          // Field 1: Employee ID
                          Text(
                            'Employee ID',
                            style: AppTypography.label.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                                  Icons.badge_outlined,
                                  color: AppColors.textDisabled,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _codeController,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'e.g. DA-014',
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

                          // Field 2: PIN
                          Text(
                            'PIN',
                            style: AppTypography.label.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                                  color: AppColors.textDisabled,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _pinController,
                                    obscureText: _obscurePin,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '6-digit PIN',
                                      counterText: '',
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: AppColors.textPrimary,
                                      letterSpacing: _obscurePin ? 4 : 1,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _obscurePin
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: AppColors.textDisabled,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePin = !_obscurePin;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Error Strip
                          if (errorMessage != null) ...[
                            const SizedBox(height: 8),
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

                          // Forgot PIN Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPinDialog,
                              child: Text(
                                'Forgot PIN?',
                                style: AppTypography.label.copyWith(
                                  color: AppColors.primary600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.x2),

                          // Primary Log in Button
                          AppButton(
                            label: 'Log in',
                            onPressed: isLoading ? null : _handleLogin,
                            isLoading: isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Below Card Helper Text
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                    ),
                    child: Text(
                      'Contact the office if you cannot sign in.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const Spacer(),

                  // Bottom Admin Login Link
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminLoginPage(),
                            ),
                          );
                        },
                        child: Text(
                          'Admin login',
                          style: AppTypography.label.copyWith(
                            color: AppColors.primary600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
