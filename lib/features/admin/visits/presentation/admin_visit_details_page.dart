import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../domain/entities/visit_record.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import 'admin_visit_photo_viewer.dart';
import 'admin_visit_presenter.dart';
import 'controllers/visit_photo_source.dart';
import 'widgets/admin_visit_map_card.dart';
import 'widgets/visit_photo.dart';

/// One visit in full (PRD F10): the photo (tap to enlarge), store, when (IST),
/// note, and where it happened on a map.
class AdminVisitDetailsPage extends StatelessWidget {
  const AdminVisitDetailsPage({
    super.key,
    required this.visit,
    required this.employeeName,
  });

  final VisitRecord visit;
  final String employeeName;

  void _enlarge(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AdminVisitPhotoViewer(visit: visit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final note = visit.note?.trim();
    final accuracy = AdminVisitPresenter.accuracy(visit);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        leading: AppTopBarLeading.back,
        leadingKey: const Key('btn-visit-details-back'),
        title: 'Visit details',
        subtitle: employeeName,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ClipRRect(
              borderRadius: AppRadius.lgAll,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: GestureDetector(
                  key: const Key('visit-photo-enlarge'),
                  onTap: visit.hasRemotePhoto ? () => _enlarge(context) : null,
                  child: VisitPhoto(visit: visit, size: VisitPhotoSize.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _field('Store', AdminVisitPresenter.title(visit)),
                  _field('Date and time', AdminVisitPresenter.when(visit)),
                  _field(
                    'Note',
                    note == null || note.isEmpty ? 'No note' : note,
                  ),
                  _field(
                    'Position',
                    accuracy == null
                        ? AdminVisitPresenter.coordinates(visit)
                        : '${AdminVisitPresenter.coordinates(visit)}  '
                              '($accuracy)',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            AdminVisitMapCard(
              latitude: visit.latitude,
              longitude: visit.longitude,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : AppSpacing.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTypography.overline.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
