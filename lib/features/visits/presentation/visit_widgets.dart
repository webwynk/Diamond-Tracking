import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../requests/data/photo_upload.dart';
import '../application/visits_providers.dart';
import '../domain/visit.dart';

/// "Camera photo at 22.57261, 88.36389" or "Gallery photo, no location".
/// A location from a fake-location app says so first; a poor one ends with
/// "(approximate, ±300 m)" (L59).
String visitPlace(Visit v) {
  final String approx = v.isApproximate
      ? ' (approximate, ±${v.accuracyM} m)'
      : '';
  return switch (v.location) {
    final p? when v.mocked =>
      'Fake GPS: camera photo at ${formatPoint(p)}$approx',
    final p? => 'Camera photo at ${formatPoint(p)}$approx',
    null => 'Gallery photo, no location',
  };
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
    final PhotoSource src = ref
        .watch(visitsRepositoryProvider)
        .photo(visitId, small: small);
    return Image.network(
      src.url,
      headers: src.headers,
      fit: fit,
      cacheWidth: small ? 144 : null,
      errorBuilder: (_, _, _) => small
          ? const ColoredBox(
              color: Color(0xFFCBD5E1),
              child: Icon(DsIcons.gallery, size: 18, color: DsColors.text2),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(DsSpace.lg),
                child: Text(
                  "Couldn't load the photo",
                  style: DsText.body.copyWith(color: DsColors.white),
                ),
              ),
            ),
      loadingBuilder: (_, Widget child, ImageChunkEvent? p) => p == null
          ? child
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
