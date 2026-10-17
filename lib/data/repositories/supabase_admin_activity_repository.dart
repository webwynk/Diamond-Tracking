import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../domain/entities/admin_activity_event.dart';
import '../../domain/repositories/admin_activity_repository.dart';
import '../network_failure.dart';

/// Supabase implementation of [AdminActivityRepository].
///
/// Reads `public.duty_sessions` (duty started and ended) and
/// `public.audit_log` (employee created, blocked, unblocked), both readable by
/// admins only through row-level security, and the names of the people in them
/// from `public.profiles`. Four small reads, newest first.
class SupabaseAdminActivityRepository implements AdminActivityRepository {
  SupabaseAdminActivityRepository([SupabaseClient? client])
    : _injected = client;

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  static const String _sessionColumns =
      'id, employee_id, status, started_at, ended_at';

  static const Map<String, AdminActivityKind> _auditKinds =
      <String, AdminActivityKind>{
        'employee_created': AdminActivityKind.employeeCreated,
        'employee_blocked': AdminActivityKind.employeeBlocked,
        'employee_unblocked': AdminActivityKind.employeeUnblocked,
      };

  @override
  Future<List<AdminActivityEvent>> fetchRecent({int limit = 10}) {
    return _run('load recent activity', () async {
      // A session that started long ago can have just ended, so starts and
      // ends are each read newest-first on their own column, then merged.
      final reads = await Future.wait<List<Map<String, dynamic>>>([
        _client
            .from('duty_sessions')
            .select(_sessionColumns)
            .order('started_at', ascending: false)
            .limit(limit),
        _client
            .from('duty_sessions')
            .select(_sessionColumns)
            .not('ended_at', 'is', null)
            .order('ended_at', ascending: false)
            .limit(limit),
        _client
            .from('audit_log')
            .select('id, actor_id, action, target_id, details, created_at')
            .inFilter('action', _auditKinds.keys.toList())
            .order('created_at', ascending: false)
            .limit(limit),
      ]);

      final sessionRows = [...reads[0], ...reads[1]];
      final auditRows = reads[2];
      final names = await _namesOf(<String?>{
        for (final row in sessionRows) row['employee_id'] as String?,
        for (final row in auditRows) ...<String?>[
          row['actor_id'] as String?,
          row['target_id'] as String?,
        ],
      });

      final events = <String, AdminActivityEvent>{};
      for (final row in sessionRows) {
        for (final event in _sessionEvents(row, names)) {
          events[event.id] = event;
        }
      }
      for (final row in auditRows) {
        final event = _auditEvent(row, names);
        if (event != null) events[event.id] = event;
      }

      final newestFirst = events.values.toList()
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      return newestFirst.take(limit).toList();
    });
  }

  Iterable<AdminActivityEvent> _sessionEvents(
    Map<String, dynamic> row,
    Map<String, ({String name, String? code})> names,
  ) sync* {
    final id = row['id'];
    final started = DateTime.tryParse('${row['started_at']}');
    if (id is! String || started == null) return;
    final person = names[row['employee_id']];
    final name = person?.name;
    final code = person?.code;

    yield AdminActivityEvent(
      id: 'start:$id',
      kind: AdminActivityKind.dutyStarted,
      occurredAt: started.toUtc(),
      personName: name ?? 'An employee',
      employeeCode: code,
    );

    final ended = DateTime.tryParse('${row['ended_at']}');
    if (ended == null) return;
    final status = row['status'];
    yield AdminActivityEvent(
      id: 'end:$id',
      kind: status == 'auto_curfew'
          ? AdminActivityKind.dutyAutoEnded
          : AdminActivityKind.dutyEnded,
      occurredAt: ended.toUtc(),
      personName: name ?? 'An employee',
      employeeCode: code,
      detail: status == 'blocked' ? 'Employee was blocked' : null,
    );
  }

  AdminActivityEvent? _auditEvent(
    Map<String, dynamic> row,
    Map<String, ({String name, String? code})> names,
  ) {
    final kind = _auditKinds[row['action']];
    final at = DateTime.tryParse('${row['created_at']}');
    final id = row['id'];
    if (kind == null || at == null || id == null) return null;

    final target = names[row['target_id']];
    final actor = names[row['actor_id']];
    final details = row['details'];
    final code =
        target?.code ?? (details is Map ? details['employee_code'] : null);
    return AdminActivityEvent(
      id: 'audit:$id',
      kind: kind,
      occurredAt: at.toUtc(),
      personName: target?.name ?? 'An employee',
      employeeCode: code is String ? code : null,
      detail: actor == null ? null : 'by ${actor.name}',
    );
  }

  Future<Map<String, ({String name, String? code})>> _namesOf(
    Set<String?> ids,
  ) async {
    final wanted = ids.whereType<String>().toList();
    if (wanted.isEmpty) return const {};
    final rows = await _client
        .from('profiles')
        .select('id, full_name, employee_code')
        .inFilter('id', wanted);
    return {
      for (final row in rows)
        row['id'] as String: (
          name: row['full_name'] as String? ?? 'An employee',
          code: row['employee_code'] as String?,
        ),
    };
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const UnauthorizedRoleException(
          'Only active administrators can see the activity.',
        );
      }
      throw ServerException('Could not $action. Please try again.');
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      debugPrint('AdminActivityRepository: could not $action: $e\n$st');
      throw ServerException('Could not $action. Please try again.');
    }
  }
}
