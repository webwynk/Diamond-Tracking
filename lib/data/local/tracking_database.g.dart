// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_database.dart';

// ignore_for_file: type=lint
class $QueuedPointsTable extends QueuedPoints
    with TableInfo<$QueuedPointsTable, QueuedPointRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
    'speed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headingMeta = const VerificationMeta(
    'heading',
  );
  @override
  late final GeneratedColumn<double> heading = GeneratedColumn<double>(
    'heading',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _altitudeMeta = const VerificationMeta(
    'altitude',
  );
  @override
  late final GeneratedColumn<double> altitude = GeneratedColumn<double>(
    'altitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _batteryLevelMeta = const VerificationMeta(
    'batteryLevel',
  );
  @override
  late final GeneratedColumn<int> batteryLevel = GeneratedColumn<int>(
    'battery_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isMockMeta = const VerificationMeta('isMock');
  @override
  late final GeneratedColumn<bool> isMock = GeneratedColumn<bool>(
    'is_mock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_mock" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    latitude,
    longitude,
    accuracy,
    speed,
    heading,
    altitude,
    batteryLevel,
    isMock,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueuedPointRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('speed')) {
      context.handle(
        _speedMeta,
        speed.isAcceptableOrUnknown(data['speed']!, _speedMeta),
      );
    }
    if (data.containsKey('heading')) {
      context.handle(
        _headingMeta,
        heading.isAcceptableOrUnknown(data['heading']!, _headingMeta),
      );
    }
    if (data.containsKey('altitude')) {
      context.handle(
        _altitudeMeta,
        altitude.isAcceptableOrUnknown(data['altitude']!, _altitudeMeta),
      );
    }
    if (data.containsKey('battery_level')) {
      context.handle(
        _batteryLevelMeta,
        batteryLevel.isAcceptableOrUnknown(
          data['battery_level']!,
          _batteryLevelMeta,
        ),
      );
    }
    if (data.containsKey('is_mock')) {
      context.handle(
        _isMockMeta,
        isMock.isAcceptableOrUnknown(data['is_mock']!, _isMockMeta),
      );
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QueuedPointRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedPointRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      )!,
      speed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}speed'],
      ),
      heading: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}heading'],
      ),
      altitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}altitude'],
      ),
      batteryLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}battery_level'],
      ),
      isMock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_mock'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $QueuedPointsTable createAlias(String alias) {
    return $QueuedPointsTable(attachedDatabase, alias);
  }
}

