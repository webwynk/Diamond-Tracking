import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../domain/entities/visit_record.dart';
import '../../../employees/presentation/widgets/admin_profile_section.dart';
import '../controllers/admin_visits_state.dart';
import 'admin_visit_tile.dart';

/// The "Visits" card on the employee profile (Screen 18): the latest few visits
/// and a way to see them all.
class AdminVisitsCard extends StatelessWidget {
  const AdminVisitsCard({
    super.key,
    required this.state,
    required this.onViewAll,
    required this.onVisitSelected,
  });

  /// How many visits the card shows; the rest are behind "View all".
  static const int shown = 3;

  final AdminVisitsState state;
  final VoidCallback onViewAll;
  final ValueChanged<VisitRecord> onVisitSelected;

  @override
  Widget build(BuildContext context) {
    final visits = state.visits.take(shown).toList();
    return AdminProfileSection(
      title: 'Visits',
      trailing: AdminProfileSectionLink(
        key: const Key('btn-visits-view-all'),
        label: 'View all',
        onPressed: onViewAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (visits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
              child: Text(
                switch (state.load) {
                  AdminVisitsLoad.loading => 'Loading…',
                  AdminVisitsLoad.failed => "Couldn't load visits.",
                  AdminVisitsLoad.loaded => 'No visits yet.',
                },
                key: const Key('text-visits-empty'),
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          for (var i = 0; i < visits.length; i++) ...<Widget>[
            if (i > 0) const Divider(color: AppColors.border, height: 1),
            AdminVisitTile(
              visit: visits[i],
              onTap: () => onVisitSelected(visits[i]),
            ),
          ],
        ],
      ),
    );
  }
}
