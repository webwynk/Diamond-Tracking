import 'package:flutter/foundation.dart';

import '../../../../../domain/entities/live_position.dart';

/// Filter mode for the live map. Only people on duty have a position, so there
/// is no off-duty or blocked filter: those people are not on the map (the Team
/// list shows them).
enum AdminMapFilter { all, onDuty, stale, needsCheck }

/// State of the live feed itself, shown to the admin so a silent outage never
/// looks like "nobody is working".
enum LiveConnection {
  /// Opening the connection.
  connecting,

  /// Receiving changes as they happen.
  live,

  /// The connection is down. The positions shown are the last known ones and
  /// the app is trying to reconnect.
  offline,
}

/// An employee who is on duty, with the position the map draws.
@immutable
class LiveOfficer {
  const LiveOfficer({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.phoneNumber,
    required this.position,
    required this.status,
    required this.lastSeen,
  });

  /// The employee's profile id.
  final String id;
  final String name;
  final String employeeCode;
  final String phoneNumber;
  final LivePosition position;
  final LiveStatus status;

  /// Plain-words age of the last position, for example "3 min ago".
  final String lastSeen;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'EM';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}

/// State of the admin live map.
@immutable
class AdminLiveMapState {
  const AdminLiveMapState({
    this.selectedFilter = AdminMapFilter.all,
    this.searchQuery = '',
    this.selectedId,
    this.officers = const <LiveOfficer>[],
    this.offDutyCount,
    this.connection = LiveConnection.connecting,
    this.isLoading = true,
    this.errorMessage,
  });

  final AdminMapFilter selectedFilter;
  final String searchQuery;

  /// The employee whose card is open, if any.
  final String? selectedId;

  /// Everyone on duty, ordered by name.
  final List<LiveOfficer> officers;

  /// Active employees who are not on duty right now (blocked ones excluded).
  /// Null until the roster has loaded: unknown is never shown as zero.
  final int? offDutyCount;
  final LiveConnection connection;

  /// True until the first load finishes (or fails).
  final bool isLoading;

  /// Why the first load failed. Null once loaded.
  final String? errorMessage;

  int get totalCount => officers.length;
  int get onDutyCount => _count(LiveStatus.active);
  int get staleCount => _count(LiveStatus.stale);
  int get needsCheckCount => _count(LiveStatus.suspect);

  int _count(LiveStatus status) =>
      officers.where((o) => o.status == status).length;

  /// The open card's employee, or null when none is open or that employee has
  /// since gone off duty.
  LiveOfficer? get selectedOfficer {
    final id = selectedId;
    if (id == null) return null;
    for (final officer in officers) {
      if (officer.id == id) return officer;
    }
    return null;
  }

  List<LiveOfficer> get filteredOfficers {
    final query = searchQuery.trim().toLowerCase();
    return officers.where((officer) {
      final statusOk = switch (selectedFilter) {
        AdminMapFilter.all => true,
        AdminMapFilter.onDuty => officer.status == LiveStatus.active,
        AdminMapFilter.stale => officer.status == LiveStatus.stale,
        AdminMapFilter.needsCheck => officer.status == LiveStatus.suspect,
      };
      if (!statusOk) return false;
      if (query.isEmpty) return true;
      return officer.name.toLowerCase().contains(query) ||
          officer.employeeCode.toLowerCase().contains(query);
    }).toList();
  }

  AdminLiveMapState copyWith({
    AdminMapFilter? selectedFilter,
    String? searchQuery,
    String? selectedId,
    bool clearSelected = false,
    List<LiveOfficer>? officers,
    int? offDutyCount,
    LiveConnection? connection,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AdminLiveMapState(
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
      officers: officers ?? this.officers,
      offDutyCount: offDutyCount ?? this.offDutyCount,
      connection: connection ?? this.connection,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
