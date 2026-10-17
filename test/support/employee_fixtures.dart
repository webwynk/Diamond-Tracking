import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_controller.dart';
import 'package:diamond_tracking/features/admin/employees/presentation/controllers/admin_employee_list_state.dart';

/// Test-only sample roster. Production starts with no employees; tests that
/// exercise filtering, search and detail screens inject this instead.
const List<AdminEmployeeItem> kFixtureEmployees = [
  // 1. Suresh Patel (On Duty)
  AdminEmployeeItem(
    id: 'emp-1',
    name: 'Suresh Patel',
    employeeCode: 'DA-022',
    phoneNumber: '+91 98201 44556',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:04 AM',
    distanceTodayKm: '38.6 km',
    locationName: 'Shivpuri Agricultural Cluster',
  ),

  // 2. Anil Sharma (Check Needed / Suspect)
  AdminEmployeeItem(
    id: 'emp-2',
    name: 'Anil Sharma',
    employeeCode: 'DA-008',
    phoneNumber: '+91 98332 11094',
    status: AdminEmployeeStatus.needsCheck,
    hasFlags: true,
    dutyStartTime: '9:15 AM',
    distanceTodayKm: '14.2 km',
    locationName: 'Dindori Agro Zone',
  ),

  // 3. Prakash Rao (No Update / Stale)
  AdminEmployeeItem(
    id: 'emp-3',
    name: 'Prakash Rao',
    employeeCode: 'DA-017',
    phoneNumber: '+91 97123 88412',
    status: AdminEmployeeStatus.stale,
    dutyStartTime: '8:30 AM',
    distanceTodayKm: '26.8 km',
    locationName: 'Godavari Basin Nursery',
  ),

  // 4. Meena Kulkarni (Off Duty)
  AdminEmployeeItem(
    id: 'emp-4',
    name: 'Meena Kulkarni',
    employeeCode: 'DA-045',
    phoneNumber: '+91 98450 67231',
    status: AdminEmployeeStatus.offDuty,
    locationName: 'Sinnar Hub',
  ),

  // 5. Dinesh Joshi (Blocked / Suspended)
  AdminEmployeeItem(
    id: 'emp-5',
    name: 'Dinesh Joshi',
    employeeCode: 'DA-099',
    phoneNumber: '+91 98210 55432',
    status: AdminEmployeeStatus.blocked,
    isActive: false,
    locationName: 'Nashik Central Depot',
  ),

  // 6. Vikram Gaikwad (On Duty)
  AdminEmployeeItem(
    id: 'emp-6',
    name: 'Vikram Gaikwad',
    employeeCode: 'DA-014',
    phoneNumber: '+91 98201 22334',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:12 AM',
    distanceTodayKm: '41.2 km',
    locationName: 'Niphad Agro Farm 12',
  ),

  // 7. Sunil Jadhav (On Duty)
  AdminEmployeeItem(
    id: 'emp-7',
    name: 'Sunil Jadhav',
    employeeCode: 'DA-052',
    phoneNumber: '+91 98201 33445',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:45 AM',
    distanceTodayKm: '29.5 km',
    locationName: 'Godavari Basin',
  ),

  // 8. Vijay Singh (On Duty)
  AdminEmployeeItem(
    id: 'emp-8',
    name: 'Vijay Singh',
    employeeCode: 'DA-031',
    phoneNumber: '+91 98201 55667',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '7:55 AM',
    distanceTodayKm: '34.0 km',
    locationName: 'Shivpuri Grape Ranch',
  ),

  // 9. Ganesh More (On Duty)
  AdminEmployeeItem(
    id: 'emp-9',
    name: 'Ganesh More',
    employeeCode: 'DA-064',
    phoneNumber: '+91 98201 66778',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:20 AM',
    distanceTodayKm: '22.1 km',
    locationName: 'Deolali Farm Cluster B',
  ),

  // 10. Deepak Shinde (On Duty)
  AdminEmployeeItem(
    id: 'emp-10',
    name: 'Deepak Shinde',
    employeeCode: 'DA-073',
    phoneNumber: '+91 98201 77889',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:50 AM',
    distanceTodayKm: '18.7 km',
    locationName: 'Sinnar Industrial Agritech',
  ),

  // 11. R. Shinde (SOS / Check Needed)
  AdminEmployeeItem(
    id: 'emp-11',
    name: 'R. Shinde',
    employeeCode: 'DA-003',
    phoneNumber: '+91 98201 11223',
    status: AdminEmployeeStatus.needsCheck,
    hasFlags: true,
    dutyStartTime: '8:00 AM',
    distanceTodayKm: '12.4 km',
    locationName: 'Dindori Road Border',
  ),

  // 12. Amit Deshmukh (On Duty)
  AdminEmployeeItem(
    id: 'emp-12',
    name: 'Amit Deshmukh',
    employeeCode: 'DA-028',
    phoneNumber: '+91 98201 88990',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:15 AM',
    distanceTodayKm: '31.3 km',
    locationName: 'Trimbak Sector',
  ),

  // 13. Ramesh Pawar (Off Duty)
  AdminEmployeeItem(
    id: 'emp-13',
    name: 'Ramesh Pawar',
    employeeCode: 'DA-012',
    phoneNumber: '+91 98201 99001',
    status: AdminEmployeeStatus.offDuty,
    locationName: 'Yeola Onion Tract',
  ),

  // 14. Kavita Patil (On Duty)
  AdminEmployeeItem(
    id: 'emp-14',
    name: 'Kavita Patil',
    employeeCode: 'DA-088',
    phoneNumber: '+91 98201 12345',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:05 AM',
    distanceTodayKm: '27.4 km',
    locationName: 'Lasalgaon Market',
  ),

  // 15. Rahul Bhosale (On Duty)
  AdminEmployeeItem(
    id: 'emp-15',
    name: 'Rahul Bhosale',
    employeeCode: 'DA-095',
    phoneNumber: '+91 98201 23456',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:35 AM',
    distanceTodayKm: '36.9 km',
    locationName: 'Ozar Airport Zone',
  ),

  // 16. Sanjay Chaudhari (Off Duty)
  AdminEmployeeItem(
    id: 'emp-16',
    name: 'Sanjay Chaudhari',
    employeeCode: 'DA-061',
    phoneNumber: '+91 98201 34567',
    status: AdminEmployeeStatus.offDuty,
    locationName: 'Igatpuri Hills',
  ),

  // 17. Nilesh Wagh (On Duty)
  AdminEmployeeItem(
    id: 'emp-17',
    name: 'Nilesh Wagh',
    employeeCode: 'DA-077',
    phoneNumber: '+91 98201 45678',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:10 AM',
    distanceTodayKm: '44.8 km',
    locationName: 'Chandwad Orchards',
  ),

  // 18. Ajay Jagtap (On Duty)
  AdminEmployeeItem(
    id: 'emp-18',
    name: 'Ajay Jagtap',
    employeeCode: 'DA-036',
    phoneNumber: '+91 98201 56789',
    status: AdminEmployeeStatus.onDuty,
    dutyStartTime: '8:40 AM',
    distanceTodayKm: '25.0 km',
    locationName: 'Kalwan Taluka',
  ),

  // 19. Sachin Thorat (Off Duty)
  AdminEmployeeItem(
    id: 'emp-19',
    name: 'Sachin Thorat',
    employeeCode: 'DA-082',
    phoneNumber: '+91 98201 67890',
    status: AdminEmployeeStatus.offDuty,
    locationName: 'Malegaon North',
  ),

  // 20. Hemant Sonawane (Blocked)
  AdminEmployeeItem(
    id: 'emp-20',
    name: 'Hemant Sonawane',
    employeeCode: 'DA-091',
    phoneNumber: '+91 98201 78901',
    status: AdminEmployeeStatus.blocked,
    isActive: false,
    hasFlags: true,
    locationName: 'Satana Border',
  ),
];

/// Seeds the roster with [kFixtureEmployees].
class FixtureEmployeeListNotifier extends AdminEmployeeListNotifier {
  @override
  AdminEmployeeListState build() =>
      super.build().copyWith(employees: kFixtureEmployees, hasLoaded: true);
}

/// Provider override that seeds the roster for a test.
final fixtureEmployeeListOverride = adminEmployeeListControllerProvider
    .overrideWith(FixtureEmployeeListNotifier.new);
