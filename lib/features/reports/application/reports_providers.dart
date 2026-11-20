import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import '../../../core/supabase/supabase_providers.dart';
import '../data/report_pdf.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';

/// Overridden in tests.
final Provider<ReportsRepository> reportsRepositoryProvider =
    Provider<ReportsRepository>(
      (Ref ref) => SupabaseReportsRepository(ref.watch(supabaseClientProvider)),
    );

/// Overridden in tests (the share sheet is native).
final Provider<PdfSharer> pdfSharerProvider = Provider<PdfSharer>(
  (Ref ref) => const PrintingPdfSharer(),
);

final FutureProviderFamily<List<PersonReport>, ReportRange> reportProvider =
    FutureProvider.autoDispose.family<List<PersonReport>, ReportRange>(
      (Ref ref, ReportRange range) =>
          ref.watch(reportsRepositoryProvider).load(range),
      retry: (int count, Object error) => null,
    );
