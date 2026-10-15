import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';

/// Modal dialog for updating the 4-digit security PIN adhering to Screen 13 specifications.
class UpdatePinDialog extends StatefulWidget {
  const UpdatePinDialog({
    super.key,
    required this.onSavePin,
  });

  final Future<bool> Function(String newPin) onSavePin;

  static Future<bool?> show(
    BuildContext context, {
    required Future<bool> Function(String newPin) onSavePin,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => UpdatePinDialog(onSavePin: onSavePin),
    );
  }

  @override
  State<UpdatePinDialog> createState() => _UpdatePinDialogState();
}

class _UpdatePinDialogState extends State<UpdatePinDialog> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be at least 4 digits.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onSavePin(pin);
      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to update PIN. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Title + Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Update Security PIN',
                  style: AppTypography.title.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  key: const Key('btn-close-pin-dialog'),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),

            // Description
            Text(
              'Enter a new 4-digit PIN for device login authentication in offline field zones.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.x4),

            // Form: Label
            Text(
              'New 4-Digit PIN',
              style: AppTypography.label.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.x2),

            // PIN Text Field
            TextField(
              key: const Key('pin-input-field'),
              controller: _pinController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                letterSpacing: 12.0,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: '••••',
                hintStyle: TextStyle(
                  letterSpacing: 12.0,
                  color: AppColors.textDisabled,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(color: AppColors.neutral300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                  borderSide: BorderSide(
                    color: AppColors.primary600,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.x2),
              Text(
                _errorMessage!,
                style: AppTypography.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.x4),

            // Save Action Button
            AppButton(
              key: const Key('btn-save-pin'),
              label: 'Save New PIN',
              isLoading: _isLoading,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }
}
