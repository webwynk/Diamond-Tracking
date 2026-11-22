import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/links/open_link.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../routes/domain/geo_point.dart';
import '../domain/visit.dart';
import 'visit_widgets.dart';

/// Opens [visit] in Visit detail.
void openVisit(BuildContext context, Visit visit) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => VisitDetailPage(visit: visit)));

/// "Visit detail" (design v2), the same for Rahul and the admin: the photo
/// (pinch to zoom, full screen), the store, date and time, the note, and
/// where it was taken with a button to open Google Maps there.
class VisitDetailPage extends ConsumerWidget {
  const VisitDetailPage({required this.visit, super.key});

  final Visit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Visit v = visit;
    final MediaQueryData media = MediaQuery.of(context);
    final double photoHeight = (media.size.height * 0.47)
        .clamp(280, 440)
        .toDouble();
    final AuthStatus auth = ref.watch(authStatusProvider);
    final bool admin = auth is SignedIn && auth.role == AppRole.admin;
    return Scaffold(
      backgroundColor: DsColors.ink,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: photoHeight,
            child: _Photo(visit: v),
          ),
          Positioned(
            left: DsSpace.lg,
            bottom: media.size.height - photoHeight + 44,
            child: _Glass(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    v.fromGallery ? DsIcons.gallery : DsIcons.camera,
                    size: 15,
                    color: DsColors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    v.fromGallery ? 'Gallery photo' : 'Camera photo',
                    style: DsText.micro.copyWith(
                      color: DsColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: photoHeight - 28,
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: DsColors.white,
                borderRadius: DsRadius.sheetTop,
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  18,
                  22,
                  18,
                  DsSpace.xl + media.padding.bottom,
                ),
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(v.storeName, style: DsText.title),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: DsSpace.sm,
                    runSpacing: DsSpace.sm,
                    children: <Widget>[
                      _Fact(
                        icon: DsIcons.history,
                        label: IstFormat.weekdayDay(Ist.dateOf(v.capturedAt)),
                      ),
                      _Fact(
                        icon: DsIcons.clock,
                        label: IstFormat.time(v.capturedAt),
                      ),
                    ],
                  ),
                  if (v.note?.trim() case final String note
                      when note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    _Note(text: note),
                  ],
                  const SizedBox(height: 14),
                  _PlaceCard(visit: v),
                  const SizedBox(height: DsSpace.xl),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          DsIcons.info,
                          size: 14,
                          color: DsColors.text2,
                        ),
                      ),
                      const SizedBox(width: DsSpace.sm),
                      Expanded(
                        child: Text(
                          'Photo kept for 90 days. The visit stays in '
                          '${admin ? 'the' : 'your'} history.',
                          style: DsText.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: media.padding.top + DsSpace.md,
            left: DsSpace.lg,
            right: DsSpace.lg,
            child: Row(
              children: <Widget>[
                _GlassButton(
                  icon: DsIcons.back,
                  label: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (v.showsPhoto)
                  _GlassButton(
                    icon: DsIcons.expand,
                    label: 'View full screen',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _FullPhoto(visit: v),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo, pinch to zoom; a grey box once it is deleted (90 days).
class _Photo extends StatelessWidget {
  const _Photo({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    if (!visit.showsPhoto) {
      return ColoredBox(
        color: const Color(0xFF334155),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(DsIcons.gallery, size: 36, color: DsColors.text3),
              const SizedBox(height: DsSpace.sm),
              Text(
                visit.photoRemoved
                    ? 'Photo deleted after 90 days'
                    : 'No photo with this visit',
                style: DsText.body.copyWith(color: DsColors.white),
              ),
            ],
          ),
        ),
      );
    }
    return Semantics(
      image: true,
      label: 'Photo at ${visit.storeName}, pinch to zoom',
      child: InteractiveViewer(
        maxScale: 5,
        child: SizedBox.expand(
          child: VisitPhoto(visitId: visit.id, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// The photo alone on black, whole, pinch to zoom.
class _FullPhoto extends StatelessWidget {
  const _FullPhoto({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: <Widget>[
        Positioned.fill(
          child: InteractiveViewer(
            maxScale: 6,
            child: Center(
              child: VisitPhoto(visitId: visit.id, fit: BoxFit.contain),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + DsSpace.md,
          left: DsSpace.lg,
          child: _GlassButton(
            icon: DsIcons.close,
            label: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    ),
  );
}

/// Dark see-through pill on the photo.
class _Glass extends StatelessWidget {
  const _Glass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
    decoration: const BoxDecoration(
      color: Color(0x8C0F172A),
      borderRadius: DsRadius.pill,
    ),
    child: child,
  );
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: const Color(0x8C0F172A),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 46,
          child: Icon(icon, size: 22, color: DsColors.white),
        ),
      ),
    ),
  );
}

/// "Sat, 21 Nov" / "8:12 AM" in a grey pill.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
    decoration: const BoxDecoration(
      color: DsColors.surface,
      borderRadius: DsRadius.pill,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: DsColors.slate),
        const SizedBox(width: 6),
        Text(label, style: DsText.label.copyWith(color: DsColors.slate)),
      ],
    ),
  );
}

/// The visit's note in the blue box.
class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Note: $text',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.all(DsSpace.lg),
      decoration: const BoxDecoration(
        color: DsColors.primaryTint,
        borderRadius: DsRadius.large,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(DsIcons.message, size: 18, color: DsColors.primary),
          ),
          const SizedBox(width: DsSpace.md),
          Expanded(
            child: Text(
              text,
              style: DsText.body.copyWith(color: DsColors.deep, height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Where the photo was taken: saved, approximate, fake, or none; with a
/// Maps button when there is a place.
class _PlaceCard extends ConsumerWidget {
  const _PlaceCard({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Visit v = visit;
    final GeoPoint? at = v.location;
    final (Color dot, String title, String line) = switch (at) {
      null => (DsColors.text3, 'No place saved', 'Gallery photo, no location'),
      final GeoPoint p when v.mocked => (
        DsColors.dangerDot,
        'Fake GPS',
        '${formatPoint(p)} · from a fake-location app',
      ),
      final GeoPoint p when v.isApproximate => (
        DsColors.warningDot,
        'Place saved, approximate',
        '${formatPoint(p)} · ±${v.accuracyM} m',
      ),
      final GeoPoint p => (DsColors.successDot, 'Place saved', formatPoint(p)),
    };
    final Color tint = v.mocked ? DsColors.dangerTint : DsColors.surface;
    return Container(
      padding: const EdgeInsets.all(DsSpace.sm),
      decoration: BoxDecoration(color: tint, borderRadius: DsRadius.large),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: DsColors.white,
              borderRadius: DsRadius.medium,
            ),
            child: Icon(
              DsIcons.pin,
              size: 22,
              color: at == null ? DsColors.text3 : DsColors.primary,
            ),
          ),
          const SizedBox(width: DsSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        style: DsText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: v.mocked ? DsColors.dangerText : DsColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(line, style: DsText.caption),
              ],
            ),
          ),
          if (at != null) ...<Widget>[
            const SizedBox(width: DsSpace.sm),
            DsSmallButton(
              label: 'Maps',
              onPressed: () async {
                final bool opened = await ref.read(openLinkProvider)(
                  mapsLink(at.lat, at.lng),
                );
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Couldn't open Google Maps")),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
