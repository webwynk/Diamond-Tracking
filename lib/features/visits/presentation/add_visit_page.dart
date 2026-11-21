import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/time/clock_providers.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/form_message.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_status.dart';
import '../../requests/data/photo_picker.dart';
import '../../requests/presentation/photo_field.dart';
import '../../routes/domain/geo_point.dart';
import '../application/visit_sender.dart';
import '../application/visits_providers.dart';
import '../data/current_location.dart';
import '../data/visit_outbox.dart';
import '../domain/visit.dart';
import '../domain/visit_failure.dart';

/// Add a dealer visit while on duty: store name, note and a photo. A camera
/// photo saves where it was taken; a gallery photo saves no place. With no
/// internet the visit is kept on the phone and sent later.
class AddVisitPage extends ConsumerStatefulWidget {
  const AddVisitPage({required this.dayId, super.key});

  /// Today's duty, whose visit list reloads after saving.
  final int dayId;

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

  /// Kept after a successful upload, so a retry here does not upload again
  /// and does not add a second visit.
  String? _photoId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _store.dispose();
    _note.dispose();
    super.dispose();
  }

  void _photoChanged(Uint8List? photo) {
    setState(() {
      _photo = photo;
      _photoId = null;
      if (photo == null) {
        _from = null;
        _location = null;
        _gps = _Gps.none;
      }
    });
  }

  void _picked(PhotoFrom from) {
    _from = from;
    _takenAt = ref.read(serverClockProvider).now();
    _location = null;
    _mocked = false;
    _accuracyM = null;
    if (from == PhotoFrom.camera) {
      _findLocation();
    } else {
      setState(() => _gps = _Gps.none);
    }
  }

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

  String? _check() {
    if (_store.text.trim().isEmpty) {
      return VisitFailure.storeNameRequired.message;
    }
    if (_photo == null) return VisitFailure.photoRequired.message;
    if (_from == PhotoFrom.camera && _gps == _Gps.finding) {
      return 'Finding your location. Wait a moment.';
    }
    if (_from == PhotoFrom.camera && _location == null) {
      return VisitFailure.noLocation.message;
    }
    return null;
  }

  Future<void> _save() async {
    final String? problem = _check();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
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

  Widget _gpsLine() {
    final (IconData icon, Color color, String text) = switch (_gps) {
      _Gps.none => (
        Icons.location_off_rounded,
        AppColors.textSecondary,
        'Gallery photo: no location is saved.',
      ),
      _Gps.finding => (
        Icons.my_location_rounded,
        AppColors.textSecondary,
        'Finding your location…',
      ),
      _Gps.found => (
        Icons.location_on_rounded,
        AppColors.success,
        'Location found: ${formatPoint(_location!)}'
            '${(_accuracyM ?? 0) > approximateOverM ? ' (approximate, ±$_accuracyM m)' : ''}',
      ),
      _Gps.failed => (
        Icons.location_disabled_rounded,
        AppColors.error,
        'Location not found.',
      ),
    };
    return Row(
      children: <Widget>[
        Icon(icon, color: color, size: 20),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(text, style: AppTypography.body.copyWith(color: color)),
        ),
        if (_gps == _Gps.failed)
          TextButton(
            onPressed: _busy ? null : _findLocation,
            child: const Text('Try again'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kept alive: the visit is saved under the signed-in person.
    ref.watch(authStatusProvider);
    return _page(context);
  }

  Widget _page(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add visit')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.x4),
        children: <Widget>[
          TextField(
            controller: _store,
            enabled: !_busy,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Store name'),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextField(
            controller: _note,
            enabled: !_busy,
            maxLength: 300,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'Order taken, stock, what the dealer said',
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          PhotoField(
            label: 'Dealer photo (required)',
            photo: _photo,
            enabled: !_busy,
            onPicked: _picked,
            onChanged: _photoChanged,
          ),
          if (_photo != null) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            _gpsLine(),
          ],
          if (_error case final String e) ...<Widget>[
            const SizedBox(height: AppSpacing.x4),
            FormMessage.error(e),
          ],
          const SizedBox(height: AppSpacing.x4),
          AppButton(
            label: 'Save visit',
            isFullWidth: true,
            isLoading: _busy,
            loadingLabel: 'Saving…',
            onPressed: _save,
          ),
        ],
      ),
    ),
  );
}
