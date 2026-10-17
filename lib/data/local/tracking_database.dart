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

/// A duty-off waiting to be told to the server.
@DataClassName('PendingEndRow')
class PendingEnds extends Table {
  TextColumn get sessionId => text()();
  DateTimeColumn get endedAt => dateTime()();
  TextColumn get reason => text()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// Small named counters (for example how many points were rejected).
@DataClassName('MetaRow')
class TrackingMeta extends Table {
  TextColumn get key => text()();
  IntColumn get intValue => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {key};
}

/// Runs once per connection, in whichever isolate drift opens it.
void _configureConnection(CommonDatabase database) {
  database
    ..execute('PRAGMA journal_mode = WAL;')
    ..execute('PRAGMA busy_timeout = 5000;');
}

@DriftDatabase(
  tables: [QueuedPoints, ActiveSessions, PendingEnds, TrackingMeta],
)
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
  int get schemaVersion => 1;
}
