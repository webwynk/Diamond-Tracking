import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/design/ds_colors.dart';
import '../../../core/design/ds_icons.dart';
import '../../../core/design/ds_layout.dart';
import '../../../core/design/ds_text.dart';
import '../../../core/links/open_link.dart';
import '../../../core/logging/app_log.dart';
import '../../../core/time/clock_providers.dart';
import '../../../core/time/ist.dart';
import '../../../core/time/ist_format.dart';
import '../../../shared/ds/ds_button.dart';
import '../../../shared/ds/ds_feedback.dart';
import '../../../shared/ds/ds_field.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../requests/application/requests_providers.dart';
import '../../requests/data/photo_picker.dart';
import '../../routes/domain/geo_point.dart';
import '../application/visit_sender.dart';
import '../application/visits_providers.dart';
import '../data/current_location.dart';
import '../data/visit_outbox.dart';
import '../domain/visit.dart';
import '../domain/visit_failure.dart';

/// Quick words for the note (design v2).
const List<String> visitNoteChips = <String>[
  'Order taken',
  'Stock checked',
  'Payment collected',
  'Visit again',
];

/// "New visit" (design v2), while on duty: the dealer photo first (the
/// camera opens by itself), then the store name and an optional note. A
/// camera photo saves where it was taken; a gallery photo saves no place.
/// With no internet the visit is kept on the phone and sent later. When
/// the camera is blocked, the photo area says so and opens the settings.
class AddVisitPage extends ConsumerStatefulWidget {
  const AddVisitPage({required this.dayId, super.key});

  /// Today's duty, whose visit list reloads after saving.
  final int dayId;

  static const int storeMax = 80;
  static const int noteMax = 300;

  @override
  ConsumerState<AddVisitPage> createState() => _AddVisitPageState();
}

enum _Gps { none, finding, found, failed }

class _AddVisitPageState extends ConsumerState<AddVisitPage> {
  final TextEditingController _store = TextEditingController();
  final TextEditingController _note = TextEditingController();
  Uint8List? _photo;
  PhotoFrom? _from;
  DateTime? _takenAt;
  GeoPoint? _location;
  bool _mocked = false;
  int? _accuracyM;
  _Gps _gps = _Gps.none;
  int _gpsTry = 0;
  bool _cameraBlocked = false;

