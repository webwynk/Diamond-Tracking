import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_live_map_state.dart';

/// Provider exposing the administrative live telemetry map controller.
final adminLiveMapControllerProvider =
    NotifierProvider<AdminLiveMapNotifier, AdminLiveMapState>(
  AdminLiveMapNotifier.new,
);

/// Riverpod 3 Notifier managing geospatial state, filtering, and officer selection.
class AdminLiveMapNotifier extends Notifier<AdminLiveMapState> {
  @override
  AdminLiveMapState build() {
    return AdminLiveMapState(
      selectedFilter: AdminMapFilter.all,
      searchQuery: '',
      activeFilterBadgeCount: 2,
      officers: _buildDefaultOfficers(),
      clusters: _buildDefaultClusters(),
    );
  }

  void setFilter(AdminMapFilter filter) {
    state = state.copyWith(selectedFilter: filter);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectOfficer(MapOfficerItem? officer) {
    if (officer == null) {
      state = state.copyWith(clearSelectedOfficer: true);
    } else {
      state = state.copyWith(
        selectedOfficer: officer,
        clearSelectedCluster: true,
      );
    }
  }

  void selectCluster(MapClusterItem? cluster) {
    if (cluster == null) {
      state = state.copyWith(clearSelectedCluster: true);
    } else {
      state = state.copyWith(
        selectedCluster: cluster,
        clearSelectedOfficer: true,
      );
    }
  }

  void toggleLayer() {
    state = state.copyWith(isSatelliteLayer: !state.isSatelliteLayer);
  }

  Future<void> recenterMap() async {
    state = state.copyWith(isLoading: true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    state = state.copyWith(
      isLoading: false,
      clearSelectedOfficer: true,
      clearSelectedCluster: true,
    );
  }

  List<MapClusterItem> _buildDefaultClusters() {
    return const [
      MapClusterItem(
        id: 'cluster-niphad',
        title: 'Niphad Onion & Grape Zone',
        count: 34,
        relativeX: 0.54,
        relativeY: 0.24,
        dominantStatus: AdminOfficerStatus.onDuty,
      ),
      MapClusterItem(
        id: 'cluster-sinnar',
        title: 'Sinnar Agronomy Hub',
        count: 21,
        relativeX: 0.68,
        relativeY: 0.66,
        dominantStatus: AdminOfficerStatus.onDuty,
      ),
      MapClusterItem(
        id: 'cluster-trimbak',
        title: 'Trimbak Remote Cluster',
        count: 12,
        relativeX: 0.16,
        relativeY: 0.72,
        dominantStatus: AdminOfficerStatus.stale,
      ),
      MapClusterItem(
        id: 'cluster-nashik-depot',
        title: 'Nashik Central Depot',
        count: 6,
        relativeX: 0.28,
        relativeY: 0.34,
        dominantStatus: AdminOfficerStatus.blocked,
      ),
    ];
  }

  List<MapOfficerItem> _buildDefaultOfficers() {
    return const [
      // 1 Critical SOS Officer
      MapOfficerItem(
        id: 'officer-sos-1',
        name: 'R. Shinde',
        employeeCode: 'DA-003',
        relativeX: 0.44,
        relativeY: 0.41,
        status: AdminOfficerStatus.needsCheck,
        locationName: 'Dindori Road Border',
        lastUpdated: '1m ago',
        batteryPercent: 14,
        isSos: true,
        sosTag: 'SOS • R. SHINDE',
      ),

      // 10 On-Duty Officers
      MapOfficerItem(
        id: 'officer-on-1',
        name: 'Suresh Patel',
        employeeCode: 'DA-022',
        relativeX: 0.36,
        relativeY: 0.19,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Shivpuri Agricultural Cluster',
        lastUpdated: 'Updated 8 sec ago',
        batteryPercent: 82,
        phoneNumber: '+91 98201 44556',
        dutyDuration: '7h 24m',
        dutyStartTime: '8:04 AM',
        distanceTodayKm: '38.6 km',
        visitsToday: 3,
        accuracyMeters: 6,
        speedKmh: 42,
        proximityText: 'Near Shivpuri Farm · 180 m away',
        geofenceText: 'GEOFENCE ACTIVE · 4.8 KM²',
        sectorText: 'SECTOR 04',
      ),
      MapOfficerItem(
        id: 'officer-on-2',
        name: 'Vikram Gaikwad',
        employeeCode: 'DA-045',
        relativeX: 0.78,
        relativeY: 0.17,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Niphad Agro Farm 12',
        lastUpdated: '3m ago',
        batteryPercent: 84,
      ),
      MapOfficerItem(
        id: 'officer-on-3',
        name: 'Sunil Jadhav',
        employeeCode: 'DA-052',
        relativeX: 0.84,
        relativeY: 0.31,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Godavari Basin Nursery',
        lastUpdated: '5m ago',
        batteryPercent: 77,
      ),
      MapOfficerItem(
        id: 'officer-on-4',
        name: 'Vijay Singh',
        employeeCode: 'DA-031',
        relativeX: 0.15,
        relativeY: 0.24,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Shivpuri Grape Ranch',
        lastUpdated: '2m ago',
        batteryPercent: 65,
      ),
      MapOfficerItem(
        id: 'officer-on-5',
        name: 'Mahesh Kulkarni',
        employeeCode: 'DA-019',
        relativeX: 0.32,
        relativeY: 0.48,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Nashik Rural Central',
        lastUpdated: '4m ago',
        batteryPercent: 88,
      ),
      MapOfficerItem(
        id: 'officer-on-6',
        name: 'Ganesh More',
        employeeCode: 'DA-064',
        relativeX: 0.62,
        relativeY: 0.49,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Deolali Farm Cluster B',
        lastUpdated: '6m ago',
        batteryPercent: 91,
      ),
      MapOfficerItem(
        id: 'officer-on-7',
        name: 'Deepak Shinde',
        employeeCode: 'DA-073',
        relativeX: 0.47,
        relativeY: 0.63,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Sinnar Industrial Agritech',
        lastUpdated: 'Just now',
        batteryPercent: 54,
      ),
      MapOfficerItem(
        id: 'officer-on-8',
        name: 'Sachin Pawar',
        employeeCode: 'DA-081',
        relativeX: 0.83,
        relativeY: 0.56,
        status: AdminOfficerStatus.onDuty,
        locationName: 'East Sinnar Crop Line',
        lastUpdated: '8m ago',
        batteryPercent: 70,
      ),
      MapOfficerItem(
        id: 'officer-on-9',
        name: 'Nitin Deshmukh',
        employeeCode: 'DA-094',
        relativeX: 0.36,
        relativeY: 0.81,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Trimbak South Ridge',
        lastUpdated: '1m ago',
        batteryPercent: 83,
      ),
      MapOfficerItem(
        id: 'officer-on-10',
        name: 'Ajay Chavan',
        employeeCode: 'DA-108',
        relativeX: 0.79,
        relativeY: 0.84,
        status: AdminOfficerStatus.onDuty,
        locationName: 'Ghats Agronomy Checkpoint',
        lastUpdated: 'Just now',
        batteryPercent: 95,
      ),

      // 2 Stale Location Officers
      MapOfficerItem(
        id: 'officer-stale-1',
        name: 'Prakash Rao',
        employeeCode: 'DA-017',
        relativeX: 0.24,
        relativeY: 0.58,
        status: AdminOfficerStatus.stale,
        locationName: 'Deolali Outskirts Station',
        lastUpdated: '12m ago',
        batteryPercent: 41,
      ),
      MapOfficerItem(
        id: 'officer-stale-2',
        name: 'Anil Sharma',
        employeeCode: 'DA-008',
        relativeX: 0.58,
        relativeY: 0.86,
        status: AdminOfficerStatus.stale,
        locationName: 'Sinnar Border Sector 4',
        lastUpdated: '14m ago',
        batteryPercent: 32,
      ),
    ];
  }
}
