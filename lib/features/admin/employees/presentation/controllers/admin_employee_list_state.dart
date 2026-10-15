import 'package:flutter/foundation.dart';

/// Status classification for an employee on the admin roster.
enum AdminEmployeeStatus {
  onDuty,
  needsCheck,
  stale,
  offDuty,
  blocked,
}

/// Filter mode for the admin employee list.
enum AdminEmployeeFilter {
  active,
  onDuty,
  offDuty,
  blocked,
  hasFlags,
}

/// Domain entity representing a field employee on the administration roster.
@immutable
class AdminEmployeeItem {
  const AdminEmployeeItem({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.phoneNumber,
    required this.status,
    this.isActive = true,
    this.hasFlags = false,
    this.dutyStartTime,
    this.distanceTodayKm,
    this.locationName,
  });

  final String id;
  final String name;
  final String employeeCode;
  final String phoneNumber;
  final AdminEmployeeStatus status;
  final bool isActive;
  final bool hasFlags;
  final String? dutyStartTime;
  final String? distanceTodayKm;
  final String? locationName;

  /// Generates clean two-letter monogram initials (e.g., "Suresh Patel" -> "SP").
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'EM';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  AdminEmployeeItem copyWith({
    String? id,
    String? name,
    String? employeeCode,
    String? phoneNumber,
    AdminEmployeeStatus? status,
    bool? isActive,
    bool? hasFlags,
    String? dutyStartTime,
    String? distanceTodayKm,
    String? locationName,
  }) {
    return AdminEmployeeItem(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeCode: employeeCode ?? this.employeeCode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      hasFlags: hasFlags ?? this.hasFlags,
      dutyStartTime: dutyStartTime ?? this.dutyStartTime,
      distanceTodayKm: distanceTodayKm ?? this.distanceTodayKm,
      locationName: locationName ?? this.locationName,
    );
  }
}

/// State representation for Screen 17 (Employee List — Admin).
@immutable
class AdminEmployeeListState {
  const AdminEmployeeListState({
    this.selectedFilter = AdminEmployeeFilter.active,
    this.searchQuery = '',
    this.filterActiveOnly = true,
    this.filterTuneBadgeCount = 1,
    this.employees = const [],
    this.isLoading = false,
  });

  final AdminEmployeeFilter selectedFilter;
  final String searchQuery;
  final bool filterActiveOnly;
  final int filterTuneBadgeCount;
  final List<AdminEmployeeItem> employees;
  final bool isLoading;

  int get totalEmployeesCount => 143;
  int get activeEmployeesCount => 141;
  int get onDutyCount => 112;
  int get offDutyCount => 31;
  int get blockedCount => 2;
  int get hasFlagsCount => 3;

  /// Filtered list based on search term, active-only switch, and selected chip.
  List<AdminEmployeeItem> get filteredEmployees {
    return employees.where((emp) {
      // 1. Active Only Modifier (applies unless Blocked filter is explicitly selected)
      if (filterActiveOnly &&
          selectedFilter != AdminEmployeeFilter.blocked &&
          !emp.isActive) {
        return false;
      }

      // 2. Chip Filter Mode
      switch (selectedFilter) {
        case AdminEmployeeFilter.active:
          // Active-only filtering is controlled by filterActiveOnly above
          break;
        case AdminEmployeeFilter.onDuty:
          if (emp.status != AdminEmployeeStatus.onDuty) return false;
          break;
        case AdminEmployeeFilter.offDuty:
          if (emp.status != AdminEmployeeStatus.offDuty) return false;
          break;
        case AdminEmployeeFilter.blocked:
          if (emp.status != AdminEmployeeStatus.blocked) return false;
          break;
        case AdminEmployeeFilter.hasFlags:
          if (!emp.hasFlags) return false;
          break;
      }

      // 3. Search Query Filter (Matches Name, Employee Code, or Phone Number)
      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final matchesName = emp.name.toLowerCase().contains(query);
        final matchesCode = emp.employeeCode.toLowerCase().contains(query);
        final matchesPhone = emp.phoneNumber.toLowerCase().contains(query);
        return matchesName || matchesCode || matchesPhone;
      }

      return true;
    }).toList();
  }

  AdminEmployeeListState copyWith({
    AdminEmployeeFilter? selectedFilter,
    String? searchQuery,
    bool? filterActiveOnly,
    int? filterTuneBadgeCount,
    List<AdminEmployeeItem>? employees,
    bool? isLoading,
  }) {
    return AdminEmployeeListState(
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      filterActiveOnly: filterActiveOnly ?? this.filterActiveOnly,
      filterTuneBadgeCount: filterTuneBadgeCount ?? this.filterTuneBadgeCount,
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