  /// Kept after a successful upload, so a retry here does not upload again
  /// and does not add a second visit.
  String? _photoId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The photo always comes first: open the camera straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _take(PhotoFrom.camera);
    });
  }

  @override
  void dispose() {
    _store.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _take(PhotoFrom from) async {
    final Uint8List? bytes;
    try {
      bytes = await ref.read(photoPickerProvider).pick(from);
    } on CameraBlocked {
      if (mounted) setState(() => _cameraBlocked = true);
      return;
    } on Object catch (e, s) {
      AppLog.failure('pickVisitPhoto', e, s);
      if (mounted) setState(() => _error = "Couldn't open the camera.");
      return;
    }
    if (!mounted || bytes == null) return;
    setState(() {
      if (from == PhotoFrom.camera) _cameraBlocked = false;
      _photo = bytes;
      _photoId = null;
      _from = from;
      _takenAt = ref.read(serverClockProvider).now();
      _location = null;
      _mocked = false;
      _accuracyM = null;
      _gps = _Gps.none;
      _error = null;
    });
    if (from == PhotoFrom.camera) _findLocation();
  }

  void _remove() => setState(() {
    _photo = null;
    _photoId = null;
    _from = null;
    _location = null;
    _gps = _Gps.none;
    _gpsTry++;
  });

  Future<void> _findLocation() async {
    final int attempt = ++_gpsTry;
    setState(() => _gps = _Gps.finding);
    final LocationFix? fix = await ref.read(currentLocationProvider).find();
    if (!mounted || attempt != _gpsTry || _from != PhotoFrom.camera) return;
    setState(() {
      _location = fix?.point;
      _mocked = fix?.mocked ?? false;
      _accuracyM = fix?.accuracyM;
      _gps = fix == null ? _Gps.failed : _Gps.found;
    });
  }

  void _addNoteWords(String words) {
    final String now = _note.text.trim();
    final String next = now.isEmpty ? words : '$now. $words';
    if (next.length > AddVisitPage.noteMax) return;
    setState(() {
      _note.text = next;
      _note.selection = TextSelection.collapsed(offset: next.length);
    });
  }

  /// What still stops the save, said on the button; null when ready.
  String? _missing() {
    if (_store.text.trim().isEmpty) return 'Write the store name';
    if (_photo == null) return 'Add a photo to save';
    if (_from == PhotoFrom.camera && _gps == _Gps.finding) {
      return 'Finding your place…';
    }
    if (_from == PhotoFrom.camera && _location == null) {
      return 'Find the place to save';
    }
    return null;
  }

  Future<void> _save() async {
    if (_missing() != null) return;
    final AuthStatus status = ref.read(authStatusProvider);
    if (status is! SignedIn) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Kept on the phone first, so a visit is never lost (M10): with no
      // internet it stays there and is sent later.
      final VisitOutbox outbox = ref.read(visitOutboxProvider);
      final PendingVisit visit = PendingVisit(
        id: VisitOutbox.newId(),
        userId: status.userId,
        storeName: _store.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        location: _from == PhotoFrom.camera ? _location : null,
        mocked: _from == PhotoFrom.camera && _mocked,
        accuracyM: _from == PhotoFrom.camera ? _accuracyM : null,
        capturedAt: _takenAt ?? ref.read(serverClockProvider).now(),
        photoId: _photoId,
      );
      await outbox.add(visit, _photo!);
      final VisitFailure? failure = await ref
          .read(visitSenderProvider)
          .send(visit);
      if (!mounted) return;
      if (failure == null || VisitSender.isOffline(failure)) {
        ref
          ..invalidate(dayVisitsProvider(widget.dayId))
          ..invalidate(pendingVisitsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure == null
                  ? 'Visit saved.'
                  : 'No internet. The visit is kept on the phone and will be '
                        'sent when you are online.',
            ),
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      // Something to fix here (or a problem the person must see): show it
      // and keep the page; the uploaded photo is reused on the next try.
      final List<PendingVisit> left = await outbox.pending();
      final PendingVisit? kept = left
          .where((PendingVisit v) => v.id == visit.id)
          .firstOrNull;
      _photoId = kept?.photoId ?? _photoId;
      if (kept != null) await outbox.remove(kept);
      if (mounted) setState(() => _error = failure.message);
    } on Object catch (e) {
      if (mounted) setState(() => _error = mapVisitError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _subtitle() {
    final DateTime at = _takenAt ?? ref.read(serverClockProvider).now();
    final String day = DateFormat('EEEE, d MMM').format(Ist.dateOf(at));
    return switch ((_from, _gps)) {
      (PhotoFrom.gallery, _) => '$day · photo from gallery',
      (PhotoFrom.camera, _Gps.found) => '$day · ${formatPoint(_location!)}',
      (PhotoFrom.camera, _Gps.finding) => '$day · finding your place…',
      (PhotoFrom.camera, _Gps.failed) => '$day · place not found',
      _ => day,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Kept alive: the visit is saved under the signed-in person.
    ref.watch(authStatusProvider);
    final MediaQueryData media = MediaQuery.of(context);
    final double photoHeight = (media.size.height * 0.42)
        .clamp(260, 380)
        .toDouble();
    final String? missing = _missing();
    return Scaffold(
      backgroundColor: DsColors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: photoHeight,
              child: _PhotoArea(
                photo: _photo,
                from: _from,
                takenAt: _takenAt,
                gps: _gps,
                mocked: _mocked,
                approximate: (_accuracyM ?? 0) > approximateOverM,
                accuracyM: _accuracyM,
                blocked: _cameraBlocked,
                busy: _busy,
                onCamera: () => _take(PhotoFrom.camera),
                onGallery: () => _take(PhotoFrom.gallery),
                onRemove: _remove,
                onSettings: () => ref.read(openAppSettingsProvider)(),
                onClose: () => Navigator.of(context).maybePop(),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: const BoxDecoration(
                  color: DsColors.white,
                  borderRadius: DsRadius.sheetTop,
                ),
                padding: EdgeInsets.fromLTRB(
                  DsSpace.gutter,
                  DsSpace.xl,
                  DsSpace.gutter,
                  media.padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: const Text('New visit', style: DsText.title),
                    ),
                    const SizedBox(height: 2),
                    Text(_subtitle(), style: DsText.caption),
                    if (_from == PhotoFrom.gallery) ...<Widget>[
                      const SizedBox(height: DsSpace.lg),
                      DsBanner(
                        kind: DsBannerKind.warning,
                        title: 'No place saved.',
                        message: "Gallery photos don't show on the map.",
                        actionLabel: _cameraBlocked ? null : 'Take photo',
                        onAction: _busy || _cameraBlocked
                            ? null
                            : () => _take(PhotoFrom.camera),
                      ),
                    ],
                    if (_from == PhotoFrom.camera &&
                        _gps == _Gps.failed) ...<Widget>[
                      const SizedBox(height: DsSpace.lg),
                      DsBanner(
                        kind: DsBannerKind.danger,
                        title: 'Place not found',
                        message:
                            'Turn on location or step outside, then try '
                            'again.',
                        actionLabel: 'Try again',
                        onAction: _busy ? null : _findLocation,
                      ),
                    ],
                    const SizedBox(height: DsSpace.lg),
                    DsTextField(
                      label: 'Store name',
                      controller: _store,
                      locked: _busy,
                      icon: DsIcons.store,
                      hint: 'Shop or dealer name',
                      maxLength: AddVisitPage.storeMax,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: DsSpace.lg),
                    DsTextField(
                      label: 'Note',
                      optional: true,
                      controller: _note,
                      locked: _busy,
                      hint: 'Order, stock, what the dealer said',
                      maxLines: 4,
                      maxLength: AddVisitPage.noteMax,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: DsSpace.md),
                    Wrap(
                      spacing: DsSpace.sm,
                      runSpacing: DsSpace.sm,
                      children: <Widget>[
                        for (final String c in visitNoteChips)
                          _NoteChip(
                            label: c,
                            onTap: _busy ? null : () => _addNoteWords(c),
                          ),
                      ],
                    ),
                    if (_error case final String e) ...<Widget>[
                      const SizedBox(height: DsSpace.lg),
                      DsBanner(kind: DsBannerKind.danger, title: e),
                    ],
                    const SizedBox(height: DsSpace.xl),
                    DsButton(
                      label: missing ?? 'Save visit',
                      arrow: missing == null,
                      busy: _busy,
                      busyLabel: 'Saving…',
                      onPressed: missing == null ? _save : null,
                    ),
                    const SizedBox(height: DsSpace.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The top: the photo with its tag, place pill, Retake and Remove; or the
/// buttons to take one; or "Camera is blocked".
class _PhotoArea extends StatelessWidget {
  const _PhotoArea({
    required this.photo,
    required this.from,
    required this.takenAt,
    required this.gps,
    required this.mocked,
    required this.approximate,
    required this.accuracyM,
    required this.blocked,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    required this.onSettings,
    required this.onClose,
  });

  final Uint8List? photo;
  final PhotoFrom? from;
  final DateTime? takenAt;
  final _Gps gps;
  final bool mocked;
  final bool approximate;
  final int? accuracyM;
  final bool blocked;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;
  final VoidCallback onSettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final Uint8List? p = photo;
    final double top = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (p != null)
          Image.memory(
            p,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFF334155),
              child: Icon(DsIcons.gallery, size: 36, color: DsColors.text3),
            ),
          )
        else
          ColoredBox(
            color: blocked ? DsColors.slate : DsColors.surface,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                DsSpace.xl,
                top + 60,
                DsSpace.xl,
                DsSpace.md + 24,
              ),
              // Shrinks to fit on a short phone instead of overflowing.
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: c.maxWidth,
                    child: blocked
                        ? _Blocked(onSettings: onSettings, onGallery: onGallery)
                        : _Empty(
                            busy: busy,
                            onCamera: onCamera,
                            onGallery: onGallery,
                          ),
                  ),
                ),
              ),
            ),
          ),
        if (p != null) ...<Widget>[
          Positioned(
            left: DsSpace.lg,
            right: DsSpace.lg,
            bottom: 24 + DsSpace.lg,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _placePill(),
                  ),
                ),
                const SizedBox(width: DsSpace.sm),
                _GlassButton(
                  icon: from == PhotoFrom.gallery
                      ? DsIcons.gallery
                      : DsIcons.camera,
                  label: 'Retake photo',
                  onPressed: busy
                      ? null
                      : (from == PhotoFrom.gallery ? onGallery : onCamera),
                ),
                const SizedBox(width: DsSpace.sm),
                _GlassButton(
                  icon: DsIcons.close,
                  label: 'Remove photo',
                  onPressed: busy ? null : onRemove,
                ),
              ],
            ),
          ),
        ],
        Positioned(
          top: top + DsSpace.md,
          left: DsSpace.lg,
          right: DsSpace.lg,
          child: Row(
            children: <Widget>[
              _GlassButton(
                icon: DsIcons.close,
                label: 'Close',
                onPressed: onClose,
                light: p == null && !blocked,
              ),
              const Spacer(),
              if (p != null && takenAt != null)
                _Pill(
                  text:
                      '${from == PhotoFrom.gallery ? 'Gallery' : 'Camera'} · '
                      '${IstFormat.time(takenAt!)}',
                  bg: const Color(0x8C0F172A),
                  fg: DsColors.white,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placePill() {
    if (from == PhotoFrom.gallery) {
      return const _Pill(
        text: 'No place',
        bg: DsColors.warningTint,
        fg: DsColors.warningText,
        icon: DsIcons.pin,
      );
    }
    return switch (gps) {
      _Gps.finding => const _Pill(
        text: 'Finding place…',
        bg: DsColors.white,
        fg: DsColors.text2,
        icon: DsIcons.locate,
      ),
      _Gps.failed => const _Pill(
        text: 'Place not found',
        bg: DsColors.dangerTint,
        fg: DsColors.dangerText,
        icon: DsIcons.pin,
      ),
      _Gps.found when mocked => const _Pill(
        text: 'Fake GPS',
        bg: DsColors.dangerTint,
        fg: DsColors.dangerText,
        icon: DsIcons.warning,
      ),
      _Gps.found when approximate => _Pill(
        text: 'Approximate ±$accuracyM m',
        bg: DsColors.warningTint,
        fg: DsColors.warningText,
        icon: DsIcons.pin,
      ),
      _Gps.found => const _Pill(
        text: 'Location saved',
        bg: DsColors.successTint,
        fg: DsColors.successText,
        icon: DsIcons.pin,
      ),
      _Gps.none => const SizedBox.shrink(),
    };
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.busy,
    required this.onCamera,
    required this.onGallery,
  });

  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: DsColors.primaryTint,
          shape: BoxShape.circle,
        ),
        child: const Icon(DsIcons.camera, size: 28, color: DsColors.primary),
      ),
      const SizedBox(height: DsSpace.md),
      const Text(
        'Take the dealer photo',
        textAlign: TextAlign.center,
        style: DsText.section,
      ),
      const SizedBox(height: 2),
      const Text(
        'A camera photo saves the place on the map.',
        textAlign: TextAlign.center,
        style: DsText.caption,
      ),
      const SizedBox(height: DsSpace.md),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: DsSpace.sm,
        children: <Widget>[
          IntrinsicWidth(
            child: DsSmallButton(
              label: 'Take photo',
              filled: true,
              onPressed: busy ? null : onCamera,
            ),
          ),
          IntrinsicWidth(
            child: DsSmallButton(
              label: 'Gallery',
              onPressed: busy ? null : onGallery,
            ),
          ),
        ],
      ),
    ],
  );
}

