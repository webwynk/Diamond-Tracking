import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../domain/entities/visit_record.dart';
import '../admin_visit_presenter.dart';
import 'visit_photo.dart';

/// One visit as a row: thumbnail (or why there is none), store name, when, note.
class AdminVisitTile extends StatelessWidget {
  const AdminVisitTile({super.key, required this.visit, required this.onTap});

  static const double _thumb = 56;

  final VisitRecord visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final caption = AdminVisitPresenter.photoCaption(visit);
    final note = visit.note?.trim();
    return InkWell(
      key: Key('visit-tile-${visit.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: SizedBox(
                width: _thumb,
                height: _thumb,
                child: VisitPhoto(visit: visit, compact: true),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AdminVisitPresenter.title(visit),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.semiBold.withColor(
                      AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AdminVisitPresenter.when(visit),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (note != null && note.isNotEmpty)
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (caption != null)
                    Text(
                      caption,
                      key: Key('visit-caption-${visit.id}'),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}
