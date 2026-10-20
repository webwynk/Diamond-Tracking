import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/failure_log.dart';
import '../../domain/entities/visit_page.dart';
import '../../domain/entities/visit_record.dart';
import '../../domain/repositories/admin_visit_repository.dart';
import '../network_failure.dart';

/// Supabase implementation of [AdminVisitRepository].
///
/// Reads `public.visits` under the admin SELECT policy. Paged by keyset on
/// `(captured_at, id)`, newest first, which the index
/// `idx_visits_employee_captured` serves; an offset would skip or repeat rows
/// when a visit arrives while the admin scrolls (docs/03 section 8).
class SupabaseAdminVisitRepository implements AdminVisitRepository {
  SupabaseAdminVisitRepository([SupabaseClient? client]) : _injected = client;

  static const String _columns =
      'id, session_id, employee_id, store_name, note, latitude, longitude, '
      'accuracy, captured_at, created_at, photo_public_id, '
      'photo_attached_at, photo_removed_at';

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<VisitPage> fetchPage({
    required String employeeId,
    VisitRecord? after,
    int limit = 20,
  }) {
    return _run('load the visits', () async {
      var query = _client
          .from('visits')
          .select(_columns)
          .eq('employee_id', employeeId);
      if (after != null) {
        final at = after.capturedAt.toUtc().toIso8601String();
        query = query.or(
          'captured_at.lt.$at,and(captured_at.eq.$at,id.lt.${after.id})',
        );
      }
      // One extra row tells whether another page exists.
      // `nullsFirst` is Postgres's own default for DESC and what the index is
      // built with; the client's default (NULLS LAST) would add a sort step.
      // Both columns are NOT NULL, so the rows are the same either way.
      final rows = await query
          .order('captured_at', ascending: false, nullsFirst: true)
          .order('id', ascending: false, nullsFirst: true)
          .limit(limit + 1);

      final visits = <VisitRecord>[
        for (final row in rows.take(limit)) VisitRecord.fromMap(row),
      ];
      return VisitPage(visits: visits, hasMore: rows.length > limit);
    });
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const UnauthorizedRoleException(
          'Only active administrators can see visits.',
        );
      }
      throw ServerException('Could not $action. Please try again.');
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      logFailure('AdminVisitRepository: could not $action', e, st);
      throw ServerException('Could not $action. Please try again.');
    }
  }
}
