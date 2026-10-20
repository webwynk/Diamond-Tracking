import '../../../../core/utils/duty_time_helper.dart';
import '../../../../domain/entities/visit_record.dart';

/// Words for a visit, shown the same way in the profile card, the list and the
/// details page. Times are IST (PRD BR-1).
abstract final class AdminVisitPresenter {
  const AdminVisitPresenter._();

  /// The store or shop name, or a plain label when none was given.
  static String title(VisitRecord visit) {
    final name = visit.storeName?.trim();
    return name == null || name.isEmpty ? 'Visit' : name;
  }

  /// "12 Oct 2026 · 8:04 AM".
  static String when(VisitRecord visit) {
    return '${DutyTimeHelper.formatDate(visit.capturedAt)} · '
        '${DutyTimeHelper.formatTime(visit.capturedAt)}';
  }

  /// What the photo situation is, in words; null when there is a photo.
  static String? photoCaption(VisitRecord visit) {
    if (visit.hasRemotePhoto) return null;
    if (visit.photoRemovedAt != null) return 'Photo removed after 90 days';
    return 'No photo';
  }

  /// "19.99750, 73.78980".
  static String coordinates(VisitRecord visit) {
    return '${visit.latitude.toStringAsFixed(5)}, '
        '${visit.longitude.toStringAsFixed(5)}';
  }

  /// "± 4 m" for the GPS accuracy, or null when it was not recorded.
  static String? accuracy(VisitRecord visit) {
    final metres = visit.accuracy;
    return metres == null ? null : '± ${metres.round()} m';
  }
}
