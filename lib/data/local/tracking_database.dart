import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

part 'tracking_database.g.dart';

/// GPS points recorded on the phone and not yet confirmed by the server.
/// The id is generated on the phone so a retried upload is recognised as a
/// duplicate (docs/06 section 5).
@DataClassName('QueuedPointRow')
@TableIndex(name: 'idx_queued_points_recorded', columns: {#recordedAt})
class QueuedPoints extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real()();
  RealColumn get speed => real().nullable()();
  RealColumn get heading => real().nullable()();
  RealColumn get altitude => real().nullable()();
  IntColumn get batteryLevel => integer().nullable()();
  BoolColumn get isMock => boolean().withDefault(const Constant(false))();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The session being tracked. At most one row (the store replaces it whole).
@DataClassName('ActiveSessionRow')
class ActiveSessions extends Table {
  TextColumn get sessionId => text()();
  TextColumn get employeeId => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get clockOffsetMs => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// A visit saved on the phone and not yet fully confirmed by the server. The id
/// is generated on the phone, so a retried send is recognised as a duplicate.
/// The entry is deleted once the server holds the row and, if there is one, the
/// photo ([rowSent] true and [photoPath] null).
@DataClassName('PendingVisitRow')
@TableIndex(name: 'idx_pending_visits_captured', columns: {#capturedAt})
class PendingVisits extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get employeeId => text()();
  TextColumn get storeName => text().nullable()();
  TextColumn get note => text().nullable()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real().nullable()();
  DateTimeColumn get capturedAt => dateTime()();

  /// The phone's own copy of the photo; null when there is none (or it is sent).
  TextColumn get photoPath => text().nullable()();

  /// The server has confirmed the visit row.
  BoolColumn get rowSent => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Runs once per connection, in whichever isolate drift opens it.
void _configureConnection(CommonDatabase database) {
  database
    ..execute('PRAGMA journal_mode = WAL;')
    ..execute('PRAGMA busy_timeout = 5000;');
}

@DriftDatabase(tables: [QueuedPoints, ActiveSessions, PendingVisits])
class TrackingDatabase extends _$TrackingDatabase {
  TrackingDatabase(super.executor);

  /// The real on-phone database, in the app's private storage.
  ///
  /// Two isolates open it at the same time: the app screens and the background
  /// tracking service. WAL journalling lets one write while the other reads, and
  /// the busy timeout makes a second writer wait instead of failing.
  TrackingDatabase.onDevice()
    : super(
        driftDatabase(
          name: 'tracking_queue',
          native: const DriftNativeOptions(setup: _configureConnection),
        ),
      );

  @override
  int get schemaVersion => 3;

  /// Version 2 adds [PendingVisits]. Version 3 drops two tables nothing used
  /// any more, `pending_ends` and `tracking_meta`. Neither upgrade touches the
  /// GPS queue already on an installed phone.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(pendingVisits);
      if (from < 3) {
        await m.database.customStatement('DROP TABLE IF EXISTS pending_ends');
        await m.database.customStatement('DROP TABLE IF EXISTS tracking_meta');
      }
    },
  );
}
