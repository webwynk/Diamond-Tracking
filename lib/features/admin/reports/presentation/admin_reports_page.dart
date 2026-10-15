import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../dashboard/presentation/widgets/admin_bottom_navigation.dart';
import 'controllers/admin_reports_controller.dart';
import 'widgets/admin_reports_build_view.dart';
import 'widgets/admin_reports_ready_view.dart';
import 'widgets/admin_reports_top_bar.dart';

/// Screen 26 — Reports (Admin).
///
/// Complete report builder and export interface:
/// - Panel A (Build): Select report type (2x2 grid), date range (chips + calendar readout),
///   employee filters (chips with removal), output format (PDF / Excel), and "Generate report".
/// - Panel B (Ready): Progress telemetry banner ("Completed in 14s"), success check badge,
///   export file metrics card, "Share", "Save to device", and audit log notice.
class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({
    super.key,
    this.onBack,
    this.onNavigateToHome,
    this.onNavigateToMap,
    this.onNavigateToTeam,
    this.onNavigateToPlaces,
  });

  final VoidCallback? onBack;
  final VoidCallback? onNavigateToHome;
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToTeam;
  final VoidCallback? onNavigateToPlaces;

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        widget.onNavigateToHome?.call();
        break;
      case 1:
        widget.onNavigateToMap?.call();
        break;
      case 2:
        widget.onNavigateToTeam?.call();
        break;
      case 3:
        widget.onNavigateToPlaces?.call();
        break;
      case 4:
        // Already on Reports
        break;
    }
  }

  void _handleShare(String fileName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preparing $fileName for system share...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleSaveToDevice(String fileName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved $fileName to device downloads folder.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminReportsControllerProvider);
    final notifier = ref.read(adminReportsControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AdminReportsTopBar(
        isReady: state.isReady,
        onBack: widget.onBack,
        onViewHistory: () {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening previous reports history...'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        onCloseReadyView: notifier.resetToBuild,
      ),
      body: state.isReady
          ? AdminReportsReadyView(
              state: state,
              onShare: () => _handleShare(state.generatedFileName),
              onSaveToDevice: () =>
                  _handleSaveToDevice(state.generatedFileName),
            )
          : AdminReportsBuildView(
              state: state,
              onSelectReportType: notifier.setReportType,
              onSelectDatePreset: notifier.setDateRangePreset,
              onRemoveEmployee: notifier.removeEmployee,
              onSelectFormat: notifier.setReportFormat,
              onGenerateReport: notifier.generateReport,
            ),
      bottomNavigationBar: !state.isReady
          ? AdminBottomNavigationBar(
              currentIndex: 4, // Reports tab active
              onTap: _handleNavigation,
            )
          : null,
    );
  }
}
