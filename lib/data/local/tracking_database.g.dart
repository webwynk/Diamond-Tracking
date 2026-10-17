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

class $PendingEndsTable extends PendingEnds
    with TableInfo<$PendingEndsTable, PendingEndRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingEndsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [sessionId, endedAt, reason, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_ends';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingEndRow> instance, {
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
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  PendingEndRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingEndRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $PendingEndsTable createAlias(String alias) {
    return $PendingEndsTable(attachedDatabase, alias);
  }
}

class PendingEndRow extends DataClass implements Insertable<PendingEndRow> {
  final String sessionId;
  final DateTime endedAt;
  final String reason;
  final String? notes;
  const PendingEndRow({
    required this.sessionId,
    required this.endedAt,
    required this.reason,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  PendingEndsCompanion toCompanion(bool nullToAbsent) {
    return PendingEndsCompanion(
      sessionId: Value(sessionId),
      endedAt: Value(endedAt),
      reason: Value(reason),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory PendingEndRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingEndRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      reason: serializer.fromJson<String>(json['reason']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'reason': serializer.toJson<String>(reason),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  PendingEndRow copyWith({
    String? sessionId,
    DateTime? endedAt,
    String? reason,
    Value<String?> notes = const Value.absent(),
  }) => PendingEndRow(
    sessionId: sessionId ?? this.sessionId,
    endedAt: endedAt ?? this.endedAt,
    reason: reason ?? this.reason,
    notes: notes.present ? notes.value : this.notes,
  );
  PendingEndRow copyWithCompanion(PendingEndsCompanion data) {
    return PendingEndRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      reason: data.reason.present ? data.reason.value : this.reason,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingEndRow(')
          ..write('sessionId: $sessionId, ')
          ..write('endedAt: $endedAt, ')
          ..write('reason: $reason, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, endedAt, reason, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingEndRow &&
          other.sessionId == this.sessionId &&
          other.endedAt == this.endedAt &&
          other.reason == this.reason &&
          other.notes == this.notes);
}

class PendingEndsCompanion extends UpdateCompanion<PendingEndRow> {
  final Value<String> sessionId;
  final Value<DateTime> endedAt;
  final Value<String> reason;
  final Value<String?> notes;
  final Value<int> rowid;
  const PendingEndsCompanion({
    this.sessionId = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.reason = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingEndsCompanion.insert({
    required String sessionId,
    required DateTime endedAt,
    required String reason,
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       endedAt = Value(endedAt),
       reason = Value(reason);
  static Insertable<PendingEndRow> custom({
    Expression<String>? sessionId,
    Expression<DateTime>? endedAt,
    Expression<String>? reason,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (endedAt != null) 'ended_at': endedAt,
      if (reason != null) 'reason': reason,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingEndsCompanion copyWith({
    Value<String>? sessionId,
    Value<DateTime>? endedAt,
    Value<String>? reason,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return PendingEndsCompanion(
      sessionId: sessionId ?? this.sessionId,
      endedAt: endedAt ?? this.endedAt,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingEndsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('endedAt: $endedAt, ')
          ..write('reason: $reason, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackingMetaTable extends TrackingMeta
    with TableInfo<$TrackingMetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackingMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _intValueMeta = const VerificationMeta(
    'intValue',
  );
  @override
  late final GeneratedColumn<int> intValue = GeneratedColumn<int>(
    'int_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [key, intValue];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracking_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('int_value')) {
      context.handle(
        _intValueMeta,
        intValue.isAcceptableOrUnknown(data['int_value']!, _intValueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      intValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}int_value'],
      )!,
    );
  }

  @override
  $TrackingMetaTable createAlias(String alias) {
    return $TrackingMetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final int intValue;
  const MetaRow({required this.key, required this.intValue});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['int_value'] = Variable<int>(intValue);
    return map;
  }

  TrackingMetaCompanion toCompanion(bool nullToAbsent) {
    return TrackingMetaCompanion(key: Value(key), intValue: Value(intValue));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      intValue: serializer.fromJson<int>(json['intValue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'intValue': serializer.toJson<int>(intValue),
    };
  }

  MetaRow copyWith({String? key, int? intValue}) =>
      MetaRow(key: key ?? this.key, intValue: intValue ?? this.intValue);
  MetaRow copyWithCompanion(TrackingMetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      intValue: data.intValue.present ? data.intValue.value : this.intValue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('intValue: $intValue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, intValue);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow &&
          other.key == this.key &&
          other.intValue == this.intValue);
}

class TrackingMetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<int> intValue;
  final Value<int> rowid;
  const TrackingMetaCompanion({
    this.key = const Value.absent(),
    this.intValue = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackingMetaCompanion.insert({
    required String key,
    this.intValue = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<int>? intValue,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (intValue != null) 'int_value': intValue,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackingMetaCompanion copyWith({
    Value<String>? key,
    Value<int>? intValue,
    Value<int>? rowid,
  }) {
    return TrackingMetaCompanion(
      key: key ?? this.key,
      intValue: intValue ?? this.intValue,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (intValue.present) {
      map['int_value'] = Variable<int>(intValue.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackingMetaCompanion(')
          ..write('key: $key, ')
          ..write('intValue: $intValue, ')
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
  late final $PendingEndsTable pendingEnds = $PendingEndsTable(this);
  late final $TrackingMetaTable trackingMeta = $TrackingMetaTable(this);
  late final Index idxQueuedPointsRecorded = Index(
    'idx_queued_points_recorded',
    'CREATE INDEX idx_queued_points_recorded ON queued_points (recorded_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    queuedPoints,
    activeSessions,
    pendingEnds,
    trackingMeta,
    idxQueuedPointsRecorded,
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
typedef $$PendingEndsTableCreateCompanionBuilder =
    PendingEndsCompanion Function({
      required String sessionId,
      required DateTime endedAt,
      required String reason,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$PendingEndsTableUpdateCompanionBuilder =
    PendingEndsCompanion Function({
      Value<String> sessionId,
      Value<DateTime> endedAt,
      Value<String> reason,
      Value<String?> notes,
      Value<int> rowid,
    });

class $$PendingEndsTableFilterComposer
    extends Composer<_$TrackingDatabase, $PendingEndsTable> {
  $$PendingEndsTableFilterComposer({
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

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingEndsTableOrderingComposer
    extends Composer<_$TrackingDatabase, $PendingEndsTable> {
  $$PendingEndsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingEndsTableAnnotationComposer
    extends Composer<_$TrackingDatabase, $PendingEndsTable> {
  $$PendingEndsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$PendingEndsTableTableManager
    extends
        RootTableManager<
          _$TrackingDatabase,
          $PendingEndsTable,
          PendingEndRow,
          $$PendingEndsTableFilterComposer,
          $$PendingEndsTableOrderingComposer,
          $$PendingEndsTableAnnotationComposer,
          $$PendingEndsTableCreateCompanionBuilder,
          $$PendingEndsTableUpdateCompanionBuilder,
          (
            PendingEndRow,
            BaseReferences<
              _$TrackingDatabase,
              $PendingEndsTable,
              PendingEndRow
            >,
          ),
          PendingEndRow,
          PrefetchHooks Function()
        > {
  $$PendingEndsTableTableManager(_$TrackingDatabase db, $PendingEndsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingEndsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingEndsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingEndsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingEndsCompanion(
                sessionId: sessionId,
                endedAt: endedAt,
                reason: reason,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required DateTime endedAt,
                required String reason,
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingEndsCompanion.insert(
                sessionId: sessionId,
                endedAt: endedAt,
                reason: reason,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingEndsTable, PendingEndRow>(table),
                  BaseReferences<
                    _$TrackingDatabase,
                    $PendingEndsTable,
                    PendingEndRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingEndsTableProcessedTableManager =
    ProcessedTableManager<
      _$TrackingDatabase,
      $PendingEndsTable,
      PendingEndRow,
      $$PendingEndsTableFilterComposer,
      $$PendingEndsTableOrderingComposer,
      $$PendingEndsTableAnnotationComposer,
      $$PendingEndsTableCreateCompanionBuilder,
      $$PendingEndsTableUpdateCompanionBuilder,
      (
        PendingEndRow,
        BaseReferences<_$TrackingDatabase, $PendingEndsTable, PendingEndRow>,
      ),
      PendingEndRow,
      PrefetchHooks Function()
    >;
typedef $$TrackingMetaTableCreateCompanionBuilder =
    TrackingMetaCompanion Function({
      required String key,
      Value<int> intValue,
      Value<int> rowid,
    });
typedef $$TrackingMetaTableUpdateCompanionBuilder =
    TrackingMetaCompanion Function({
      Value<String> key,
      Value<int> intValue,
      Value<int> rowid,
    });

class $$TrackingMetaTableFilterComposer
    extends Composer<_$TrackingDatabase, $TrackingMetaTable> {
  $$TrackingMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intValue => $composableBuilder(
    column: $table.intValue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrackingMetaTableOrderingComposer
    extends Composer<_$TrackingDatabase, $TrackingMetaTable> {
  $$TrackingMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intValue => $composableBuilder(
    column: $table.intValue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrackingMetaTableAnnotationComposer
    extends Composer<_$TrackingDatabase, $TrackingMetaTable> {
  $$TrackingMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get intValue =>
      $composableBuilder(column: $table.intValue, builder: (column) => column);
}

class $$TrackingMetaTableTableManager
    extends
        RootTableManager<
          _$TrackingDatabase,
          $TrackingMetaTable,
          MetaRow,
          $$TrackingMetaTableFilterComposer,
          $$TrackingMetaTableOrderingComposer,
          $$TrackingMetaTableAnnotationComposer,
          $$TrackingMetaTableCreateCompanionBuilder,
          $$TrackingMetaTableUpdateCompanionBuilder,
          (
            MetaRow,
            BaseReferences<_$TrackingDatabase, $TrackingMetaTable, MetaRow>,
          ),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$TrackingMetaTableTableManager(
    _$TrackingDatabase db,
    $TrackingMetaTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackingMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackingMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackingMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> intValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackingMetaCompanion(
                key: key,
                intValue: intValue,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                Value<int> intValue = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackingMetaCompanion.insert(
                key: key,
                intValue: intValue,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackingMetaTable, MetaRow>(table),
                  BaseReferences<
                    _$TrackingDatabase,
                    $TrackingMetaTable,
                    MetaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrackingMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$TrackingDatabase,
      $TrackingMetaTable,
      MetaRow,
      $$TrackingMetaTableFilterComposer,
      $$TrackingMetaTableOrderingComposer,
      $$TrackingMetaTableAnnotationComposer,
      $$TrackingMetaTableCreateCompanionBuilder,
      $$TrackingMetaTableUpdateCompanionBuilder,
      (
        MetaRow,
        BaseReferences<_$TrackingDatabase, $TrackingMetaTable, MetaRow>,
      ),
      MetaRow,
      PrefetchHooks Function()
    >;

class $TrackingDatabaseManager {
  final _$TrackingDatabase _db;
  $TrackingDatabaseManager(this._db);
  $$QueuedPointsTableTableManager get queuedPoints =>
      $$QueuedPointsTableTableManager(_db, _db.queuedPoints);
  $$ActiveSessionsTableTableManager get activeSessions =>
      $$ActiveSessionsTableTableManager(_db, _db.activeSessions);
  $$PendingEndsTableTableManager get pendingEnds =>
      $$PendingEndsTableTableManager(_db, _db.pendingEnds);
  $$TrackingMetaTableTableManager get trackingMeta =>
      $$TrackingMetaTableTableManager(_db, _db.trackingMeta);
}
