import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../domain/entities/live_position.dart';
import '../../../map/presentation/controllers/admin_live_map_state.dart';
import '../../../map/presentation/widgets/live_officer_card.dart';

/// Live Map shortcut card on the dashboard: who is on duty right now.
///
/// It draws no map of its own (a map inside a scrolling page fights the scroll
/// and costs memory, docs/07 section 6). It lists the first few people on duty
/// with how fresh their position is, and opens the Map tab from its header or
/// body. The "No one is on duty" prompt appears only when that is true.
class AdminMapPreviewCard extends StatelessWidget {
  const AdminMapPreviewCard({
    super.key,
    required this.onViewMap,
    this.officers = const <LiveOfficer>[],
    this.isLoading = false,
    this.errorMessage,
  });

  /// How many people are listed before "+N more".
  static const int maxRows = 3;

  final VoidCallback onViewMap;
  final List<LiveOfficer> officers;

  /// First load in progress: shown instead of "No one is on duty".
  final bool isLoading;

  /// The first load failed: shown instead of "No one is on duty".
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onViewMap,
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      Text(
                        'Live map',
                        style: AppTypography.title.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'View all',
                        style: AppTypography.label.copyWith(
                          color: AppColors.primary600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.primary600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            key: const Key('admin-live-map-preview-tap'),
            onTap: onViewMap,
            child: Container(
              width: double.infinity,
              color: AppColors.neutral50,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
            key: Key('preview-loading'),
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (errorMessage != null) {
      return _prompt(
        key: const Key('preview-error'),
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load who is on duty",
        hint: 'Open the Live map to try again.',
      );
    }
    if (officers.isEmpty) {
      return _prompt(
        icon: Icons.location_off_outlined,
        title: 'No one is on duty',
        hint: 'Officers appear here once they start duty.',
      );
    }

    final shown = officers.take(maxRows).toList();
    final more = officers.length - shown.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Column(
        children: [
          for (final officer in shown) _row(officer),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
                vertical: AppSpacing.x2,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '+$more more on duty',
                  key: const Key('preview-more'),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(LiveOfficer officer) {
    final key = liveStatusKey(officer.status);
    final colour = AppStatusColors.colours[key] ?? AppColors.neutral400;
    final needsWords = officer.status != LiveStatus.active;
    return Padding(
      key: Key('preview-officer-${officer.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  officer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Status is colour AND words (docs/03).
                if (needsWords)
                  Text(
                    AppStatusColors.labels[key] ?? '',
                    style: AppTypography.caption.copyWith(color: colour),
                  ),
              ],
            ),
          ),
          Text(
            officer.lastSeen,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prompt({
    Key? key,
    required IconData icon,
    required String title,
    required String hint,
  }) {
    return SizedBox(
      key: key,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: AppColors.textDisabled),
          const SizedBox(height: AppSpacing.x2),
          Text(
            title,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            hint,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
