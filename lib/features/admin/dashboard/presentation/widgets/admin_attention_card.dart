import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../controllers/admin_attention.dart';

/// "Needs attention": the few people an admin may want to look at now, taken
/// from the live feed (fake GPS, gone quiet, low battery). Shown only when
/// there is someone to list. Tapping a person opens the map on them.
class AdminAttentionCard extends StatelessWidget {
  const AdminAttentionCard({
    super.key,
    required this.items,
    required this.onOpen,
  });

  /// How many people are listed before "+N more".
  static const int maxRows = 3;

  final List<AttentionItem> items;
  final void Function(AttentionItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(maxRows).toList();
    final more = items.length - shown.length;

    return Container(
      key: const Key('dashboard-attention'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.neutral200, width: 1),
        boxShadow: AppElevation.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x3,
              AppSpacing.x4,
              AppSpacing.x1,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.warningBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.priority_high_rounded,
                    size: 16,
                    color: AppColors.warningText,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: Text(
                    'Needs attention',
                    style: AppTypography.title.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${items.length}',
                  key: const Key('attention-count'),
                  style: AppTypography.label.copyWith(
                    color: AppColors.warningText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (final item in shown) _Row(item: item, onOpen: onOpen),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x1,
                AppSpacing.x4,
                AppSpacing.x3,
              ),
              child: Text(
                '+$more more',
                key: const Key('attention-more'),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            const SizedBox(height: AppSpacing.x2),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.onOpen});

  final AttentionItem item;
  final void Function(AttentionItem item) onOpen;

  @override
  Widget build(BuildContext context) {
    final (colour, tint) = switch (item.reason) {
      AttentionReason.fakeGps => (AppColors.error, AppColors.errorBg),
      AttentionReason.noUpdate => (AppColors.warningText, AppColors.warningBg),
      AttentionReason.lowBattery => (
        AppColors.warningText,
        AppColors.warningBg,
      ),
    };
    final icon = switch (item.reason) {
      AttentionReason.fakeGps => Icons.gpp_maybe_rounded,
      AttentionReason.noUpdate => Icons.signal_wifi_off_rounded,
      AttentionReason.lowBattery => Icons.battery_alert_rounded,
    };

    return InkWell(
      key: Key('attention-row-${item.officer.id}'),
      onTap: () => onOpen(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: colour),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.officer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: colour),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }
}
