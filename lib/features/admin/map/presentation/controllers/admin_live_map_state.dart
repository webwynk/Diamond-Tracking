import 'package:flutter/foundation.dart';

/// Status classification of an officer on the administrative map.
enum AdminOfficerStatus {
  onDuty,
  stale,
  needsCheck,
  offDuty,
  blocked,
}

/// Filter mode for the live telemetry map.
enum AdminMapFilter {
  all,
  onDuty,
  stale,
  needsCheck,
  offDuty,
  blocked,
}

/// Domain entity representing a field officer rendered on the telemetry canvas.
@immutable
class MapOfficerItem {
  const MapOfficerItem({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.relativeX,
    required this.relativeY,
    required this.status,
    required this.locationName,
    required this.lastUpdated,
    this.batteryPercent = 88,
    this.isSos = false,
    this.sosTag,
    this.phoneNumber = '+91 98201 44556',
    this.dutyDuration = '7h 24m',
    this.dutyStartTime = '8:04 AM',
    this.distanceTodayKm = '38.6 km',
    this.visitsToday = 3,
    this.accuracyMeters = 6,
    this.speedKmh = 42,
    this.proximityText = 'Near Shivpuri Farm · 180 m away',
    this.geofenceText = 'GEOFENCE ACTIVE · 4.8 KM²',
    this.sectorText = 'SECTOR 04',
  });

  final String id;
  final String name;
  final String employeeCode;
  final double relativeX;
  final double relativeY;
  final AdminOfficerStatus status;
  final String locationName;
  final String lastUpdated;
  final int batteryPercent;
  final bool isSos;
  final String? sosTag;
  final String phoneNumber;
  final String dutyDuration;
  final String dutyStartTime;
  final String distanceTodayKm;
  final int visitsToday;
  final int accuracyMeters;
  final int speedKmh;
  final String proximityText;
  final String geofenceText;
  final String sectorText;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'EM';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String get calloutTag {
    if (sosTag != null) return sosTag!;
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0].toUpperCase()} ${parts[1][0].toUpperCase()}.';
    }
    return name.toUpperCase();
  }

  MapOfficerItem copyWith({
    String? id,
    String? name,
    String? employeeCode,
    double? relativeX,
    double? relativeY,
    AdminOfficerStatus? status,
    String? locationName,
    String? lastUpdated,
    int? batteryPercent,
    bool? isSos,
    String? sosTag,
    String? phoneNumber,
    String? dutyDuration,
    String? dutyStartTime,
    String? distanceTodayKm,
    int? visitsToday,
    int? accuracyMeters,
    int? speedKmh,
    String? proximityText,
    String? geofenceText,
    String? sectorText,
  }) {
    return MapOfficerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeCode: employeeCode ?? this.employeeCode,
      relativeX: relativeX ?? this.relativeX,
      relativeY: relativeY ?? this.relativeY,
      status: status ?? this.status,
      locationName: locationName ?? this.locationName,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      isSos: isSos ?? this.isSos,
      sosTag: sosTag ?? this.sosTag,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dutyDuration: dutyDuration ?? this.dutyDuration,
      dutyStartTime: dutyStartTime ?? this.dutyStartTime,
      distanceTodayKm: distanceTodayKm ?? this.distanceTodayKm,
      visitsToday: visitsToday ?? this.visitsToday,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      speedKmh: speedKmh ?? this.speedKmh,
      proximityText: proximityText ?? this.proximityText,
      geofenceText: geofenceText ?? this.geofenceText,
      sectorText: sectorText ?? this.sectorText,
    );
  }
}

/// Domain entity representing an aggregated regional cluster bubble.
@immutable
class MapClusterItem {
  const MapClusterItem({
    required this.id,
    required this.title,
    required this.count,
    required this.relativeX,
    required this.relativeY,
    required this.dominantStatus,
  });

  final String id;
  final String title;
  final int count;
  final double relativeX;
  final double relativeY;
  final AdminOfficerStatus dominantStatus;
}

