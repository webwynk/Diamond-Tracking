import '../../../core/logging/app_log.dart';
import '../data/visit_outbox.dart';
import '../data/visits_repository.dart';
import '../domain/visit_failure.dart';

/// Sends visits kept on the phone (M10): uploads the photo once, then saves
/// the visit. The server puts it into the duty the photo was taken in.
class VisitSender {
  VisitSender(this._outbox, this._repo);

  final VisitOutbox _outbox;
  final VisitsRepository _repo;
  bool _sending = false;

  /// No internet (or Cloudinary not reached): the visit waits for later.
  static bool isOffline(VisitFailure f) =>
      f == VisitFailure.noInternet || f == VisitFailure.photoUploadFailed;

  /// The server will never take it: wrong details, or too late (more than
  /// 2 days after the duty).
  static bool isRefused(VisitFailure f) => switch (f) {
    VisitFailure.notOnDuty ||
    VisitFailure.storeNameRequired ||
    VisitFailure.photoRequired ||
    VisitFailure.noLocation ||
    VisitFailure.noteTooLong => true,
    _ => false,
  };

  /// Sends one visit. Null when the server has it (and the phone's copy is
  /// gone); otherwise why not, with the visit still on the phone.
  Future<VisitFailure?> send(PendingVisit visit) async {
    PendingVisit v = visit;
    try {
      if (v.photoId == null) {
        v = v.withPhotoId(await _repo.uploadPhoto(await _outbox.photo(v)));
        await _outbox.update(v);
      }
      await _repo.add(
        photoId: v.photoId!,
        storeName: v.storeName,
        note: v.note,
        location: v.location,
        mocked: v.location != null && v.mocked,
        accuracyM: v.location == null ? null : v.accuracyM,
        capturedAt: v.capturedAt,
      );
      await _outbox.remove(v);
      return null;
    } on Object catch (e) {
      return mapVisitError(e);
    }
  }

  /// Sends [userId]'s waiting visits, oldest first; stops at the first one
  /// that has to wait. A visit the server refuses for good is dropped.
  /// Returns how many the server now has.
  Future<int> sendAll(String userId) async {
    if (_sending) return 0;
    _sending = true;
    int sent = 0;
    try {
      for (final PendingVisit v in await _outbox.pending(userId: userId)) {
        final VisitFailure? f = await send(v);
        if (f == null) {
          sent++;
        } else if (isRefused(f)) {
          AppLog.info('Visit ${v.id} refused for good: ${f.name}');
          await _outbox.remove(v);
        } else {
          break;
        }
      }
    } on Object catch (e, st) {
      AppLog.failure('VisitSender.sendAll', e, st);
    } finally {
      _sending = false;
    }
    return sent;
  }
}
