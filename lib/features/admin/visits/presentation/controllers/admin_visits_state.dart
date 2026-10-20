import 'package:flutter/foundation.dart';

import '../../../../../domain/entities/visit_record.dart';

/// How the first page of visits is doing.
enum AdminVisitsLoad { loading, loaded, failed }

/// What the admin's Visits list shows.
@immutable
class AdminVisitsState {
  const AdminVisitsState({
    this.visits = const <VisitRecord>[],
    this.load = AdminVisitsLoad.loading,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  /// Newest first.
  final List<VisitRecord> visits;
  final AdminVisitsLoad load;

  /// Older visits exist beyond the ones loaded.
  final bool hasMore;
  final bool isLoadingMore;

  /// The last request for an older page failed; Retry is offered.
  final bool loadMoreFailed;

  AdminVisitsState copyWith({
    List<VisitRecord>? visits,
    AdminVisitsLoad? load,
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return AdminVisitsState(
      visits: visits ?? this.visits,
      load: load ?? this.load,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}
