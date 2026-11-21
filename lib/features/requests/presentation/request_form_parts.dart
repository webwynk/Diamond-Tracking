import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/logging/app_log.dart';
import '../application/requests_providers.dart';
import '../data/photo_picker.dart';
import '../data/requests_repository.dart';

/// A white card on a request form: a 15 bold title, an optional tag on the
/// right, then the [child].
class RequestSection extends StatelessWidget {
  const RequestSection({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: const BoxDecoration(
      color: DsColors.white,
      borderRadius: DsRadius.large,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: DsText.body.copyWith(
                      fontWeight: FontWeight.w700,
                      fontVariations: const <FontVariation>[
                        FontVariation('wght', 700),
                      ],
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

/// A photo on a form: the picked bytes, and the photo id once uploaded so
/// a retry does not upload it again (L68).
class PickedPhoto {
  PickedPhoto(this.bytes);

  final Uint8List bytes;
  String? uploadedId;
}

/// Uploads the photos not uploaded yet and returns all their ids, in order.
Future<List<String>> uploadPhotos(
  RequestsRepository repo,
  List<PickedPhoto> photos,
) async => <String>[
  for (final PickedPhoto p in photos)
    p.uploadedId ??= await repo.uploadPhoto(p.bytes),
];

/// Up to [maxRequestPhotos] photos: small previews with a remove button,
/// then "Take photo" (brand blue) and "From gallery" while there is room.
class RequestPhotos extends ConsumerWidget {
  const RequestPhotos({
    required this.photos,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<PickedPhoto> photos;
  final ValueChanged<List<PickedPhoto>> onChanged;
  final bool enabled;

  Future<void> _pick(WidgetRef ref, PhotoFrom from) async {
    try {
      final Uint8List? bytes = await ref.read(photoPickerProvider).pick(from);
      if (bytes == null) return;
      onChanged(<PickedPhoto>[...photos, PickedPhoto(bytes)]);
    } on Object catch (e, s) {
      // Camera permission refused, or the picker was closed oddly.
      AppLog.failure('pick photo', e, s);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool room = photos.length < maxRequestPhotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (photos.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              for (int i = 0; i < maxRequestPhotos; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: DsSpace.sm),
                Expanded(
                  child: i < photos.length
                      ? _Thumb(
                          photo: photos[i],
                          number: i + 1,
                          onRemove: enabled
                              ? () => onChanged(
                                  <PickedPhoto>[...photos]..removeAt(i),
                                )
                              : null,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (room)
          Row(
            children: <Widget>[
              Expanded(
                child: _PickTile(
                  icon: DsIcons.camera,
                  label: 'Take photo',
                  primary: true,
                  onTap: enabled ? () => _pick(ref, PhotoFrom.camera) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickTile(
                  icon: DsIcons.gallery,
                  label: 'From gallery',
                  onTap: enabled ? () => _pick(ref, PhotoFrom.gallery) : null,
                ),
              ),
            ],
          ),
        const SizedBox(height: DsSpace.sm),
        Text(
          room
              ? 'Up to $maxRequestPhotos photos · ${photos.length} added'
              : '$maxRequestPhotos photos added, the most allowed',
          textAlign: TextAlign.center,
          style: DsText.caption,
        ),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.photo,
    required this.number,
    required this.onRemove,
  });

  final PickedPhoto photo;
  final int number;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1,
    child: Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ClipRRect(
          borderRadius: DsRadius.medium,
          child: Image.memory(
            photo.bytes,
            fit: BoxFit.cover,
            semanticLabel: 'Photo $number',
            errorBuilder: (_, _, _) => Container(
              color: DsColors.primaryTint,
              alignment: Alignment.center,
              child: const Icon(
                DsIcons.camera,
                size: 22,
                color: DsColors.primary,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Semantics(
            button: true,
            label: 'Remove photo $number',
            excludeSemantics: true,
            child: InkResponse(
              onTap: onRemove,
              radius: 24,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: DsColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    DsIcons.close,
                    size: 14,
                    color: DsColors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: primary ? DsColors.primary : DsColors.primaryTint,
      borderRadius: DsRadius.large,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary ? const Color(0xFF1C7CA3) : DsColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: primary ? DsColors.white : DsColors.primary,
                ),
              ),
              const SizedBox(height: DsSpace.sm),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsText.button.copyWith(
                  fontSize: 15,
                  color: primary ? DsColors.white : DsColors.deep,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
