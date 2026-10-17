import 'dart:async';
import 'dart:typed_data';

import 'package:diamond_tracking/core/reports/report_delivery.dart';
import 'package:diamond_tracking/core/reports/report_pdf_renderer.dart';
import 'package:diamond_tracking/core/reports/report_pdf_style.dart';
import 'package:diamond_tracking/core/utils/phone_clock.dart';
import 'package:diamond_tracking/data/repositories/supabase_report_repository.dart';
import 'package:diamond_tracking/domain/entities/report_data.dart';
import 'package:diamond_tracking/domain/entities/user_profile.dart';
import 'package:diamond_tracking/domain/repositories/report_repository.dart';
import 'package:diamond_tracking/features/admin/reports/presentation/controllers/admin_reports_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_controller.dart';
import 'package:diamond_tracking/features/auth/presentation/controllers/auth_state.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:pdf/widgets.dart' as pw;

/// The PDF standard faces, which need no asset. The text is then readable in
/// the PDF bytes, which the tests rely on.
ReportFonts standardReportFonts() =>
    ReportFonts(regular: pw.Font.helvetica(), bold: pw.Font.helveticaBold());

/// Saturday 17 October 2026, 10:00 IST, as the phone's clock.
final DateTime kReportNow = DateTime.utc(2026, 10, 17, 4, 30);

/// One call to [FakeReportRepository.fetch].
class ReportFetchCall {
  const ReportFetchCall(this.from, this.to, this.employeeId);

  final DateTime from;
  final DateTime to;
  final String? employeeId;
}

/// One call to [FakeReportRepository.logExport].
class ReportLogCall {
  const ReportLogCall(this.kind, this.from, this.to, this.employeeId);

  final ReportKind kind;
  final DateTime from;
  final DateTime to;
  final String? employeeId;
}

/// Test-only [ReportRepository] that stands in for the server. It lives in
/// test/ so production code never contains a pretend backend.
class FakeReportRepository implements ReportRepository {
  FakeReportRepository({ReportSource? source})
    : source =
          source ??
          ReportSource(
            sessions: const [],
            employees: const [],
            serverNow: kReportNow,
          );

  ReportSource source;

  /// Set to make a call fail the way the real repository does.
  Exception? fetchError;
  Exception? logError;

  final List<ReportFetchCall> fetchCalls = <ReportFetchCall>[];
  final List<ReportLogCall> logCalls = <ReportLogCall>[];

  /// What happened, in order: `fetch`, `log`.
  final List<String> events = <String>[];

  Completer<void>? _gate;

  /// Holds the next fetch back until [release].
  void gateFetch() => _gate = Completer<void>();

  void release() => _gate?.complete();

  @override
  Future<ReportSource> fetch({
    required DateTime from,
    required DateTime to,
    String? employeeId,
  }) async {
    events.add('fetch');
    fetchCalls.add(ReportFetchCall(from, to, employeeId));
    final gate = _gate;
    if (gate != null) await gate.future;
    final failure = fetchError;
    if (failure != null) throw failure;
    return source;
  }

  @override
  Future<void> logExport({
    required ReportKind kind,
    required DateTime from,
    required DateTime to,
    String? employeeId,
    String format = 'pdf',
  }) async {
    events.add('log');
    logCalls.add(ReportLogCall(kind, from, to, employeeId));
    final failure = logError;
    if (failure != null) throw failure;
  }
}

/// Test-only [ReportDelivery]: records what would have been shared or printed
/// instead of opening a system dialog.
class FakeReportDelivery implements ReportDelivery {
  final List<(Uint8List, String)> shared = <(Uint8List, String)>[];
  final List<(Uint8List, String)> printed = <(Uint8List, String)>[];

  /// Set to make sharing and printing fail.
  Exception? error;

  @override
  Future<void> share(Uint8List bytes, String fileName) async {
    final failure = error;
    if (failure != null) throw failure;
    shared.add((bytes, fileName));
  }

  @override
  Future<void> printOrSave(Uint8List bytes, String fileName) async {
    final failure = error;
    if (failure != null) throw failure;
    printed.add((bytes, fileName));
  }
}

/// Name of the signed-in admin in report tests.
const String kReportAdminName = 'Operations Administrator';

/// A signed-in admin, so no test reaches for the real auth repository.
class _SignedInAdmin extends AuthNotifier {
  @override
  AuthState build() => AuthAuthenticated(
    UserProfile(
      id: 'admin-123',
      role: UserRole.admin,
      status: UserStatus.active,
      fullName: kReportAdminName,
      email: 'admin@diamondagritech.in',
      mustChangePin: false,
      failedLoginAttempts: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  );
}

/// Provider overrides for the Reports screen: a signed-in admin, the fake server, a delivery that
/// opens nothing, the PDF fonts that need no asset (readable in the bytes), and
/// the phone clock fixed at [kReportNow].
List<Override> reportOverrides(
  FakeReportRepository repository,
  FakeReportDelivery delivery, {
  DateTime? now,
}) {
  return <Override>[
    reportRepositoryProvider.overrideWithValue(repository),
    reportDeliveryProvider.overrideWithValue(delivery),
    reportPdfRendererLoaderProvider.overrideWithValue(
      () async =>
          ReportPdfRenderer(fonts: standardReportFonts(), compress: false),
    ),
    phoneClockProvider.overrideWithValue(() => now ?? kReportNow),
    authControllerProvider.overrideWith(_SignedInAdmin.new),
  ];
}
