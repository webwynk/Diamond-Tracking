import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_employee_list_state.dart';
import 'admin_profile_section.dart';

/// Screen 18 "Contact": the employee's phone and email, each with a Copy
/// button that really copies it. Nothing pretends to dial or send.
class AdminEmployeeContactCard extends StatelessWidget {
  const AdminEmployeeContactCard({super.key, required this.employee});

  final AdminEmployeeItem employee;

  @override
  Widget build(BuildContext context) {
    final email = employee.email?.trim();
    final hasEmail = email != null && email.isNotEmpty;
    return AdminProfileSection(
      title: 'Contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _ContactRow(
            key: const Key('row-contact-phone'),
            copyKey: const Key('btn-copy-phone'),
            icon: Icons.call_outlined,
            label: 'Phone',
            value: employee.phoneNumber,
            copiedMessage: 'Phone number copied',
          ),
          const Divider(color: AppColors.border, height: 1),
          _ContactRow(
            key: const Key('row-contact-email'),
            copyKey: const Key('btn-copy-email'),
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: hasEmail ? email : '—',
            copiedMessage: hasEmail ? 'Email copied' : null,
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    super.key,
    required this.copyKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.copiedMessage,
  });

  static const double _badge = 40;

  final Key copyKey;
  final IconData icon;
  final String label;
  final String value;

  /// Null when there is nothing worth copying (no email on file).
  final String? copiedMessage;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: value));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copiedMessage!)));
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.listRowMinHeight),
      child: Row(
        children: <Widget>[
          Container(
            width: _badge,
            height: _badge,
            decoration: const BoxDecoration(
              color: AppColors.neutral100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: AppSizes.iconDense,
              color: AppColors.neutral600,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: AppTypography.caption.withColor(
                    AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.withColor(AppColors.textPrimary),
                ),
              ],
            ),
          ),
          if (copiedMessage != null)
            IconButton(
              key: copyKey,
              tooltip: 'Copy ${label.toLowerCase()}',
              icon: const Icon(
                Icons.copy_rounded,
                size: AppSizes.iconDense,
                color: AppColors.neutral600,
              ),
              onPressed: () => _copy(context),
            ),
        ],
      ),
    );
  }
}
