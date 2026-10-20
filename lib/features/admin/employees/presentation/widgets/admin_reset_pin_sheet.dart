import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../auth/domain/pin_validator.dart';
import '../controllers/admin_employee_list_state.dart';

/// Bottom sheet for an admin to give an employee a new temporary PIN.
///
/// The employee must change it the next time they sign in, and any lockout is
/// cleared. The PIN is shown as typed so the admin can read it to the employee.
/// The server applies the same PIN rules and records the reset in the audit log.
class AdminResetPinSheet extends StatefulWidget {
  const AdminResetPinSheet({
    super.key,
    required this.employee,
    required this.onConfirm,
  });

  final AdminEmployeeItem employee;
  final Future<void> Function(String pin) onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    required AdminEmployeeItem employee,
    required Future<void> Function(String pin) onConfirm,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (ctx) =>
          AdminResetPinSheet(employee: employee, onConfirm: onConfirm),
    );
  }

  @override
  State<AdminResetPinSheet> createState() => _AdminResetPinSheetState();
}

class _AdminResetPinSheetState extends State<AdminResetPinSheet> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _serverError;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  String get _pin => _pinController.text;

  /// What is wrong with the PIN typed so far, in words; null when it is fine.
  /// Nothing is said until all six digits are in, so typing is not nagged.
  String? get _problem {
    if (_pin.length < 6) return null;
    if (!PinValidator.isNotRepeated(_pin)) {
      return 'PIN cannot be one repeated digit.';
    }
    if (!PinValidator.isNotSequential(_pin)) {
      return 'PIN cannot be a simple sequence like 123456.';
    }
    return null;
  }

  bool get _canSubmit =>
      PinValidator.hasSixDigits(_pin) && _problem == null && !_isLoading;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isLoading = true;
      _serverError = null;
    });
    try {
      await widget.onConfirm(_pin);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _serverError = e is AppException
              ? e.message
              : 'Could not reset the PIN. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final problem = _problem ?? _serverError;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.xlTop,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x6,
          AppSpacing.x4,
          AppSpacing.x6,
          AppSpacing.x6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primary50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: AppColors.primary600,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              Text(
                'Reset PIN for ${widget.employee.name}?',
                key: const Key('reset-pin-title'),
                textAlign: TextAlign.center,
                style: AppTypography.h3.copyWith(color: AppColors.neutral900),
              ),
              const SizedBox(height: 2),
              Text(
                widget.employee.employeeCode,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.neutral500),
              ),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Choose a temporary 6-digit PIN and tell it to the employee. '
                'They must choose their own PIN when they next sign in. Any '
                'lockout is cleared.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              TextField(
                key: const Key('input-reset-pin'),
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (_) => setState(() => _serverError = null),
                textAlign: TextAlign.center,
                style: AppTypography.h3.copyWith(
                  color: AppColors.neutral900,
                  letterSpacing: 6,
                ),
                decoration: InputDecoration(
                  hintText: '6 digits',
                  hintStyle: AppTypography.bodyLarge.copyWith(
                    color: AppColors.neutral400,
                    letterSpacing: 0,
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.all(AppSpacing.x3),
                  fillColor: AppColors.surface,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.neutral300,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.neutral300,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(
                      color: AppColors.primary600,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              if (problem != null) ...<Widget>[
                const SizedBox(height: AppSpacing.x2),
                Text(
                  problem,
                  key: const Key('reset-pin-error'),
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.x1),
              const Text(
                'This reset is recorded in the audit log.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.x5),
              Opacity(
                opacity: _canSubmit ? 1.0 : 0.4,
                child: SizedBox(
                  height: AppSizes.controlHeight,
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('btn-reset-pin-submit'),
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: AppColors.neutral0,
                      disabledBackgroundColor: AppColors.primary600,
                      disabledForegroundColor: AppColors.neutral0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.neutral0,
                            ),
                          )
                        : Text(
                            'Set temporary PIN',
                            style: AppTypography.label.copyWith(
                              color: AppColors.neutral0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x1 + 2),
              SizedBox(
                height: AppSizes.controlHeight,
                width: double.infinity,
                child: TextButton(
                  key: const Key('btn-reset-pin-cancel'),
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.neutral500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTypography.label.copyWith(
                      color: AppColors.neutral500,
                      fontWeight: FontWeight.w500,
                    ),
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