class _Blocked extends StatelessWidget {
  const _Blocked({required this.onSettings, required this.onGallery});

  final VoidCallback onSettings;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0x33F59E0B),
          shape: BoxShape.circle,
        ),
        child: const Icon(DsIcons.camera, size: 28, color: DsColors.warningDot),
      ),
      const SizedBox(height: DsSpace.md),
      Text(
        'Camera is blocked',
        textAlign: TextAlign.center,
        style: DsText.section.copyWith(color: DsColors.white),
      ),
      const SizedBox(height: 2),
      Text(
        'Allow camera access to take the dealer photo with its place.',
        textAlign: TextAlign.center,
        style: DsText.caption.copyWith(color: DsColors.skyText),
      ),
      const SizedBox(height: DsSpace.md),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: DsSpace.sm,
        children: <Widget>[
          IntrinsicWidth(
            child: DsSmallButton(
              label: 'Open settings',
              filled: true,
              onPressed: onSettings,
            ),
          ),
          IntrinsicWidth(
            child: DsSmallButton(label: 'Use gallery', onPressed: onGallery),
          ),
        ],
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
    decoration: BoxDecoration(color: bg, borderRadius: DsRadius.pill),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsText.micro.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.light = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// White with a dark icon, over the light empty area.
  final bool light;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: light ? DsColors.white : const Color(0x8C0F172A),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 46,
          child: Icon(
            icon,
            size: 20,
            color: light ? DsColors.ink : DsColors.white,
          ),
        ),
      ),
    ),
  );
}

/// "+ Order taken": adds the words to the note.
class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Add "$label" to the note',
    excludeSemantics: true,
    child: Material(
      color: DsColors.surface,
      borderRadius: DsRadius.pill,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpace.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '+ $label',
                  style: DsText.label.copyWith(color: DsColors.slate),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