class QueuedPointRow extends DataClass implements Insertable<QueuedPointRow> {
  final String id;
  final String sessionId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final int? batteryLevel;
  final bool isMock;
  final DateTime recordedAt;
  const QueuedPointRow({
    required this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.batteryLevel,
    required this.isMock,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['accuracy'] = Variable<double>(accuracy);
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    if (!nullToAbsent || heading != null) {
      map['heading'] = Variable<double>(heading);
    }
    if (!nullToAbsent || altitude != null) {
      map['altitude'] = Variable<double>(altitude);
    }
    if (!nullToAbsent || batteryLevel != null) {
      map['battery_level'] = Variable<int>(batteryLevel);
    }
    map['is_mock'] = Variable<bool>(isMock);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  QueuedPointsCompanion toCompanion(bool nullToAbsent) {
    return QueuedPointsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      accuracy: Value(accuracy),
      speed: speed == null && nullToAbsent
          ? const Value.absent()
          : Value(speed),
      heading: heading == null && nullToAbsent
          ? const Value.absent()
          : Value(heading),
      altitude: altitude == null && nullToAbsent
          ? const Value.absent()
          : Value(altitude),
      batteryLevel: batteryLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(batteryLevel),
      isMock: Value(isMock),
      recordedAt: Value(recordedAt),
    );
  }

  factory QueuedPointRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedPointRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      accuracy: serializer.fromJson<double>(json['accuracy']),
      speed: serializer.fromJson<double?>(json['speed']),
      heading: serializer.fromJson<double?>(json['heading']),
      altitude: serializer.fromJson<double?>(json['altitude']),
      batteryLevel: serializer.fromJson<int?>(json['batteryLevel']),
      isMock: serializer.fromJson<bool>(json['isMock']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'accuracy': serializer.toJson<double>(accuracy),
      'speed': serializer.toJson<double?>(speed),
      'heading': serializer.toJson<double?>(heading),
      'altitude': serializer.toJson<double?>(altitude),
      'batteryLevel': serializer.toJson<int?>(batteryLevel),
      'isMock': serializer.toJson<bool>(isMock),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  QueuedPointRow copyWith({
    String? id,
    String? sessionId,
    double? latitude,
    double? longitude,
    double? accuracy,
    Value<double?> speed = const Value.absent(),
    Value<double?> heading = const Value.absent(),
    Value<double?> altitude = const Value.absent(),
    Value<int?> batteryLevel = const Value.absent(),
    bool? isMock,
    DateTime? recordedAt,
  }) => QueuedPointRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    accuracy: accuracy ?? this.accuracy,
    speed: speed.present ? speed.value : this.speed,
    heading: heading.present ? heading.value : this.heading,
    altitude: altitude.present ? altitude.value : this.altitude,
    batteryLevel: batteryLevel.present ? batteryLevel.value : this.batteryLevel,
    isMock: isMock ?? this.isMock,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  QueuedPointRow copyWithCompanion(QueuedPointsCompanion data) {
    return QueuedPointRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      speed: data.speed.present ? data.speed.value : this.speed,
      heading: data.heading.present ? data.heading.value : this.heading,
      altitude: data.altitude.present ? data.altitude.value : this.altitude,
      batteryLevel: data.batteryLevel.present
          ? data.batteryLevel.value
          : this.batteryLevel,
      isMock: data.isMock.present ? data.isMock.value : this.isMock,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedPointRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('speed: $speed, ')
          ..write('heading: $heading, ')
          ..write('altitude: $altitude, ')
          ..write('batteryLevel: $batteryLevel, ')
          ..write('isMock: $isMock, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    latitude,
    longitude,
    accuracy,
    speed,
    heading,
    altitude,
    batteryLevel,
    isMock,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedPointRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracy == this.accuracy &&
          other.speed == this.speed &&
          other.heading == this.heading &&
          other.altitude == this.altitude &&
          other.batteryLevel == this.batteryLevel &&
          other.isMock == this.isMock &&
          other.recordedAt == this.recordedAt);
}

class QueuedPointsCompanion extends UpdateCompanion<QueuedPointRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> accuracy;
  final Value<double?> speed;
  final Value<double?> heading;
  final Value<double?> altitude;
  final Value<int?> batteryLevel;
  final Value<bool> isMock;
  final Value<DateTime> recordedAt;
  final Value<int> rowid;
  const QueuedPointsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.speed = const Value.absent(),
    this.heading = const Value.absent(),
    this.altitude = const Value.absent(),
    this.batteryLevel = const Value.absent(),
    this.isMock = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueuedPointsCompanion.insert({
    required String id,
    required String sessionId,
    required double latitude,
    required double longitude,
    required double accuracy,
    this.speed = const Value.absent(),
    this.heading = const Value.absent(),
    this.altitude = const Value.absent(),
    this.batteryLevel = const Value.absent(),
    this.isMock = const Value.absent(),
    required DateTime recordedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       latitude = Value(latitude),
       longitude = Value(longitude),
       accuracy = Value(accuracy),
       recordedAt = Value(recordedAt);
  static Insertable<QueuedPointRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracy,
    Expression<double>? speed,
    Expression<double>? heading,
    Expression<double>? altitude,
    Expression<int>? batteryLevel,
    Expression<bool>? isMock,
    Expression<DateTime>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (altitude != null) 'altitude': altitude,
      if (batteryLevel != null) 'battery_level': batteryLevel,
      if (isMock != null) 'is_mock': isMock,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueuedPointsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double>? accuracy,
    Value<double?>? speed,
    Value<double?>? heading,
    Value<double?>? altitude,
    Value<int?>? batteryLevel,
    Value<bool>? isMock,
    Value<DateTime>? recordedAt,
    Value<int>? rowid,
  }) {
    return QueuedPointsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      altitude: altitude ?? this.altitude,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isMock: isMock ?? this.isMock,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (heading.present) {
      map['heading'] = Variable<double>(heading.value);
    }
    if (altitude.present) {
      map['altitude'] = Variable<double>(altitude.value);
    }
    if (batteryLevel.present) {
      map['battery_level'] = Variable<int>(batteryLevel.value);
    }
    if (isMock.present) {
      map['is_mock'] = Variable<bool>(isMock.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueuedPointsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('speed: $speed, ')
          ..write('heading: $heading, ')
          ..write('altitude: $altitude, ')
          ..write('batteryLevel: $batteryLevel, ')
          ..write('isMock: $isMock, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ActiveSessionsTable extends ActiveSessions
    with TableInfo<$ActiveSessionsTable, ActiveSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActiveSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<String> employeeId = GeneratedColumn<String>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clockOffsetMsMeta = const VerificationMeta(
    'clockOffsetMs',
  );
  @override
  late final GeneratedColumn<int> clockOffsetMs = GeneratedColumn<int>(
    'clock_offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    employeeId,
    startedAt,
    clockOffsetMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'active_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActiveSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('clock_offset_ms')) {
      context.handle(
        _clockOffsetMsMeta,
        clockOffsetMs.isAcceptableOrUnknown(
          data['clock_offset_ms']!,
          _clockOffsetMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  ActiveSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActiveSessionRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      clockOffsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clock_offset_ms'],
      )!,
    );
  }

  @override
  $ActiveSessionsTable createAlias(String alias) {
    return $ActiveSessionsTable(attachedDatabase, alias);
  }
}

class ActiveSessionRow extends DataClass
    implements Insertable<ActiveSessionRow> {
  final String sessionId;
  final String employeeId;
  final DateTime startedAt;
  final int clockOffsetMs;
  const ActiveSessionRow({
    required this.sessionId,
    required this.employeeId,
    required this.startedAt,
    required this.clockOffsetMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['employee_id'] = Variable<String>(employeeId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['clock_offset_ms'] = Variable<int>(clockOffsetMs);
    return map;
  }

  ActiveSessionsCompanion toCompanion(bool nullToAbsent) {
    return ActiveSessionsCompanion(
      sessionId: Value(sessionId),
      employeeId: Value(employeeId),
      startedAt: Value(startedAt),
      clockOffsetMs: Value(clockOffsetMs),
    );
  }

  factory ActiveSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActiveSessionRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      employeeId: serializer.fromJson<String>(json['employeeId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      clockOffsetMs: serializer.fromJson<int>(json['clockOffsetMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'employeeId': serializer.toJson<String>(employeeId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'clockOffsetMs': serializer.toJson<int>(clockOffsetMs),
    };
  }

  ActiveSessionRow copyWith({
    String? sessionId,
    String? employeeId,
    DateTime? startedAt,
    int? clockOffsetMs,
  }) => ActiveSessionRow(
    sessionId: sessionId ?? this.sessionId,
    employeeId: employeeId ?? this.employeeId,
    startedAt: startedAt ?? this.startedAt,
    clockOffsetMs: clockOffsetMs ?? this.clockOffsetMs,
  );
  ActiveSessionRow copyWithCompanion(ActiveSessionsCompanion data) {
    return ActiveSessionRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      clockOffsetMs: data.clockOffsetMs.present
          ? data.clockOffsetMs.value
          : this.clockOffsetMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSessionRow(')
          ..write('sessionId: $sessionId, ')
          ..write('employeeId: $employeeId, ')
          ..write('startedAt: $startedAt, ')
          ..write('clockOffsetMs: $clockOffsetMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, employeeId, startedAt, clockOffsetMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActiveSessionRow &&
          other.sessionId == this.sessionId &&
          other.employeeId == this.employeeId &&
          other.startedAt == this.startedAt &&
          other.clockOffsetMs == this.clockOffsetMs);
}

class ActiveSessionsCompanion extends UpdateCompanion<ActiveSessionRow> {
  final Value<String> sessionId;
  final Value<String> employeeId;
  final Value<DateTime> startedAt;
  final Value<int> clockOffsetMs;
  final Value<int> rowid;
  const ActiveSessionsCompanion({
    this.sessionId = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.clockOffsetMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActiveSessionsCompanion.insert({
    required String sessionId,
    required String employeeId,
    required DateTime startedAt,
    this.clockOffsetMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       employeeId = Value(employeeId),
       startedAt = Value(startedAt);
  static Insertable<ActiveSessionRow> custom({
    Expression<String>? sessionId,
    Expression<String>? employeeId,
    Expression<DateTime>? startedAt,
    Expression<int>? clockOffsetMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (employeeId != null) 'employee_id': employeeId,
      if (startedAt != null) 'started_at': startedAt,
      if (clockOffsetMs != null) 'clock_offset_ms': clockOffsetMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActiveSessionsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? employeeId,
    Value<DateTime>? startedAt,
    Value<int>? clockOffsetMs,
    Value<int>? rowid,
  }) {
    return ActiveSessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      employeeId: employeeId ?? this.employeeId,
      startedAt: startedAt ?? this.startedAt,
      clockOffsetMs: clockOffsetMs ?? this.clockOffsetMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<String>(employeeId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (clockOffsetMs.present) {
      map['clock_offset_ms'] = Variable<int>(clockOffsetMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActiveSessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('employeeId: $employeeId, ')
          ..write('startedAt: $startedAt, ')
          ..write('clockOffsetMs: $clockOffsetMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingVisitsTable extends PendingVisits
    with TableInfo<$PendingVisitsTable, PendingVisitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingVisitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<String> employeeId = GeneratedColumn<String>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storeNameMeta = const VerificationMeta(
    'storeName',
  );
  @override
  late final GeneratedColumn<String> storeName = GeneratedColumn<String>(
    'store_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<double> accuracy = GeneratedColumn<double>(
    'accuracy',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rowSentMeta = const VerificationMeta(
    'rowSent',
  );
  @override
  late final GeneratedColumn<bool> rowSent = GeneratedColumn<bool>(
    'row_sent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("row_sent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    employeeId,
    storeName,
    note,
    latitude,
    longitude,
    accuracy,
    capturedAt,
    photoPath,
    rowSent,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_visits';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingVisitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('store_name')) {
      context.handle(
        _storeNameMeta,
        storeName.isAcceptableOrUnknown(data['store_name']!, _storeNameMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('row_sent')) {
      context.handle(
        _rowSentMeta,
        rowSent.isAcceptableOrUnknown(data['row_sent']!, _rowSentMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingVisitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingVisitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_id'],
      )!,
      storeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_name'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      rowSent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}row_sent'],
      )!,
    );
  }

  @override
  $PendingVisitsTable createAlias(String alias) {
    return $PendingVisitsTable(attachedDatabase, alias);
  }
}

class PendingVisitRow extends DataClass implements Insertable<PendingVisitRow> {
  final String id;
  final String sessionId;
  final String employeeId;
  final String? storeName;
  final String? note;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime capturedAt;

  /// The phone's own copy of the photo; null when there is none (or it is sent).
  final String? photoPath;

  /// The server has confirmed the visit row.
  final bool rowSent;
  const PendingVisitRow({
    required this.id,
    required this.sessionId,
    required this.employeeId,
    this.storeName,
    this.note,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.capturedAt,
    this.photoPath,
    required this.rowSent,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['employee_id'] = Variable<String>(employeeId);
    if (!nullToAbsent || storeName != null) {
      map['store_name'] = Variable<String>(storeName);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || accuracy != null) {
      map['accuracy'] = Variable<double>(accuracy);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    map['row_sent'] = Variable<bool>(rowSent);
    return map;
  }

  PendingVisitsCompanion toCompanion(bool nullToAbsent) {
    return PendingVisitsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      employeeId: Value(employeeId),
      storeName: storeName == null && nullToAbsent
          ? const Value.absent()
          : Value(storeName),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      latitude: Value(latitude),
      longitude: Value(longitude),
      accuracy: accuracy == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracy),
      capturedAt: Value(capturedAt),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      rowSent: Value(rowSent),
    );
  }

  factory PendingVisitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingVisitRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      employeeId: serializer.fromJson<String>(json['employeeId']),
      storeName: serializer.fromJson<String?>(json['storeName']),
      note: serializer.fromJson<String?>(json['note']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      accuracy: serializer.fromJson<double?>(json['accuracy']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      rowSent: serializer.fromJson<bool>(json['rowSent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'employeeId': serializer.toJson<String>(employeeId),
      'storeName': serializer.toJson<String?>(storeName),
      'note': serializer.toJson<String?>(note),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'accuracy': serializer.toJson<double?>(accuracy),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'photoPath': serializer.toJson<String?>(photoPath),
      'rowSent': serializer.toJson<bool>(rowSent),
    };
  }

  PendingVisitRow copyWith({
    String? id,
    String? sessionId,
    String? employeeId,
    Value<String?> storeName = const Value.absent(),
    Value<String?> note = const Value.absent(),
    double? latitude,
    double? longitude,
    Value<double?> accuracy = const Value.absent(),
    DateTime? capturedAt,
    Value<String?> photoPath = const Value.absent(),
    bool? rowSent,
  }) => PendingVisitRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    employeeId: employeeId ?? this.employeeId,
    storeName: storeName.present ? storeName.value : this.storeName,
    note: note.present ? note.value : this.note,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    accuracy: accuracy.present ? accuracy.value : this.accuracy,
    capturedAt: capturedAt ?? this.capturedAt,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    rowSent: rowSent ?? this.rowSent,
  );
  PendingVisitRow copyWithCompanion(PendingVisitsCompanion data) {
    return PendingVisitRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      storeName: data.storeName.present ? data.storeName.value : this.storeName,
      note: data.note.present ? data.note.value : this.note,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      rowSent: data.rowSent.present ? data.rowSent.value : this.rowSent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingVisitRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('employeeId: $employeeId, ')
          ..write('storeName: $storeName, ')
          ..write('note: $note, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('photoPath: $photoPath, ')
          ..write('rowSent: $rowSent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    employeeId,
    storeName,
    note,
    latitude,
    longitude,
    accuracy,
    capturedAt,
    photoPath,
    rowSent,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingVisitRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.employeeId == this.employeeId &&
          other.storeName == this.storeName &&
          other.note == this.note &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracy == this.accuracy &&
          other.capturedAt == this.capturedAt &&
          other.photoPath == this.photoPath &&
          other.rowSent == this.rowSent);
}

class PendingVisitsCompanion extends UpdateCompanion<PendingVisitRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> employeeId;
  final Value<String?> storeName;
  final Value<String?> note;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> accuracy;
  final Value<DateTime> capturedAt;
  final Value<String?> photoPath;
  final Value<bool> rowSent;
  final Value<int> rowid;
  const PendingVisitsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.storeName = const Value.absent(),
    this.note = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.rowSent = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingVisitsCompanion.insert({
    required String id,
    required String sessionId,
    required String employeeId,
    this.storeName = const Value.absent(),
    this.note = const Value.absent(),
    required double latitude,
    required double longitude,
    this.accuracy = const Value.absent(),
    required DateTime capturedAt,
    this.photoPath = const Value.absent(),
    this.rowSent = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       employeeId = Value(employeeId),
       latitude = Value(latitude),
       longitude = Value(longitude),
       capturedAt = Value(capturedAt);
  static Insertable<PendingVisitRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? employeeId,
    Expression<String>? storeName,
    Expression<String>? note,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracy,
    Expression<DateTime>? capturedAt,
    Expression<String>? photoPath,
    Expression<bool>? rowSent,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (employeeId != null) 'employee_id': employeeId,
      if (storeName != null) 'store_name': storeName,
      if (note != null) 'note': note,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (photoPath != null) 'photo_path': photoPath,
      if (rowSent != null) 'row_sent': rowSent,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingVisitsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? employeeId,
    Value<String?>? storeName,
    Value<String?>? note,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double?>? accuracy,
    Value<DateTime>? capturedAt,
    Value<String?>? photoPath,
    Value<bool>? rowSent,
    Value<int>? rowid,
  }) {
    return PendingVisitsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      employeeId: employeeId ?? this.employeeId,
      storeName: storeName ?? this.storeName,
      note: note ?? this.note,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      capturedAt: capturedAt ?? this.capturedAt,
      photoPath: photoPath ?? this.photoPath,
      rowSent: rowSent ?? this.rowSent,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<String>(employeeId.value);
    }
    if (storeName.present) {
      map['store_name'] = Variable<String>(storeName.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<double>(accuracy.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (rowSent.present) {
      map['row_sent'] = Variable<bool>(rowSent.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingVisitsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('employeeId: $employeeId, ')
          ..write('storeName: $storeName, ')
          ..write('note: $note, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracy: $accuracy, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('photoPath: $photoPath, ')
          ..write('rowSent: $rowSent, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$TrackingDatabase extends GeneratedDatabase {
  _$TrackingDatabase(QueryExecutor e) : super(e);
  $TrackingDatabaseManager get managers => $TrackingDatabaseManager(this);
  late final $QueuedPointsTable queuedPoints = $QueuedPointsTable(this);
  late final $ActiveSessionsTable activeSessions = $ActiveSessionsTable(this);
  late final $PendingVisitsTable pendingVisits = $PendingVisitsTable(this);
  late final Index idxQueuedPointsRecorded = Index(
    'idx_queued_points_recorded',
    'CREATE INDEX idx_queued_points_recorded ON queued_points (recorded_at)',
  );
  late final Index idxPendingVisitsCaptured = Index(
    'idx_pending_visits_captured',
    'CREATE INDEX idx_pending_visits_captured ON pending_visits (captured_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    queuedPoints,
    activeSessions,
    pendingVisits,
    idxQueuedPointsRecorded,
    idxPendingVisitsCaptured,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$QueuedPointsTableCreateCompanionBuilder =
    QueuedPointsCompanion Function({
      required String id,
      required String sessionId,
      required double latitude,
      required double longitude,
      required double accuracy,
      Value<double?> speed,
      Value<double?> heading,
      Value<double?> altitude,
      Value<int?> batteryLevel,
      Value<bool> isMock,
      required DateTime recordedAt,
      Value<int> rowid,
    });
typedef $$QueuedPointsTableUpdateCompanionBuilder =
    QueuedPointsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<double> latitude,
      Value<double> longitude,
      Value<double> accuracy,
      Value<double?> speed,
      Value<double?> heading,
      Value<double?> altitude,
      Value<int?> batteryLevel,
      Value<bool> isMock,
      Value<DateTime> recordedAt,
      Value<int> rowid,
    });

class $$QueuedPointsTableFilterComposer
    extends Composer<_$TrackingDatabase, $QueuedPointsTable> {
  $$QueuedPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heading => $composableBuilder(
    column: $table.heading,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get batteryLevel => $composableBuilder(
    column: $table.batteryLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMock => $composableBuilder(
    column: $table.isMock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueuedPointsTableOrderingComposer
    extends Composer<_$TrackingDatabase, $QueuedPointsTable> {
  $$QueuedPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get speed => $composableBuilder(
    column: $table.speed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heading => $composableBuilder(
    column: $table.heading,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get altitude => $composableBuilder(
    column: $table.altitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get batteryLevel => $composableBuilder(
    column: $table.batteryLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMock => $composableBuilder(
    column: $table.isMock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueuedPointsTableAnnotationComposer
    extends Composer<_$TrackingDatabase, $QueuedPointsTable> {
  $$QueuedPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<double> get heading =>
      $composableBuilder(column: $table.heading, builder: (column) => column);

  GeneratedColumn<double> get altitude =>
      $composableBuilder(column: $table.altitude, builder: (column) => column);

  GeneratedColumn<int> get batteryLevel => $composableBuilder(
    column: $table.batteryLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMock =>
      $composableBuilder(column: $table.isMock, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$QueuedPointsTableTableManager
    extends
        RootTableManager<
          _$TrackingDatabase,
          $QueuedPointsTable,
          QueuedPointRow,
          $$QueuedPointsTableFilterComposer,
          $$QueuedPointsTableOrderingComposer,
          $$QueuedPointsTableAnnotationComposer,
          $$QueuedPointsTableCreateCompanionBuilder,
          $$QueuedPointsTableUpdateCompanionBuilder,
          (
            QueuedPointRow,
            BaseReferences<
              _$TrackingDatabase,
              $QueuedPointsTable,
              QueuedPointRow
            >,
          ),
          QueuedPointRow,
          PrefetchHooks Function()
        > {
  $$QueuedPointsTableTableManager(
    _$TrackingDatabase db,
    $QueuedPointsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueuedPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueuedPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueuedPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double> accuracy = const Value.absent(),
                Value<double?> speed = const Value.absent(),
                Value<double?> heading = const Value.absent(),
                Value<double?> altitude = const Value.absent(),
                Value<int?> batteryLevel = const Value.absent(),
                Value<bool> isMock = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueuedPointsCompanion(
                id: id,
                sessionId: sessionId,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                speed: speed,
                heading: heading,
                altitude: altitude,
                batteryLevel: batteryLevel,
                isMock: isMock,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required double latitude,
                required double longitude,
                required double accuracy,
                Value<double?> speed = const Value.absent(),
                Value<double?> heading = const Value.absent(),
                Value<double?> altitude = const Value.absent(),
                Value<int?> batteryLevel = const Value.absent(),
                Value<bool> isMock = const Value.absent(),
                required DateTime recordedAt,
                Value<int> rowid = const Value.absent(),
              }) => QueuedPointsCompanion.insert(
                id: id,
                sessionId: sessionId,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                speed: speed,
                heading: heading,
                altitude: altitude,
                batteryLevel: batteryLevel,
                isMock: isMock,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QueuedPointsTable, QueuedPointRow>(table),
                  BaseReferences<
                    _$TrackingDatabase,
                    $QueuedPointsTable,
                    QueuedPointRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueuedPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$TrackingDatabase,
      $QueuedPointsTable,
      QueuedPointRow,
      $$QueuedPointsTableFilterComposer,
      $$QueuedPointsTableOrderingComposer,
      $$QueuedPointsTableAnnotationComposer,
      $$QueuedPointsTableCreateCompanionBuilder,
      $$QueuedPointsTableUpdateCompanionBuilder,
      (
        QueuedPointRow,
        BaseReferences<_$TrackingDatabase, $QueuedPointsTable, QueuedPointRow>,
      ),
      QueuedPointRow,
      PrefetchHooks Function()
    >;
typedef $$ActiveSessionsTableCreateCompanionBuilder =
    ActiveSessionsCompanion Function({
      required String sessionId,
      required String employeeId,
      required DateTime startedAt,
      Value<int> clockOffsetMs,
      Value<int> rowid,
    });
typedef $$ActiveSessionsTableUpdateCompanionBuilder =
    ActiveSessionsCompanion Function({
      Value<String> sessionId,
      Value<String> employeeId,
      Value<DateTime> startedAt,
      Value<int> clockOffsetMs,
      Value<int> rowid,
    });

class $$ActiveSessionsTableFilterComposer
    extends Composer<_$TrackingDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clockOffsetMs => $composableBuilder(
    column: $table.clockOffsetMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActiveSessionsTableOrderingComposer
    extends Composer<_$TrackingDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clockOffsetMs => $composableBuilder(
    column: $table.clockOffsetMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActiveSessionsTableAnnotationComposer
    extends Composer<_$TrackingDatabase, $ActiveSessionsTable> {
  $$ActiveSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get clockOffsetMs => $composableBuilder(
    column: $table.clockOffsetMs,
    builder: (column) => column,
  );
}

class $$ActiveSessionsTableTableManager
    extends
        RootTableManager<
          _$TrackingDatabase,
          $ActiveSessionsTable,
          ActiveSessionRow,
          $$ActiveSessionsTableFilterComposer,
          $$ActiveSessionsTableOrderingComposer,
          $$ActiveSessionsTableAnnotationComposer,
          $$ActiveSessionsTableCreateCompanionBuilder,
          $$ActiveSessionsTableUpdateCompanionBuilder,
          (
            ActiveSessionRow,
            BaseReferences<
              _$TrackingDatabase,
              $ActiveSessionsTable,
              ActiveSessionRow
            >,
          ),
          ActiveSessionRow,
          PrefetchHooks Function()
        > {
  $$ActiveSessionsTableTableManager(
    _$TrackingDatabase db,
    $ActiveSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActiveSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActiveSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActiveSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> employeeId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> clockOffsetMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveSessionsCompanion(
                sessionId: sessionId,
                employeeId: employeeId,
                startedAt: startedAt,
                clockOffsetMs: clockOffsetMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String employeeId,
                required DateTime startedAt,
                Value<int> clockOffsetMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActiveSessionsCompanion.insert(
                sessionId: sessionId,
                employeeId: employeeId,
                startedAt: startedAt,
                clockOffsetMs: clockOffsetMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActiveSessionsTable, ActiveSessionRow>(table),
                  BaseReferences<
                    _$TrackingDatabase,
                    $ActiveSessionsTable,
                    ActiveSessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActiveSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$TrackingDatabase,
      $ActiveSessionsTable,
      ActiveSessionRow,
      $$ActiveSessionsTableFilterComposer,
      $$ActiveSessionsTableOrderingComposer,
      $$ActiveSessionsTableAnnotationComposer,
      $$ActiveSessionsTableCreateCompanionBuilder,
      $$ActiveSessionsTableUpdateCompanionBuilder,
      (
        ActiveSessionRow,
        BaseReferences<
          _$TrackingDatabase,
          $ActiveSessionsTable,
          ActiveSessionRow
        >,
      ),
      ActiveSessionRow,
      PrefetchHooks Function()
    >;
typedef $$PendingVisitsTableCreateCompanionBuilder =
    PendingVisitsCompanion Function({
      required String id,
      required String sessionId,
      required String employeeId,
      Value<String?> storeName,
      Value<String?> note,
      required double latitude,
      required double longitude,
      Value<double?> accuracy,
      required DateTime capturedAt,
      Value<String?> photoPath,
      Value<bool> rowSent,
      Value<int> rowid,
    });
typedef $$PendingVisitsTableUpdateCompanionBuilder =
    PendingVisitsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> employeeId,
      Value<String?> storeName,
      Value<String?> note,
      Value<double> latitude,
      Value<double> longitude,
      Value<double?> accuracy,
      Value<DateTime> capturedAt,
      Value<String?> photoPath,
      Value<bool> rowSent,
      Value<int> rowid,
    });

class $$PendingVisitsTableFilterComposer
    extends Composer<_$TrackingDatabase, $PendingVisitsTable> {
  $$PendingVisitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storeName => $composableBuilder(
    column: $table.storeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get rowSent => $composableBuilder(
    column: $table.rowSent,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingVisitsTableOrderingComposer
    extends Composer<_$TrackingDatabase, $PendingVisitsTable> {
  $$PendingVisitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storeName => $composableBuilder(
    column: $table.storeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get rowSent => $composableBuilder(
    column: $table.rowSent,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingVisitsTableAnnotationComposer
    extends Composer<_$TrackingDatabase, $PendingVisitsTable> {
  $$PendingVisitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get employeeId => $composableBuilder(
    column: $table.employeeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storeName =>
      $composableBuilder(column: $table.storeName, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<bool> get rowSent =>
      $composableBuilder(column: $table.rowSent, builder: (column) => column);
}

class $$PendingVisitsTableTableManager
    extends
        RootTableManager<
          _$TrackingDatabase,
          $PendingVisitsTable,
          PendingVisitRow,
          $$PendingVisitsTableFilterComposer,
          $$PendingVisitsTableOrderingComposer,
          $$PendingVisitsTableAnnotationComposer,
          $$PendingVisitsTableCreateCompanionBuilder,
          $$PendingVisitsTableUpdateCompanionBuilder,
          (
            PendingVisitRow,
            BaseReferences<
              _$TrackingDatabase,
              $PendingVisitsTable,
              PendingVisitRow
            >,
          ),
          PendingVisitRow,
          PrefetchHooks Function()
        > {
  $$PendingVisitsTableTableManager(
    _$TrackingDatabase db,
    $PendingVisitsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingVisitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingVisitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingVisitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> employeeId = const Value.absent(),
                Value<String?> storeName = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double?> accuracy = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<bool> rowSent = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingVisitsCompanion(
                id: id,
                sessionId: sessionId,
                employeeId: employeeId,
                storeName: storeName,
                note: note,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                capturedAt: capturedAt,
                photoPath: photoPath,
                rowSent: rowSent,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String employeeId,
                Value<String?> storeName = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required double latitude,
                required double longitude,
                Value<double?> accuracy = const Value.absent(),
                required DateTime capturedAt,
                Value<String?> photoPath = const Value.absent(),
                Value<bool> rowSent = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingVisitsCompanion.insert(
                id: id,
                sessionId: sessionId,
                employeeId: employeeId,
                storeName: storeName,
                note: note,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                capturedAt: capturedAt,
                photoPath: photoPath,
                rowSent: rowSent,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingVisitsTable, PendingVisitRow>(table),
                  BaseReferences<
                    _$TrackingDatabase,
                    $PendingVisitsTable,
                    PendingVisitRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingVisitsTableProcessedTableManager =
    ProcessedTableManager<
      _$TrackingDatabase,
      $PendingVisitsTable,
      PendingVisitRow,
      $$PendingVisitsTableFilterComposer,
      $$PendingVisitsTableOrderingComposer,
      $$PendingVisitsTableAnnotationComposer,
      $$PendingVisitsTableCreateCompanionBuilder,
      $$PendingVisitsTableUpdateCompanionBuilder,
      (
        PendingVisitRow,
        BaseReferences<
          _$TrackingDatabase,
          $PendingVisitsTable,
          PendingVisitRow
        >,
      ),
      PendingVisitRow,
      PrefetchHooks Function()
    >;

class $TrackingDatabaseManager {
  final _$TrackingDatabase _db;
  $TrackingDatabaseManager(this._db);
  $$QueuedPointsTableTableManager get queuedPoints =>
      $$QueuedPointsTableTableManager(_db, _db.queuedPoints);
  $$ActiveSessionsTableTableManager get activeSessions =>
      $$ActiveSessionsTableTableManager(_db, _db.activeSessions);
  $$PendingVisitsTableTableManager get pendingVisits =>
      $$PendingVisitsTableTableManager(_db, _db.pendingVisits);
}
