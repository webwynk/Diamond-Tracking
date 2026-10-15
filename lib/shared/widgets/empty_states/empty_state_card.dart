import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import 'empty_state_illustration.dart';
import 'empty_state_type.dart';

/// Screen 28 empty state card component with case header, vector illustration,
/// title, description, and action button.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.type,
    this.customTitle,
    this.customDescription,
    this.onActionPressed,
    this.showCaseHeader = true,
  });

  final EmptyStateType type;
  final String? customTitle;
  final String? customDescription;
  final VoidCallback? onActionPressed;
  final bool showCaseHeader;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 280,
        minWidth: 220,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Optional Case Header Strip (matching HTML reference Case bar)
          if (showCaseHeader) ...<Widget>[
            Container(
              padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.neutral200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      type.caseLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.overline.copyWith(
                        color: AppColors.neutral400,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    type.statusCode,
                    style: AppTypography.overline.copyWith(
                      color: AppColors.neutral500,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Card Box (300 dp min-height, 16 dp radius)
          Container(
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.all(AppSpacing.x4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.neutral200),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Content Group
                Column(
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.x2),

                    // 56x56 Vector Illustration
                    EmptyStateIllustration(type: type),

                    const SizedBox(height: AppSpacing.x4),

                    // Title
                    Text(
                      customTitle ?? type.title,
                      style: AppTypography.title.copyWith(
                        color: AppColors.neutral900,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    // Description (max-width 190 dp)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Text(
                        customDescription ?? type.defaultDescription,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.neutral500,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),

                // Bottom Action Button / Passive Badge
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x4),
                  child: _buildActionArea(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea(BuildContext context) {
    final actionLabel = type.actionLabel;
    final actionIcon = type.actionIcon;

    if (actionLabel != null) {
      if (type.isPrimaryAction) {
        // Filled Brand Primary Button
        return SizedBox(
          width: double.infinity,
          height: 36,
          child: ElevatedButton(
            key: Key('btn-empty-action-${type.name}'),
            onPressed: onActionPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: AppColors.surface,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (actionIcon != null) ...<Widget>[
                  Icon(actionIcon, size: 16, color: AppColors.surface),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Outlined 1.5 dp Button
        return SizedBox(
          width: double.infinity,
          height: 36,
          child: OutlinedButton(
            key: Key('btn-empty-action-${type.name}'),
            onPressed: onActionPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary600,
              side: const BorderSide(
                color: AppColors.primary600,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (actionIcon != null) ...<Widget>[
                  Icon(actionIcon, size: 16, color: AppColors.primary600),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Passive Status Badge for No Notifications case
    return Container(
      key: Key('badge-empty-pending-${type.name}'),
      height: 36,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0x99F8FAFC),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.neutral300,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.neutral400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            type.pendingBadgeText ?? 'NO ACTIONS PENDING',
            style: AppTypography.overline.copyWith(
              color: AppColors.neutral400,
              letterSpacing: 0.5,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
