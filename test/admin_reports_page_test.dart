import 'package:diamond_tracking/core/theme/app_theme.dart';
import 'package:diamond_tracking/features/admin/dashboard/presentation/admin_dashboard_page.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/admin_reports_page.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/widgets/admin_reports_build_view.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/widgets/admin_reports_ready_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createWidget({VoidCallback? onBack}) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: AdminReportsPage(onBack: onBack),
      ),
    );
  }

  group('Screen 26 AdminReportsPage Visual & Functional Tests', () {
    testWidgets('renders all visual elements on Panel A (Build View)', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // 1. Top App Bar
      expect(find.byKey(const Key('admin-reports-top-bar')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('admin-reports-top-bar')),
          matching: find.text('Reports'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('btn-reports-history')), findsOneWidget);

      // 2. Report Type Grid
      expect(find.text('REPORT TYPE'), findsOneWidget);
      expect(find.byKey(const Key('tile-report-type-daily')), findsOneWidget);
      expect(find.byKey(const Key('tile-report-type-employee')), findsOneWidget);
      expect(find.byKey(const Key('tile-report-type-team')), findsOneWidget);
      expect(find.byKey(const Key('tile-report-type-visit')), findsOneWidget);

      // 3. Date Range Section
      expect(find.text('DATE RANGE'), findsOneWidget);
      expect(find.byKey(const Key('chip-date-this-month')), findsOneWidget);
      expect(find.byKey(const Key('chip-date-today')), findsOneWidget);
      expect(find.byKey(const Key('chip-date-last-7-days')), findsOneWidget);
      expect(find.byKey(const Key('chip-date-custom')), findsOneWidget);
      expect(find.byKey(const Key('field-date-preview')), findsOneWidget);
      expect(find.text('01 Oct 2026 – 12 Oct 2026'), findsOneWidget);

      // 4. Employees Section
      expect(find.text('EMPLOYEES'), findsOneWidget);
      expect(find.byKey(const Key('field-employees-select')), findsOneWidget);
      expect(find.text('All employees (143)'), findsOneWidget);
      expect(find.byKey(const Key('pill-employee-Suresh Patel')), findsOneWidget);
      expect(find.byKey(const Key('pill-employee-Anil Sharma')), findsOneWidget);

      // 5. Format Section
      expect(find.text('FORMAT'), findsOneWidget);
      expect(find.byKey(const Key('tile-format-pdf')), findsOneWidget);
      expect(find.byKey(const Key('tile-format-excel')), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('Excel'), findsOneWidget);

      // 6. Notice Banner & Bottom Bar
      expect(find.byKey(const Key('reports-info-banner')), findsOneWidget);
      expect(find.text('Reports are generated in English.'), findsOneWidget);
      expect(find.byKey(const Key('btn-generate-report')), findsOneWidget);
      expect(find.text('Generate report'), findsOneWidget);
    });

    testWidgets('selecting different report type updates selection', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final employeeTile = find.byKey(const Key('tile-report-type-employee'));
      await tester.tap(employeeTile);
      await tester.pumpAndSettle();

      expect(employeeTile, findsOneWidget);
    });

    testWidgets('selecting date preset updates date preview field', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Tap 'Today' chip
      final todayChip = find.byKey(const Key('chip-date-today'));
      await tester.tap(todayChip);
      await tester.pumpAndSettle();

      expect(find.text('12 Oct 2026'), findsOneWidget);
    });

    testWidgets('removing employee pill removes it from the list', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pill-employee-Suresh Patel')), findsOneWidget);

      final removeSureshBtn = find.byKey(const Key('btn-remove-employee-Suresh Patel'));
      await tester.tap(removeSureshBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pill-employee-Suresh Patel')), findsNothing);
      expect(find.byKey(const Key('pill-employee-Anil Sharma')), findsOneWidget);
    });

    testWidgets('selecting Excel format updates format card', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      final excelTile = find.byKey(const Key('tile-format-excel'));
      await tester.tap(excelTile);
      await tester.pumpAndSettle();

      expect(excelTile, findsOneWidget);
    });

    testWidgets('tapping Generate report transitions from Panel A to Panel B (Ready View)', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byType(AdminReportsBuildView), findsOneWidget);
      expect(find.byType(AdminReportsReadyView), findsNothing);

      // Tap Generate report
      final generateBtn = find.byKey(const Key('btn-generate-report'));
      await tester.tap(generateBtn);
      await tester.pump(); // Start async generation
      await tester.pumpAndSettle(); // Settle after timer completes

      // Panel B should now be visible
      expect(find.byType(AdminReportsReadyView), findsOneWidget);
      expect(find.byType(AdminReportsBuildView), findsNothing);

      // Panel B visual elements
      expect(find.byKey(const Key('reports-progress-banner')), findsOneWidget);
      expect(find.text('Completed in 14s'), findsOneWidget);
      expect(find.text('READY TO EXPORT'), findsOneWidget);
      expect(find.byKey(const Key('badge-report-ready-check')), findsOneWidget);
      expect(find.text('Report ready'), findsOneWidget);
      expect(find.text('Daily detail · 01–12 Oct 2026 · 143 employees'), findsOneWidget);
      expect(find.byKey(const Key('card-generated-file')), findsOneWidget);
      expect(find.text('attendance-oct-2026.pdf'), findsOneWidget);
      expect(find.text('2.4 MB · 1,716 rows'), findsOneWidget);
      expect(find.byKey(const Key('btn-share-report')), findsOneWidget);
      expect(find.byKey(const Key('btn-download-report')), findsOneWidget);
      expect(find.byKey(const Key('text-audit-notice')), findsOneWidget);
    });

    testWidgets('Panel B share and download buttons trigger feedback snackbars', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Generate report to transition to Panel B
      await tester.tap(find.byKey(const Key('btn-generate-report')));
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap Share
      await tester.tap(find.byKey(const Key('btn-share-report')));
      await tester.pump();
      expect(find.text('Preparing attendance-oct-2026.pdf for system share...'), findsOneWidget);

      // Tap Save to device
      await tester.tap(find.byKey(const Key('btn-download-report')));
      await tester.pump();
      expect(find.text('Saved attendance-oct-2026.pdf to device downloads folder.'), findsOneWidget);
    });

    testWidgets('tapping Close button on Panel B returns to Panel A', (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Generate report to transition to Panel B
      await tester.tap(find.byKey(const Key('btn-generate-report')));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AdminReportsReadyView), findsOneWidget);

      // Tap close button in app bar
      final closeBtn = find.byKey(const Key('btn-reports-close'));
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      // Returns to Panel A
      expect(find.byType(AdminReportsBuildView), findsOneWidget);
      expect(find.byType(AdminReportsReadyView), findsNothing);
    });

    testWidgets('AdminDashboardPage bottom navigation tab 4 navigates to AdminReportsPage', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: const AdminDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Reports navigation tab
      final reportsNavTab = find.byKey(const Key('admin-nav-reports'));
      expect(reportsNavTab, findsOneWidget);

      await tester.tap(reportsNavTab);
      await tester.pumpAndSettle();

      // AdminReportsPage should be visible
      expect(find.byType(AdminReportsPage), findsOneWidget);
      expect(find.byKey(const Key('btn-generate-report')), findsOneWidget);
    });
  });
}
