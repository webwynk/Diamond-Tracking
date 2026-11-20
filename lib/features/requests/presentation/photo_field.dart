import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_log.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../application/requests_providers.dart';
import '../data/photo_picker.dart';

/// Take a photo or pick one from the gallery, with a preview.
class PhotoField extends ConsumerWidget {
  const PhotoField({
    required this.label,
    required this.photo,
    required this.onChanged,
    super.key,
    this.enabled = true,
    this.onPicked,
  });

  final String label;
  final Uint8List? photo;
  final ValueChanged<Uint8List?> onChanged;
  final bool enabled;

  /// Told whether a new photo came from the camera or the gallery.
  final ValueChanged<PhotoFrom>? onPicked;

  Future<void> _pick(WidgetRef ref, PhotoFrom from) async {
    try {
      final Uint8List? bytes = await ref.read(photoPickerProvider).pick(from);
      if (bytes == null) return;
      onPicked?.call(from);
      onChanged(bytes);
    } on Object catch (e, s) {
      // Camera permission refused, or the picker was closed oddly.
      AppLog.failure('pick photo', e, s);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Uint8List? p = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppTypography.label),
        const SizedBox(height: AppSpacing.x2),
        if (p != null) ...<Widget>[
          Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  p,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 180,
                    color: AppColors.neutral100,
                    alignment: Alignment.center,
                    child: const Text('Photo added'),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton.filledTonal(
                  tooltip: 'Remove photo',
                  onPressed: enabled ? () => onChanged(null) : null,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? () => _pick(ref, PhotoFrom.camera) : null,
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled ? () => _pick(ref, PhotoFrom.gallery) : null,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
