import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/pin_validator.dart';
import 'auth_navigation.dart';
import 'controllers/auth_controller.dart';
import 'controllers/auth_state.dart';
import 'widgets/pin_box_input.dart';

/// Screen 04: First Login PIN Change Page.
///
/// Mandatory and strictly unskippable credential setup for employees on first login.
/// Enforces all security complexity rules per PRD F1 and Screen 04 design reference.
class PinChangePage extends ConsumerStatefulWidget {
  const PinChangePage({super.key});

  @override
  ConsumerState<PinChangePage> createState() => _PinChangePageState();
}

class _PinChangePageState extends ConsumerState<PinChangePage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  String _pin = '';
  String _confirmPin = '';

  @override
  void initState() {
    super.initState();
    _pinController.addListener(() {
      setState(() {
        _pin = _pinController.text;
      });
      if (_pin.length == 6 && _confirmPin.isEmpty) {
        _confirmFocus.requestFocus();
      }
    });

    _confirmController.addListener(() {
      setState(() {
        _confirmPin = _confirmController.text;
      });
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _pinFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSavePin() async {
    final validation = PinValidator.validate(_pin, _confirmPin);
    if (!validation.isValid) return;

    FocusScope.of(context).unfocus();
    final success = await ref
        .read(authControllerProvider.notifier)
        .completePinChange(newPin: _pin);

    if (!success || !mounted) return;

    final state = ref.read(authControllerProvider);
    if (state is AuthAuthenticated) {
      AppSnackbar.show(
        context,
        message: 'PIN successfully set. Welcome to Diamond Agritech.',
      );
      AuthNavigation.goToLanding(Navigator.of(context), state.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState is AuthLoading;

    final hasSixDigits = PinValidator.hasSixDigits(_pin);
    final isNotRepeated = PinValidator.isNotRepeated(_pin);
    final isNotSequential = PinValidator.isNotSequential(_pin);
    final matchesConfirmation = _pin.isNotEmpty && _pin == _confirmPin;
    final isFormValid =
        hasSixDigits &&
        isNotRepeated &&
        isNotSequential &&
        matchesConfirmation &&
        !isLoading;

    final showMismatchWarning =
        _confirmPin.length == 6 && _pin.length == 6 && !matchesConfirmation;

    return PopScope(
      // Strictly unskippable: back gesture is disabled
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // Mandatory step: no leading button, the back gesture is blocked above.
        appBar: const AppTopBar(title: 'Create your PIN'),
        body: SafeArea(
          child: Column(
            children: [
              // Main Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4,
                    vertical: AppSpacing.x6,
                  ),
                  child: Column(
                    children: [
                      // Header Vector Graphic & Purpose
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.primary50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: AppColors.primary600,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      Text(
                        'Set a new PIN',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          'Choose a 6-digit PIN. You will use it every time you log in.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.x8),

                      // Input 1: New PIN
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'New PIN',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      PinBoxInput(
                        controller: _pinController,
                        focusNode: _pinFocus,
                        length: 6,
                        obscureText: true,
                      ),

                      const SizedBox(height: AppSpacing.x5),

                      // Input 2: Confirm PIN
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Confirm PIN',
                          style: AppTypography.label.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      PinBoxInput(
                        controller: _confirmController,
                        focusNode: _confirmFocus,
                        length: 6,
                        obscureText: true,
                        hasError: showMismatchWarning,
                      ),

                      if (showMismatchWarning) ...[
                        const SizedBox(height: AppSpacing.x2),
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 14,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PINs do not match',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: AppSpacing.x4),

                      // Security Rules Checklist
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.x1,
                        ),
                        child: Column(
                          children: [
                            _buildRuleRow(
                              label: '6 digits',
                              isSatisfied: hasSixDigits,
                            ),
                            const SizedBox(height: AppSpacing.x2),
                            _buildRuleRow(
                              label: 'Not the same digit repeated',
                              isSatisfied: isNotRepeated && _pin.length >= 2,
                            ),
                            const SizedBox(height: AppSpacing.x2),
                            _buildRuleRow(
                              label: 'Not a sequence like 123456',
                              isSatisfied: isNotSequential && _pin.length >= 3,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.x12),

                      // Bottom Action Button
                      AppButton(
                        label: 'Save PIN',
                        onPressed: isFormValid ? _handleSavePin : null,
                        isLoading: isLoading,
                        disabledReason: !isFormValid
                            ? 'Complete all PIN requirements to save'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        'Mandatory account credential update for field security',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildRuleRow({required String label, required bool isSatisfied}) {
    return Row(
      children: [
        Icon(
          isSatisfied
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isSatisfied ? AppColors.success : AppColors.textDisabled,
        ),
        const SizedBox(width: AppSpacing.x2),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSatisfied ? AppColors.success : AppColors.textSecondary,
            fontWeight: isSatisfied ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
