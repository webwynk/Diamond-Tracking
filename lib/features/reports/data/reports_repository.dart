import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/ist.dart';
import '../domain/report.dart';

abstract interface class ReportsRepository {
  /// Every employee's days in [range], with their visit counts, sorted by
  /// name. Employees with no days in the range are left out.
  Future<List<PersonReport>> load(ReportRange range);

  /// Writes a PDF export into the admin log (L84).
  Future<void> logExport(
    ReportRange range, {
    required bool detail,
    required int people,
  });
}

class SupabaseReportsRepository implements ReportsRepository {
  SupabaseReportsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> logExport(
    ReportRange range, {
    required bool detail,
    required int people,
  }) => _client.rpc<Object?>(
    'log_report_export',
    params: <String, Object?>{
      'p_from': isoDate(range.from),
      'p_to': isoDate(range.to),
      'p_detail': detail,
      'p_people': people,
    },
  );

  /// The server returns at most 1000 rows per call.
  static const int _page = 1000;

  Future<List<Map<String, dynamic>>> _all(
    PostgrestTransformBuilder<List<Map<String, dynamic>>> Function(
      int from,
      int to,
    )
    page,
  ) async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    for (int from = 0; ; from += _page) {
      final List<Map<String, dynamic>> got = await page(from, from + _page - 1);
      rows.addAll(got);
      if (got.length < _page) return rows;
    }
  }

  @override
  Future<List<PersonReport>> load(ReportRange range) async {
    final DateTime start = Ist.instantAt(
      range.from.year,
      range.from.month,
      range.from.day,
    );
    final DateTime end = Ist.instantAt(
      range.to.year,
      range.to.month,
      range.to.day + 1,
    );
    final List<Object> got = await Future.wait(<Future<Object>>[
      _client
          .from('profiles')
          .select('id, user_code, full_name')
          .eq('role', 'employee')
          .order('full_name'),
      _all(
        (int from, int to) => _client
            .from('duty_days')
            .select(
              'id, user_id, day, status, leave_type, duty_on_at, duty_off_at, '
              'end_reason, worked_minutes, distance_m',
            )
            .gte('day', isoDate(range.from))
            .lte('day', isoDate(range.to))
            .order('id')
            .range(from, to),
      ),
      _all(
        (int from, int to) => _client
            .from('visits')
            .select('duty_day_id')
            .gte('captured_at', start.toIso8601String())
            .lt('captured_at', end.toIso8601String())
            .order('id')
            .range(from, to),
      ),
    ]);
    final List<Map<String, dynamic>> people =
        got[0] as List<Map<String, dynamic>>;
    final List<Map<String, dynamic>> dayRows =
        got[1] as List<Map<String, dynamic>>;
    final Map<int, int> visits = <int, int>{};
    for (final Map<String, dynamic> v in got[2] as List<Map<String, dynamic>>) {
      final int id = (v['duty_day_id'] as num).toInt();
      visits[id] = (visits[id] ?? 0) + 1;
    }
    return buildReports(
      people: <({String id, String code, String name})>[
        for (final Map<String, dynamic> p in people)
          (
            id: p['id'] as String,
            code: p['user_code'] as String,
            name: p['full_name'] as String,
          ),
      ],
      days: <ReportDay>[
        for (final Map<String, dynamic> r in dayRows)
          ReportDay.fromRow(r, visits: visits[(r['id'] as num).toInt()] ?? 0),
      ],
    );
  }
}
