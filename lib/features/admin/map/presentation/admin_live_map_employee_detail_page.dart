import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/admin_bottom_navigation.dart';
import 'controllers/admin_live_map_state.dart';
import 'widgets/admin_map_top_bar.dart';
import 'widgets/live_map_employee_detail_sheet.dart';
import 'widgets/live_map_focused_canvas.dart';

/// Screen 16 — Live Map Employee Detail Sheet (Full Screen View).
///
/// Combines the upper ~45% regional focused cartographic canvas with the
/// persistent lower ~55% field officer telemetry detail sheet.
class AdminLiveMapEmployeeDetailPage extends StatelessWidget {
  const AdminLiveMapEmployeeDetailPage({
    super.key,
    required this.officer,
    this.onBack,
    this.onViewProfile,
    this.onRouteView,
    this.onCallEmployee,
    this.onNavigateToHome,
    this.onNavigateToTeam,
    this.onNavigateToPlaces,
    this.onNavigateToReports,
    this.onNavigateToNotifications,
  });

  final MapOfficerItem officer;
  final VoidCallback? onBack;
  final VoidCallback? onViewProfile;
  final VoidCallback? onRouteView;
  final VoidCallback? onCallEmployee;
  final VoidCallback? onNavigateToHome;
  final VoidCallback? onNavigateToTeam;
  final VoidCallback? onNavigateToPlaces;
  final VoidCallback? onNavigateToReports;
  final VoidCallback? onNavigateToNotifications;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminMapTopBar(
        onSearchPressed: () {
          // Quick filter search
        },
        onNotificationsPressed: onNavigateToNotifications,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;
          final mapHeight = (totalHeight * 0.44).clamp(320.0, 420.0);

          return Stack(
            children: [
              // 1. Upper 44% Focused Map Canvas
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: mapHeight,
                child: LiveMapFocusedCanvas(
                  officer: officer,
                  onBack: onBack ?? () => Navigator.of(context).maybePop(),
                  onRecenter: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Re-centered on ${officer.name}.'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),

              // 2. Lower Sheet (Scrollable to prevent overflow on compact screens)
              Positioned(
                top: mapHeight - 16, // Overlaps top map with rounded top corners
                left: 0,
                right: 0,
                bottom: 0,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: LiveMapEmployeeDetailSheet(
                    officer: officer,
                    isModal: false,
                    onViewProfile: onViewProfile,
                    onRouteView: onRouteView,
                    onCallEmployee: onCallEmployee,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AdminBottomNavigationBar(
        currentIndex: 1, // 'Map' tab active
        onTap: (index) {
          switch (index) {
            case 0:
              onNavigateToHome?.call();
              break;
            case 1:
              // Already on Map
              break;
            case 2:
              onNavigateToTeam?.call();
              break;
            case 3:
              onNavigateToPlaces?.call();
              break;
            case 4:
              onNavigateToReports?.call();
              break;
          }
        },
      ),
    );
  }
}
