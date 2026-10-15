import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import 'controllers/admin_employee_form_controller.dart';
import 'controllers/admin_employee_list_state.dart';
import 'widgets/admin_employee_details_card.dart';
import 'widgets/admin_employee_form_top_bar.dart';
import 'widgets/admin_employee_info_strip.dart';
import 'widgets/admin_employee_login_card.dart';
import 'widgets/admin_employee_role_card.dart';
import 'widgets/admin_employee_telemetry_preview_card.dart';

/// Screen 19: Create / Edit Employee (Admin)
///
/// Comprehensive administrative management form to provision or edit field staff.
class AdminEmployeeFormPage extends ConsumerStatefulWidget {
  const AdminEmployeeFormPage({
    super.key,
    this.employee,
  });

  final AdminEmployeeItem? employee;

  @override
  ConsumerState<AdminEmployeeFormPage> createState() =>
      _AdminEmployeeFormPageState();
}

class _AdminEmployeeFormPageState extends ConsumerState<AdminEmployeeFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _idController;
  late final TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    final initial = widget.employee;
    _nameController = TextEditingController(text: initial?.name ?? 'Kiran Deshmukh');
    _phoneController =
        TextEditingController(text: initial?.phoneNumber ?? '+91 98220 11334');
    _emailController = TextEditingController(
      text: initial?.email ??
          (initial != null
              ? '${initial.name.toLowerCase().replaceAll(' ', '.')}@diamondagritech.in'
              : 'kiran.d@diamondagritech.in'),
    );
    _idController =
        TextEditingController(text: initial?.employeeCode ?? 'DA-144');
    _pinController = TextEditingController(text: initial != null ? '******' : '849201');

    Future.microtask(() {
      if (mounted) {
        ref
            .read(adminEmployeeFormControllerProvider.notifier)
            .initForm(employee: widget.employee);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final notifier = ref.read(adminEmployeeFormControllerProvider.notifier);
    final success = await notifier.submit();
    if (success && mounted) {
      final state = ref.read(adminEmployeeFormControllerProvider);
      final isEdit = widget.employee != null || state.isEditMode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Employee ${state.employeeCode} updated successfully!'
                : 'Employee ${state.employeeCode} created successfully!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(adminEmployeeFormControllerProvider);
    final notifier = ref.read(adminEmployeeFormControllerProvider.notifier);
    final isEditMode = widget.employee != null || formState.isEditMode;

    // Keep controllers in sync when PIN is regenerated
    ref.listen<String>(
      adminEmployeeFormControllerProvider.select((s) => s.initialPin),
      (prev, next) {
        if (_pinController.text != next) {
          _pinController.text = next;
        }
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminEmployeeFormTopBar(
        isEditMode: isEditMode,
        isValid: formState.isValid,
        isSaving: formState.isSaving,
        onClose: () => Navigator.of(context).pop(),
        onSave: _handleSubmit,
      ),
      body: Stack(
        children: <Widget>[
          // Scrollable Form Canvas
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppSpacing.x4,
              right: AppSpacing.x4,
              top: AppSpacing.x4,
              bottom: 120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Card 1: EMPLOYEE DETAILS
                AdminEmployeeDetailsCard(
                  nameController: _nameController,
                  phoneController: _phoneController,
                  emailController: _emailController,
                  onNameChanged: notifier.setFullName,
                  onPhoneChanged: notifier.setPhoneNumber,
                  onEmailChanged: notifier.setEmail,
                ),
                const SizedBox(height: AppSpacing.x4),

                // Card 2: LOGIN CREDENTIALS
                AdminEmployeeLoginCard(
                  employeeIdController: _idController,
                  pinController: _pinController,
                  isEmployeeCodeAvailable: formState.isEmployeeCodeAvailable,
                  onEmployeeIdChanged: notifier.setEmployeeCode,
                  onPinChanged: (val) {
                    if (val.length <= 6) {
                      notifier.regeneratePin();
                    }
                  },
                  onRegeneratePin: notifier.regeneratePin,
                ),
                const SizedBox(height: AppSpacing.x4),

                // Card 3: ROLE SELECTION
                AdminEmployeeRoleCard(
                  selectedRole: formState.role,
                  onRoleChanged: notifier.setRole,
                ),
                const SizedBox(height: AppSpacing.x4),

                // Informational Notice Strip
                const AdminEmployeeInfoStrip(),
                const SizedBox(height: AppSpacing.x3),

                // Telemetry Diagnostic Preview
                const AdminEmployeeTelemetryPreviewCard(),
              ],
            ),
          ),

          // Pinned Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.neutral200),
                ),
              ),
              padding: EdgeInsets.only(
                left: AppSpacing.x4,
                right: AppSpacing.x4,
                top: AppSpacing.x3,
                bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.x3,
              ),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  key: const Key('admin-employee-form-submit-btn'),
                  onPressed:
                      formState.isValid && !formState.isSaving ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    disabledBackgroundColor:
                        AppColors.neutral400.withValues(alpha: 0.5),
                    foregroundColor: AppColors.neutral0,
                    disabledForegroundColor: AppColors.neutral0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                    elevation: 0,
                  ),
                  child: formState.isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.neutral0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Provisioning ${formState.employeeCode}...',
                              style: AppTypography.label.copyWith(
                                color: AppColors.neutral0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              isEditMode
                                  ? Icons.save_rounded
                                  : Icons.person_add_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isEditMode
                                  ? 'Save changes'
                                  : 'Create employee',
                              style: AppTypography.label.copyWith(
                                color: AppColors.neutral0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
