import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/widgets/app_empty_state.dart';
import '../../../../../shared/widgets/app_status_pill.dart';
import '../controllers/admin_live_map_state.dart';
import 'live_officer_card.dart';

/// The list alternative to the live map (docs/07 section 9): the same people
/// the map is drawing, readable without a map, by screen reader, and when
/// tiles will not load.
class LiveOfficerListSheet extends StatelessWidget {
  const LiveOfficerListSheet({
    super.key,
    required this.officers,
    required this.onSelected,
  });

  final List<LiveOfficer> officers;
  final ValueChanged<LiveOfficer> onSelected;

  static Future<void> show(
    BuildContext context, {
    required List<LiveOfficer> officers,
    required ValueChanged<LiveOfficer> onSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlTop),
      builder: (sheetContext) => LiveOfficerListSheet(
        officers: officers,
        onSelected: (officer) {
          Navigator.of(sheetContext).pop();
          onSelected(officer);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x4,
                AppSpacing.x2,
                AppSpacing.x2,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'On duty now (${officers.length})',
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (officers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.x6),
                child: AppEmptyState.nobodyOnDuty(),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: officers.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColors.neutral200),
                  itemBuilder: (context, index) {
                    final officer = officers[index];
                    return ListTile(
                      key: Key('live-officer-row-${officer.id}'),
                      onTap: () => onSelected(officer),
                      title: Text(
                        officer.name,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (officer.employeeCode.isNotEmpty)
                            officer.employeeCode,
                          officer.lastSeen,
                        ].join(' · '),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: AppStatusPill(
                        statusKey: liveStatusKey(officer.status),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
