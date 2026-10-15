import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';

/// 56 dp white top app bar for Screen 22 (Duty History & Attendance — Admin).
class AdminAttendanceTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAttendanceTopBar({
    super.key,
    required this.onBack,
    required this.onExport,
  });

  final VoidCallback onBack;
  final VoidCallback onExport;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Back Button + Title
              Expanded(
                child: Row(
                  children: <Widget>[
                    IconButton(
                      key: const Key('btn-attendance-back'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primary600,
                        size: 24,
                      ),
                      onPressed: onBack,
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: AppSpacing.x1),
                    Flexible(
                      child: Text(
                        'Attendance & History',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.neutral900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Export/Download Report Action
              IconButton(
                key: const Key('btn-attendance-export'),
                icon: const Icon(
                  Icons.download_rounded,
                  color: AppColors.neutral700,
                  size: 22,
                ),
                onPressed: onExport,
                tooltip: 'Export Report',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
