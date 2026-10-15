import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_employee_list_state.dart';

/// Screen 20 — Block Employee Confirmation Bottom Sheet.
///
/// A high-consequence modal bottom sheet for blocking an employee with:
/// - Centered drag handle
/// - 56 dp circular red badge with block icon
/// - H3 20px title and employee code subtitle
/// - #FEE2E2 consequence alert panel with 3 bullet items
/// - Multi-line required reason input field with character and audit helper
/// - Primary destructive button (disabled at 40% opacity until reason provided)
/// - Cancel text button
class AdminBlockEmployeeSheet extends StatefulWidget {
  const AdminBlockEmployeeSheet({
    super.key,
    required this.employee,
    required this.onConfirmBlock,
  });

  final AdminEmployeeItem employee;
  final Future<void> Function(String reason) onConfirmBlock;

  /// Convenience helper to display the sheet as a modal bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    required AdminEmployeeItem employee,
    required Future<void> Function(String reason) onConfirmBlock,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (ctx) => AdminBlockEmployeeSheet(
        employee: employee,
        onConfirmBlock: onConfirmBlock,
      ),
    );
  }

  @override
  State<AdminBlockEmployeeSheet> createState() => _AdminBlockEmployeeSheetState();
}

class _AdminBlockEmployeeSheetState extends State<AdminBlockEmployeeSheet> {
  late final TextEditingController _reasonController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _reasonController.text.trim().isNotEmpty;

  Future<void> _handleBlock() async {
    if (!_canSubmit || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onConfirmBlock(_reasonController.text.trim());
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
              // Centered 32x4 dp drag handle
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

              // Centered 56x56 circular red warning badge
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.errorBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block_rounded,
                    color: AppColors.error,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x3),

              // Title and Employee Code
              Text(
                'Block ${widget.employee.name}?',
                key: const Key('block-sheet-title'),
                textAlign: TextAlign.center,
                style: AppTypography.h3.copyWith(
                  color: AppColors.neutral900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.employee.employeeCode,
                key: const Key('block-sheet-code'),
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: AppSpacing.x5),

              // Consequence Alert Panel (#FEE2E2)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'This will immediately:',
                      style: AppTypography.label.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2 + 2),
                    _buildConsequenceRow('End their current duty session'),
                    const SizedBox(height: AppSpacing.x2),
                    _buildConsequenceRow('Stop location tracking'),
                    const SizedBox(height: AppSpacing.x2),
                    _buildConsequenceRow('Prevent them from logging in'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.x4),

              // Reason Form Field
              Text(
                'Reason (required)',
                style: AppTypography.label.copyWith(
                  color: AppColors.neutral500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.x1 + 2),
              SizedBox(
                height: 96,
                child: TextField(
                  key: const Key('input-block-reason'),
                  controller: _reasonController,
                  maxLines: 3,
                  minLines: 3,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.neutral900,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Why is this employee being blocked?',
                    hintStyle: AppTypography.bodyLarge.copyWith(
                      color: AppColors.neutral400,
                    ),
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
              ),
              const SizedBox(height: AppSpacing.x1),
              const Text(
                'This reason is recorded in the audit log.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.x5),

              // Action Buttons
              // Primary Destructive Button: Block employee
              Opacity(
                opacity: _canSubmit ? 1.0 : 0.4,
                child: SizedBox(
                  height: AppSizes.controlHeight,
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('btn-block-submit'),
                    onPressed: _canSubmit && !_isLoading ? _handleBlock : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.neutral0,
                      disabledBackgroundColor: AppColors.error,
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
                            'Block employee',
                            style: AppTypography.label.copyWith(
                              color: AppColors.neutral0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.x1 + 2),

              // Secondary Text Button: Cancel
              SizedBox(
                height: AppSizes.controlHeight,
                width: double.infinity,
                child: TextButton(
                  key: const Key('btn-block-cancel'),
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
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
              const SizedBox(height: AppSpacing.x2),

              // Bottom Home Indicator
              Center(
                child: Container(
                  width: 128,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neutral300,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsequenceRow(String text) {
    return Row(
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.x2 + 2),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(
              color: AppColors.neutral900,
            ),
          ),
        ),
      ],
    );
  }
}
