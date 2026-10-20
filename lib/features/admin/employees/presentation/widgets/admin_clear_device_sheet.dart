import 'package:flutter/material.dart';

import '../../../../../core/errors/app_exceptions.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_employee_list_state.dart';

/// Bottom sheet that asks an admin to confirm clearing an employee's registered
/// phone (BR-13), for when the employee has a new phone.
///
/// Pops with the server's answer: `true` when a phone was cleared, `false` when
/// none was registered, and `null` when the admin cancelled.
class AdminClearDeviceSheet extends StatefulWidget {
  const AdminClearDeviceSheet({
    super.key,
    required this.employee,
    required this.onConfirm,
  });

  final AdminEmployeeItem employee;

  /// Clears the phone on the server and returns what the server said.
  final Future<bool> Function() onConfirm;

  static Future<bool?> show(
    BuildContext context, {
    required AdminEmployeeItem employee,
    required Future<bool> Function() onConfirm,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (ctx) =>
          AdminClearDeviceSheet(employee: employee, onConfirm: onConfirm),
    );
  }

  @override
  State<AdminClearDeviceSheet> createState() => _AdminClearDeviceSheetState();
}

class _AdminClearDeviceSheetState extends State<AdminClearDeviceSheet> {
  bool _isLoading = false;
  String? _errorText;

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final cleared = await widget.onConfirm();
      if (mounted) Navigator.of(context).pop(cleared);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = e is AppException
              ? e.message
              : 'Could not clear the device binding. Please try again.';
        });
      }
    }
  }

  Widget _row(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: AppColors.primary600,
          ),
        ),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(color: AppColors.neutral700),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  Icons.phonelink_erase_rounded,
                  color: AppColors.primary600,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            Text(
              'Clear device binding for ${widget.employee.name}?',
              key: const Key('clear-device-title'),
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
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _row('They are signed out of their current phone.'),
                  const SizedBox(height: AppSpacing.x2),
                  _row(
                    'The next phone they sign in on becomes their registered '
                    'phone.',
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  _row(
                    'Clear it when they are ready to sign in on the new one.',
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  _row('This is recorded in the audit log.'),
                ],
              ),
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: AppSpacing.x3),
              Text(
                _errorText!,
                key: const Key('clear-device-error'),
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.x5),
            SizedBox(
              height: AppSizes.controlHeight,
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('btn-clear-device-submit'),
                onPressed: _isLoading ? null : _submit,
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
                        'Clear device binding',
                        style: AppTypography.label.copyWith(
                          color: AppColors.neutral0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.x1 + 2),
            SizedBox(
              height: AppSizes.controlHeight,
              width: double.infinity,
              child: TextButton(
                key: const Key('btn-clear-device-cancel'),
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
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
    );
  }
}
