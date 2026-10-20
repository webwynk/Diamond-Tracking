import 'dart:io';

import 'package:diamond_tracking/data/local/drift_tracking_queue_store.dart';
import 'package:diamond_tracking/data/local/tracking_database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// The phone keeps its GPS queue across app updates, so an upgrade of the
/// on-phone database must never lose a waiting point.
void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<Set<String>> tableNames(TrackingDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    return {for (final row in rows) row.read<String>('name')};
  }

  test('a new install has no pending_ends or tracking_meta table', () async {
    final db = TrackingDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tables = await tableNames(db);

    expect(
      tables,
      containsAll(<String>[
        'queued_points',
        'active_sessions',
        'pending_visits',
      ]),
    );
    expect(tables, isNot(contains('pending_ends')));
    expect(tables, isNot(contains('tracking_meta')));
  });

  test('upgrading from version 2 drops the two unused tables and keeps the '
      'waiting GPS points', () async {
    final directory = await Directory.systemTemp.createTemp('tracking_mig_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/tracking.sqlite');

    // The database exactly as version 2 of the app left it on a phone.
    final raw = sqlite3.open(file.path);
    raw
      ..execute('''
            CREATE TABLE queued_points (
              id TEXT NOT NULL PRIMARY KEY,
              session_id TEXT NOT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              accuracy REAL NOT NULL,
              speed REAL NULL,
              heading REAL NULL,
              altitude REAL NULL,
              battery_level INTEGER NULL,
              is_mock INTEGER NOT NULL DEFAULT 0 CHECK (is_mock IN (0, 1)),
              recorded_at TEXT NOT NULL
            )''')
      ..execute('''
            CREATE TABLE active_sessions (
              session_id TEXT NOT NULL PRIMARY KEY,
              employee_id TEXT NOT NULL,
              started_at TEXT NOT NULL,
              clock_offset_ms INTEGER NOT NULL DEFAULT 0
            )''')
      ..execute('''
            CREATE TABLE pending_ends (
              session_id TEXT NOT NULL PRIMARY KEY,
              ended_at TEXT NOT NULL,
              reason TEXT NOT NULL,
              notes TEXT NULL
            )''')
      ..execute('''
            CREATE TABLE tracking_meta (
              "key" TEXT NOT NULL PRIMARY KEY,
              int_value INTEGER NOT NULL DEFAULT 0
            )''')
      ..execute('''
            CREATE TABLE pending_visits (
              id TEXT NOT NULL PRIMARY KEY,
              session_id TEXT NOT NULL,
              employee_id TEXT NOT NULL,
              store_name TEXT NULL,
              note TEXT NULL,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              accuracy REAL NULL,
              captured_at TEXT NOT NULL,
              photo_path TEXT NULL,
              row_sent INTEGER NOT NULL DEFAULT 0 CHECK (row_sent IN (0, 1))
            )''')
      ..execute(
        'INSERT INTO queued_points (id, session_id, latitude, longitude, '
        "accuracy, recorded_at) VALUES ('kept', 's1', 20.0, 73.0, 5.0, "
        "'2026-10-17T12:00:00.000Z')",
      )
      ..execute('PRAGMA user_version = 2')
      ..close();

    final upgraded = TrackingDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);

    final tables = await tableNames(upgraded);
    expect(tables, isNot(contains('pending_ends')));
    expect(tables, isNot(contains('tracking_meta')));
    expect(tables, contains('pending_visits'));

    final store = DriftTrackingQueueStore(upgraded);
    expect((await store.nextBatch()).single.id, 'kept');
  });
}
