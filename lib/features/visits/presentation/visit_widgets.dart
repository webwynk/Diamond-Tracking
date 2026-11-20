import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/ist_format.dart';
import '../../requests/data/photo_upload.dart';
import '../application/visits_providers.dart';
import '../domain/visit.dart';

/// "Camera photo at 22.57261, 88.36389" or "Gallery photo, no location".
String visitPlace(Visit v) => switch (v.location) {
  final p? => 'Camera photo at ${formatPoint(p)}',
  null => 'Gallery photo, no location',
};

/// One visit in a list: thumbnail, store, time. Tap for the full visit.
class VisitTile extends StatelessWidget {
  const VisitTile({required this.visit, super.key});

  final Visit visit;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: visit.showsPhoto
            ? VisitPhoto(visitId: visit.id, fit: BoxFit.cover, small: true)
            : const ColoredBox(
                color: AppColors.neutral100,
                child: Icon(Icons.storefront_rounded),
              ),
      ),
    ),
    title: Text(visit.storeName),
    subtitle: Text(
      'Visit ${IstFormat.time(visit.capturedAt)}'
      '${visit.location == null ? ' · no location' : ''}',
    ),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => VisitDetailPage(visit: visit)),
    ),
  );
}

/// A visit's photo, loaded through the photos function.
class VisitPhoto extends ConsumerWidget {
  const VisitPhoto({
    required this.visitId,
    super.key,
    this.fit = BoxFit.cover,
    this.small = false,
  });

  final String visitId;
  final BoxFit fit;
  final bool small;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PhotoSource src = ref.watch(visitsRepositoryProvider).photo(visitId);
    return Image.network(
      src.url,
      headers: src.headers,
      fit: fit,
      cacheWidth: small ? 144 : null,
      errorBuilder: (_, _, _) => small
          ? const ColoredBox(
              color: AppColors.neutral100,
              child: Icon(Icons.broken_image_rounded),
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.x4),
                child: Text('The photo could not be loaded.'),
              ),
            ),
      loadingBuilder: (_, Widget child, ImageChunkEvent? p) => p == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

/// The whole visit: the photo (zoomable), store, note, time and place.
class VisitDetailPage extends StatelessWidget {
  const VisitDetailPage({required this.visit, super.key});

  final Visit visit;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(visit.storeName)),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 360,
            color: AppColors.neutral100,
            child: visit.showsPhoto
                ? InteractiveViewer(
                    child: VisitPhoto(visitId: visit.id, fit: BoxFit.contain),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.x4),
                      child: Text(
                        'Photos are deleted after 90 days.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        Text(visit.storeName, style: AppTypography.title),
        const SizedBox(height: AppSpacing.x1),
        Text(
          '${IstFormat.shortDate(visit.capturedAt)}, '
          '${IstFormat.time(visit.capturedAt)}',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.x3),
        Row(
          children: <Widget>[
            Icon(
              visit.location == null
                  ? Icons.location_off_rounded
                  : Icons.location_on_rounded,
              size: 20,
              color: visit.location == null
                  ? AppColors.textSecondary
                  : AppColors.success,
            ),
            const SizedBox(width: AppSpacing.x2),
            Expanded(child: Text(visitPlace(visit))),
          ],
        ),
        if (visit.note case final String note) ...<Widget>[
          const SizedBox(height: AppSpacing.x3),
          Text(note),
        ],
      ],
    ),
  );
}

/// A day's visits as a list section, for the day page.
class DayVisitsSection extends ConsumerWidget {
  const DayVisitsSection({required this.dayId, super.key});

  final int dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Visit>> visits = ref.watch(dayVisitsProvider(dayId));
    return visits.when(
      skipLoadingOnRefresh: true,
      data: (List<Visit> list) => list.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppSpacing.x4),
                Text('Visits (${list.length})', style: AppTypography.title),
                for (final Visit v in list) VisitTile(visit: v),
              ],
            ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x4),
        child: Row(
          children: <Widget>[
            const Expanded(child: Text('Visits could not be loaded.')),
            TextButton(
              onPressed: () => ref.invalidate(dayVisitsProvider(dayId)),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
    );
  }
}
