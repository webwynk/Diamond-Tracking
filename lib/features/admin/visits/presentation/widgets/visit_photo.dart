import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../domain/entities/visit_record.dart';
import '../admin_visit_presenter.dart';
import '../controllers/visit_photo_source.dart';

/// A visit photo for the admin, or an honest reason there is none.
///
/// The picture comes only from the admin-only `visit-photos` function, with the
/// admin's own sign-in. A visit with no photo, a photo removed after 90 days, a
/// picture still loading and one that could not be loaded each look different,
/// and a failed picture can be tapped to try again.
class VisitPhoto extends ConsumerStatefulWidget {
  const VisitPhoto({
    super.key,
    required this.visit,
    this.size = VisitPhotoSize.thumb,
    this.fit = BoxFit.cover,
    this.compact = false,
  });

  final VisitRecord visit;
  final VisitPhotoSize size;
  final BoxFit fit;

  /// A small thumbnail: icons only, no words.
  final bool compact;

  @override
  ConsumerState<VisitPhoto> createState() => _VisitPhotoState();
}

class _VisitPhotoState extends ConsumerState<VisitPhoto> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    if (!visit.hasRemotePhoto) {
      final removed = visit.photoRemovedAt != null;
      return _placeholder(
        key: const Key('visit-photo-none'),
        icon: removed
            ? Icons.hide_image_outlined
            : Icons.no_photography_outlined,
        label: AdminVisitPresenter.photoCaption(visit),
      );
    }

    final request = ref.read(visitPhotoRequestProvider)(visit.id, widget.size);
    if (request == null) return _failed();

    return Image.network(
      request.url,
      key: ValueKey<String>('${visit.id}-${widget.size.name}-$_attempt'),
      headers: request.headers,
      fit: widget.fit,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _placeholder(
          key: const Key('visit-photo-loading'),
          child: widget.compact
              ? const SizedBox.shrink()
              : const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _failed(),
    );
  }

  Widget _failed() {
    return InkWell(
      key: const Key('visit-photo-retry'),
      onTap: () => setState(() => _attempt++),
      child: _placeholder(
        icon: Icons.broken_image_outlined,
        label: 'Photo unavailable. Tap to try again.',
      ),
    );
  }

  Widget _placeholder({
    Key? key,
    IconData? icon,
    String? label,
    Widget? child,
  }) {
    return ColoredBox(
      key: key,
      color: AppColors.neutral100,
      child: Center(
        child:
            child ??
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: widget.compact ? AppSizes.icon : 32,
                  color: AppColors.neutral400,
                ),
                if (!widget.compact && label != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.x2),
                  Padding(
                    padding: AppSpacing.screen,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
      ),
    );
  }
}
