import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_attendance_state.dart';

/// Single day attendance log card for Screen 22.
class AdminAttendanceDailyCard extends StatelessWidget {
  const AdminAttendanceDailyCard({
    super.key,
    required this.item,
    this.onTap,
  });

  final AdminDailyAttendanceItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (item.isAbsent) {
      return _buildAbsentCard();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          children: <Widget>[
            if (item.isAutoEnded)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: AppColors.warning,
                ),
              ),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                key: Key('attendance-card-${item.id}'),
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // 1. Date Block (44x44 dp)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.neutral50,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.neutral200, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        item.dayNumber,
                        style: AppTypography.title.copyWith(
                          color: AppColors.neutral900,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.dayOfWeek,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral500,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x4),

                // 2. Middle Content (Sessions + Stats)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (item.isMultiSession) ...[
                        // Multi-session layout
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                item.sessions.first.timeRange,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.neutral900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x1 + 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.infoBg,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                              ),
                              child: Text(
                                '2 SESSIONS',
                                style: AppTypography.overline.copyWith(
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.sessions.length > 1) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.sessions[1].timeRange,
                            style: AppTypography.body.copyWith(
                              color: AppColors.neutral900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ] else ...[
                        // Single session layout
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                item.sessions.isNotEmpty
                                    ? item.sessions.first.timeRange
                                    : '',
                                style: AppTypography.body.copyWith(
                                  color: AppColors.neutral900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x2),
                            if (item.isAutoEnded) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.warningBg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.warning,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'AUTO-ENDED',
                                      style: AppTypography.overline.copyWith(
                                        color: AppColors.warningText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      // Stats Row
                      const SizedBox(height: 4),
                      Text(
                        item.statsText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),

                      // Optional Alert Note
                      if (item.alertNote != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.alertNote!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warningText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),

                // 3. Right Trailing (Warning Icon + Chevron)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (item.isAutoEnded)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                      ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.neutral300,
                      size: 22,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
);
  }

  Widget _buildAbsentCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Row(
        children: <Widget>[
          // Dimmed Date Block
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.neutral200, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  item.dayNumber,
                  style: AppTypography.title.copyWith(
                    color: AppColors.neutral400,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.dayOfWeek,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral400,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x4),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'No duty recorded',
                  style: AppTypography.body.copyWith(
                    color: AppColors.neutral400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.statsText,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.neutral400,
                  ),
                ),
              ],
            ),
          ),

          // "Off" Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'OFF',
              style: AppTypography.overline.copyWith(
                color: AppColors.neutral500,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
