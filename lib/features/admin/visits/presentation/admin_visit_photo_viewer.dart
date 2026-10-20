import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/entities/visit_record.dart';
import 'controllers/visit_photo_source.dart';
import 'widgets/visit_photo.dart';

/// The visit photo full screen, with pinch and drag to look closer.
class AdminVisitPhotoViewer extends StatelessWidget {
  const AdminVisitPhotoViewer({super.key, required this.visit});

  final VisitRecord visit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral900,
      appBar: AppBar(
        backgroundColor: AppColors.neutral900,
        foregroundColor: AppColors.neutral0,
        leading: IconButton(
          key: const Key('btn-visit-photo-close'),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: VisitPhoto(
            visit: visit,
            size: VisitPhotoSize.full,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
