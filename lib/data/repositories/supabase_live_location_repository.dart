import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/utils/failure_log.dart';
import '../../domain/entities/live_position.dart';
import '../../domain/repositories/live_location_repository.dart';
import '../network_failure.dart';
import '../server_reads.dart';

/// Supabase implementation of [LiveLocationRepository].
///
/// Reads `public.live_locations` (one row per on-duty employee, written only by
/// database triggers) and listens to its Realtime changes. Row-level security
/// lets an admin read every row; the table is in the `supabase_realtime`
/// publication.
class SupabaseLiveLocationRepository implements LiveLocationRepository {
  SupabaseLiveLocationRepository([SupabaseClient? client]) : _injected = client;

  final SupabaseClient? _injected;

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  @override
  Future<List<LivePosition>> fetchAll() {
    return _run('load the live positions', () async {
      final rows = await _client.from('live_locations').select();
      return <LivePosition>[
        for (final row in rows) ?LivePosition.tryParse(row),
      ];
    });
  }

  @override
  Future<DateTime> getServerTime() {
    return _run('read the server time', () => ServerReads.serverTime(_client));
  }

  @override
  Stream<LiveLocationEvent> watch() {
    late final StreamController<LiveLocationEvent> controller;
    RealtimeChannel? channel;

    void emit(LiveLocationEvent event) {
      if (!controller.isClosed) controller.add(event);
    }

    controller = StreamController<LiveLocationEvent>(
      onListen: () {
        try {
          channel = _client
              .channel(
                'live-locations-${DateTime.now().microsecondsSinceEpoch}',
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'live_locations',
                callback: (payload) {
                  if (payload.eventType == PostgresChangeEvent.delete) {
                    // A delete carries only the primary key.
                    final id = payload.oldRecord['employee_id'];
                    if (id is String) emit(LivePositionRemoved(id));
                    return;
                  }
                  final position = LivePosition.tryParse(payload.newRecord);
                  if (position != null) emit(LivePositionChanged(position));
                },
              )
              .subscribe((status, error) {
                emit(
                  LiveConnectionChanged(
                    connected: status == RealtimeSubscribeStatus.subscribed,
                  ),
                );
              });
        } on Object catch (e) {
          // An exception thrown from onListen would reach the zone as an
          // uncaught error. Say "not connected" instead; the listener still
          // reloads the full list on a timer.
          logFailure('LiveLocationRepository: could not open the channel', e);
          emit(const LiveConnectionChanged(connected: false));
        }
      },
      onCancel: () async {
        final open = channel;
        channel = null;
        if (open != null) await _client.removeChannel(open);
        unawaited(controller.close());
      },
    );
    return controller.stream;
  }

  Future<T> _run<T>(String action, Future<T> Function() body) async {
    try {
      return await body();
    } on AppException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const UnauthorizedRoleException(
          'Only active administrators can see the live map.',
        );
      }
      throw ServerException('Could not $action. Please try again.');
    } catch (e, st) {
      final network = asNetworkFailure(e);
      if (network != null) throw network;
      logFailure('LiveLocationRepository: could not $action', e, st);
      throw ServerException('Could not $action. Please try again.');
    }
  }
}