/// State representation for Screen 15 Admin Live Map.
@immutable
class AdminLiveMapState {
  const AdminLiveMapState({
    this.selectedFilter = AdminMapFilter.all,
    this.searchQuery = '',
    this.activeFilterBadgeCount = 2,
    this.selectedOfficer,
    this.selectedCluster,
    this.officers = const [],
    this.clusters = const [],
    this.isSatelliteLayer = false,
    this.isLoading = false,
  });

  final AdminMapFilter selectedFilter;
  final String searchQuery;
  final int activeFilterBadgeCount;
  final MapOfficerItem? selectedOfficer;
  final MapClusterItem? selectedCluster;
  final List<MapOfficerItem> officers;
  final List<MapClusterItem> clusters;
  final bool isSatelliteLayer;
  final bool isLoading;

  int get totalOfficersCount => 143;
  int get onDutyCount => 112;
  int get staleCount => 4;
  int get needsCheckCount => 3;
  int get offDutyCount => 31;
  int get blockedCount => 2;

  List<MapOfficerItem> get filteredOfficers {
    return officers.where((officer) {
      // 1. Status Filter
      if (selectedFilter == AdminMapFilter.onDuty &&
          officer.status != AdminOfficerStatus.onDuty) {
        return false;
      }
      if (selectedFilter == AdminMapFilter.stale &&
          officer.status != AdminOfficerStatus.stale) {
        return false;
      }
      if (selectedFilter == AdminMapFilter.needsCheck &&
          officer.status != AdminOfficerStatus.needsCheck) {
        return false;
      }
      if (selectedFilter == AdminMapFilter.offDuty &&
          officer.status != AdminOfficerStatus.offDuty) {
        return false;
      }
      if (selectedFilter == AdminMapFilter.blocked &&
          officer.status != AdminOfficerStatus.blocked) {
        return false;
      }

      // 2. Search Query Filter
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchesName = officer.name.toLowerCase().contains(query);
        final matchesCode = officer.employeeCode.toLowerCase().contains(query);
        final matchesLoc = officer.locationName.toLowerCase().contains(query);
        return matchesName || matchesCode || matchesLoc;
      }

      return true;
    }).toList();
  }

  List<MapClusterItem> get filteredClusters {
    if (searchQuery.trim().isNotEmpty) {
      // Hide clusters when searching for a specific individual
      return const [];
    }
    return clusters.where((cluster) {
      if (selectedFilter == AdminMapFilter.all) return true;
      if (selectedFilter == AdminMapFilter.onDuty &&
          cluster.dominantStatus == AdminOfficerStatus.onDuty) {
        return true;
      }
      if (selectedFilter == AdminMapFilter.stale &&
          cluster.dominantStatus == AdminOfficerStatus.stale) {
        return true;
      }
      if (selectedFilter == AdminMapFilter.blocked &&
          cluster.dominantStatus == AdminOfficerStatus.blocked) {
        return true;
      }
      return false;
    }).toList();
  }

  AdminLiveMapState copyWith({
    AdminMapFilter? selectedFilter,
    String? searchQuery,
    int? activeFilterBadgeCount,
    MapOfficerItem? selectedOfficer,
    bool clearSelectedOfficer = false,
    MapClusterItem? selectedCluster,
    bool clearSelectedCluster = false,
    List<MapOfficerItem>? officers,
    List<MapClusterItem>? clusters,
    bool? isSatelliteLayer,
    bool? isLoading,
  }) {
    return AdminLiveMapState(
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilterBadgeCount:
          activeFilterBadgeCount ?? this.activeFilterBadgeCount,
      selectedOfficer: clearSelectedOfficer
          ? null
          : (selectedOfficer ?? this.selectedOfficer),
      selectedCluster: clearSelectedCluster
          ? null
          : (selectedCluster ?? this.selectedCluster),
      officers: officers ?? this.officers,
      clusters: clusters ?? this.clusters,
      isSatelliteLayer: isSatelliteLayer ?? this.isSatelliteLayer,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
