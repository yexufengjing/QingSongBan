// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AttendanceGroupsTable extends AttendanceGroups
    with TableInfo<$AttendanceGroupsTable, AttendanceGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupTypeMeta = const VerificationMeta(
    'groupType',
  );
  @override
  late final GeneratedColumn<String> groupType = GeneratedColumn<String>(
    'group_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    groupType,
    isEnabled,
    sortOrder,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('group_type')) {
      context.handle(
        _groupTypeMeta,
        groupType.isAcceptableOrUnknown(data['group_type']!, _groupTypeMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttendanceGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      groupType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_type'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $AttendanceGroupsTable createAlias(String alias) {
    return $AttendanceGroupsTable(attachedDatabase, alias);
  }
}

class AttendanceGroup extends DataClass implements Insertable<AttendanceGroup> {
  final int id;
  final String name;
  final String groupType;
  final bool isEnabled;
  final int sortOrder;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const AttendanceGroup({
    required this.id,
    required this.name,
    required this.groupType,
    required this.isEnabled,
    required this.sortOrder,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['group_type'] = Variable<String>(groupType);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  AttendanceGroupsCompanion toCompanion(bool nullToAbsent) {
    return AttendanceGroupsCompanion(
      id: Value(id),
      name: Value(name),
      groupType: Value(groupType),
      isEnabled: Value(isEnabled),
      sortOrder: Value(sortOrder),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory AttendanceGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceGroup(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      groupType: serializer.fromJson<String>(json['groupType']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'groupType': serializer.toJson<String>(groupType),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  AttendanceGroup copyWith({
    int? id,
    String? name,
    String? groupType,
    bool? isEnabled,
    int? sortOrder,
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => AttendanceGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    groupType: groupType ?? this.groupType,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  AttendanceGroup copyWithCompanion(AttendanceGroupsCompanion data) {
    return AttendanceGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      groupType: data.groupType.present ? data.groupType.value : this.groupType,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupType: $groupType, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    groupType,
    isEnabled,
    sortOrder,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.groupType == this.groupType &&
          other.isEnabled == this.isEnabled &&
          other.sortOrder == this.sortOrder &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class AttendanceGroupsCompanion extends UpdateCompanion<AttendanceGroup> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> groupType;
  final Value<bool> isEnabled;
  final Value<int> sortOrder;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const AttendanceGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.groupType = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  AttendanceGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.groupType = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : name = Value(name);
  static Insertable<AttendanceGroup> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? groupType,
    Expression<bool>? isEnabled,
    Expression<int>? sortOrder,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (groupType != null) 'group_type': groupType,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  AttendanceGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? groupType,
    Value<bool>? isEnabled,
    Value<int>? sortOrder,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return AttendanceGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      groupType: groupType ?? this.groupType,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (groupType.present) {
      map['group_type'] = Variable<String>(groupType.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('groupType: $groupType, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $EmployeesTable extends Employees
    with TableInfo<$EmployeesTable, Employee> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmployeesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeNoMeta = const VerificationMeta(
    'employeeNo',
  );
  @override
  late final GeneratedColumn<String> employeeNo = GeneratedColumn<String>(
    'employee_no',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idCardNumberMeta = const VerificationMeta(
    'idCardNumber',
  );
  @override
  late final GeneratedColumn<String> idCardNumber = GeneratedColumn<String>(
    'id_card_number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hireDateMeta = const VerificationMeta(
    'hireDate',
  );
  @override
  late final GeneratedColumn<DateTime> hireDate = GeneratedColumn<DateTime>(
    'hire_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<EmployeeStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('active'),
      ).withConverter<EmployeeStatus>($EmployeesTable.$converterstatus);
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<String> position = GeneratedColumn<String>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _teamMeta = const VerificationMeta('team');
  @override
  late final GeneratedColumn<String> team = GeneratedColumn<String>(
    'team',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workAreaMeta = const VerificationMeta(
    'workArea',
  );
  @override
  late final GeneratedColumn<String> workArea = GeneratedColumn<String>(
    'work_area',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _managerMeta = const VerificationMeta(
    'manager',
  );
  @override
  late final GeneratedColumn<String> manager = GeneratedColumn<String>(
    'manager',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _employmentTypeMeta = const VerificationMeta(
    'employmentType',
  );
  @override
  late final GeneratedColumn<String> employmentType = GeneratedColumn<String>(
    'employment_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultAttendanceGroupIdMeta =
      const VerificationMeta('defaultAttendanceGroupId');
  @override
  late final GeneratedColumn<int> defaultAttendanceGroupId =
      GeneratedColumn<int>(
        'default_attendance_group_id',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES attendance_groups (id)',
        ),
      );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeNo,
    name,
    gender,
    idCardNumber,
    birthDate,
    phone,
    address,
    hireDate,
    status,
    position,
    team,
    workArea,
    manager,
    employmentType,
    defaultAttendanceGroupId,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'employees';
  @override
  VerificationContext validateIntegrity(
    Insertable<Employee> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_no')) {
      context.handle(
        _employeeNoMeta,
        employeeNo.isAcceptableOrUnknown(data['employee_no']!, _employeeNoMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeNoMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('id_card_number')) {
      context.handle(
        _idCardNumberMeta,
        idCardNumber.isAcceptableOrUnknown(
          data['id_card_number']!,
          _idCardNumberMeta,
        ),
      );
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('hire_date')) {
      context.handle(
        _hireDateMeta,
        hireDate.isAcceptableOrUnknown(data['hire_date']!, _hireDateMeta),
      );
    } else if (isInserting) {
      context.missing(_hireDateMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('team')) {
      context.handle(
        _teamMeta,
        team.isAcceptableOrUnknown(data['team']!, _teamMeta),
      );
    }
    if (data.containsKey('work_area')) {
      context.handle(
        _workAreaMeta,
        workArea.isAcceptableOrUnknown(data['work_area']!, _workAreaMeta),
      );
    }
    if (data.containsKey('manager')) {
      context.handle(
        _managerMeta,
        manager.isAcceptableOrUnknown(data['manager']!, _managerMeta),
      );
    }
    if (data.containsKey('employment_type')) {
      context.handle(
        _employmentTypeMeta,
        employmentType.isAcceptableOrUnknown(
          data['employment_type']!,
          _employmentTypeMeta,
        ),
      );
    }
    if (data.containsKey('default_attendance_group_id')) {
      context.handle(
        _defaultAttendanceGroupIdMeta,
        defaultAttendanceGroupId.isAcceptableOrUnknown(
          data['default_attendance_group_id']!,
          _defaultAttendanceGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Employee map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Employee(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employee_no'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      idCardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id_card_number'],
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      hireDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}hire_date'],
      )!,
      status: $EmployeesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}position'],
      ),
      team: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}team'],
      ),
      workArea: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_area'],
      ),
      manager: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manager'],
      ),
      employmentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}employment_type'],
      ),
      defaultAttendanceGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_attendance_group_id'],
      ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $EmployeesTable createAlias(String alias) {
    return $EmployeesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<EmployeeStatus, String, String> $converterstatus =
      const EnumNameConverter<EmployeeStatus>(EmployeeStatus.values);
}

class Employee extends DataClass implements Insertable<Employee> {
  final int id;
  final String employeeNo;
  final String name;
  final String? gender;
  final String? idCardNumber;
  final DateTime? birthDate;
  final String? phone;
  final String? address;
  final DateTime hireDate;
  final EmployeeStatus status;
  final String? position;
  final String? team;
  final String? workArea;
  final String? manager;
  final String? employmentType;
  final int? defaultAttendanceGroupId;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const Employee({
    required this.id,
    required this.employeeNo,
    required this.name,
    this.gender,
    this.idCardNumber,
    this.birthDate,
    this.phone,
    this.address,
    required this.hireDate,
    required this.status,
    this.position,
    this.team,
    this.workArea,
    this.manager,
    this.employmentType,
    this.defaultAttendanceGroupId,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_no'] = Variable<String>(employeeNo);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || idCardNumber != null) {
      map['id_card_number'] = Variable<String>(idCardNumber);
    }
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<DateTime>(birthDate);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    map['hire_date'] = Variable<DateTime>(hireDate);
    {
      map['status'] = Variable<String>(
        $EmployeesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<String>(position);
    }
    if (!nullToAbsent || team != null) {
      map['team'] = Variable<String>(team);
    }
    if (!nullToAbsent || workArea != null) {
      map['work_area'] = Variable<String>(workArea);
    }
    if (!nullToAbsent || manager != null) {
      map['manager'] = Variable<String>(manager);
    }
    if (!nullToAbsent || employmentType != null) {
      map['employment_type'] = Variable<String>(employmentType);
    }
    if (!nullToAbsent || defaultAttendanceGroupId != null) {
      map['default_attendance_group_id'] = Variable<int>(
        defaultAttendanceGroupId,
      );
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  EmployeesCompanion toCompanion(bool nullToAbsent) {
    return EmployeesCompanion(
      id: Value(id),
      employeeNo: Value(employeeNo),
      name: Value(name),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
      idCardNumber: idCardNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(idCardNumber),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      hireDate: Value(hireDate),
      status: Value(status),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      team: team == null && nullToAbsent ? const Value.absent() : Value(team),
      workArea: workArea == null && nullToAbsent
          ? const Value.absent()
          : Value(workArea),
      manager: manager == null && nullToAbsent
          ? const Value.absent()
          : Value(manager),
      employmentType: employmentType == null && nullToAbsent
          ? const Value.absent()
          : Value(employmentType),
      defaultAttendanceGroupId: defaultAttendanceGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultAttendanceGroupId),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory Employee.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Employee(
      id: serializer.fromJson<int>(json['id']),
      employeeNo: serializer.fromJson<String>(json['employeeNo']),
      name: serializer.fromJson<String>(json['name']),
      gender: serializer.fromJson<String?>(json['gender']),
      idCardNumber: serializer.fromJson<String?>(json['idCardNumber']),
      birthDate: serializer.fromJson<DateTime?>(json['birthDate']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      hireDate: serializer.fromJson<DateTime>(json['hireDate']),
      status: $EmployeesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      position: serializer.fromJson<String?>(json['position']),
      team: serializer.fromJson<String?>(json['team']),
      workArea: serializer.fromJson<String?>(json['workArea']),
      manager: serializer.fromJson<String?>(json['manager']),
      employmentType: serializer.fromJson<String?>(json['employmentType']),
      defaultAttendanceGroupId: serializer.fromJson<int?>(
        json['defaultAttendanceGroupId'],
      ),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeNo': serializer.toJson<String>(employeeNo),
      'name': serializer.toJson<String>(name),
      'gender': serializer.toJson<String?>(gender),
      'idCardNumber': serializer.toJson<String?>(idCardNumber),
      'birthDate': serializer.toJson<DateTime?>(birthDate),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
      'hireDate': serializer.toJson<DateTime>(hireDate),
      'status': serializer.toJson<String>(
        $EmployeesTable.$converterstatus.toJson(status),
      ),
      'position': serializer.toJson<String?>(position),
      'team': serializer.toJson<String?>(team),
      'workArea': serializer.toJson<String?>(workArea),
      'manager': serializer.toJson<String?>(manager),
      'employmentType': serializer.toJson<String?>(employmentType),
      'defaultAttendanceGroupId': serializer.toJson<int?>(
        defaultAttendanceGroupId,
      ),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Employee copyWith({
    int? id,
    String? employeeNo,
    String? name,
    Value<String?> gender = const Value.absent(),
    Value<String?> idCardNumber = const Value.absent(),
    Value<DateTime?> birthDate = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    Value<String?> address = const Value.absent(),
    DateTime? hireDate,
    EmployeeStatus? status,
    Value<String?> position = const Value.absent(),
    Value<String?> team = const Value.absent(),
    Value<String?> workArea = const Value.absent(),
    Value<String?> manager = const Value.absent(),
    Value<String?> employmentType = const Value.absent(),
    Value<int?> defaultAttendanceGroupId = const Value.absent(),
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => Employee(
    id: id ?? this.id,
    employeeNo: employeeNo ?? this.employeeNo,
    name: name ?? this.name,
    gender: gender.present ? gender.value : this.gender,
    idCardNumber: idCardNumber.present ? idCardNumber.value : this.idCardNumber,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    phone: phone.present ? phone.value : this.phone,
    address: address.present ? address.value : this.address,
    hireDate: hireDate ?? this.hireDate,
    status: status ?? this.status,
    position: position.present ? position.value : this.position,
    team: team.present ? team.value : this.team,
    workArea: workArea.present ? workArea.value : this.workArea,
    manager: manager.present ? manager.value : this.manager,
    employmentType: employmentType.present
        ? employmentType.value
        : this.employmentType,
    defaultAttendanceGroupId: defaultAttendanceGroupId.present
        ? defaultAttendanceGroupId.value
        : this.defaultAttendanceGroupId,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  Employee copyWithCompanion(EmployeesCompanion data) {
    return Employee(
      id: data.id.present ? data.id.value : this.id,
      employeeNo: data.employeeNo.present
          ? data.employeeNo.value
          : this.employeeNo,
      name: data.name.present ? data.name.value : this.name,
      gender: data.gender.present ? data.gender.value : this.gender,
      idCardNumber: data.idCardNumber.present
          ? data.idCardNumber.value
          : this.idCardNumber,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      hireDate: data.hireDate.present ? data.hireDate.value : this.hireDate,
      status: data.status.present ? data.status.value : this.status,
      position: data.position.present ? data.position.value : this.position,
      team: data.team.present ? data.team.value : this.team,
      workArea: data.workArea.present ? data.workArea.value : this.workArea,
      manager: data.manager.present ? data.manager.value : this.manager,
      employmentType: data.employmentType.present
          ? data.employmentType.value
          : this.employmentType,
      defaultAttendanceGroupId: data.defaultAttendanceGroupId.present
          ? data.defaultAttendanceGroupId.value
          : this.defaultAttendanceGroupId,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Employee(')
          ..write('id: $id, ')
          ..write('employeeNo: $employeeNo, ')
          ..write('name: $name, ')
          ..write('gender: $gender, ')
          ..write('idCardNumber: $idCardNumber, ')
          ..write('birthDate: $birthDate, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('hireDate: $hireDate, ')
          ..write('status: $status, ')
          ..write('position: $position, ')
          ..write('team: $team, ')
          ..write('workArea: $workArea, ')
          ..write('manager: $manager, ')
          ..write('employmentType: $employmentType, ')
          ..write('defaultAttendanceGroupId: $defaultAttendanceGroupId, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeNo,
    name,
    gender,
    idCardNumber,
    birthDate,
    phone,
    address,
    hireDate,
    status,
    position,
    team,
    workArea,
    manager,
    employmentType,
    defaultAttendanceGroupId,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Employee &&
          other.id == this.id &&
          other.employeeNo == this.employeeNo &&
          other.name == this.name &&
          other.gender == this.gender &&
          other.idCardNumber == this.idCardNumber &&
          other.birthDate == this.birthDate &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.hireDate == this.hireDate &&
          other.status == this.status &&
          other.position == this.position &&
          other.team == this.team &&
          other.workArea == this.workArea &&
          other.manager == this.manager &&
          other.employmentType == this.employmentType &&
          other.defaultAttendanceGroupId == this.defaultAttendanceGroupId &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class EmployeesCompanion extends UpdateCompanion<Employee> {
  final Value<int> id;
  final Value<String> employeeNo;
  final Value<String> name;
  final Value<String?> gender;
  final Value<String?> idCardNumber;
  final Value<DateTime?> birthDate;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<DateTime> hireDate;
  final Value<EmployeeStatus> status;
  final Value<String?> position;
  final Value<String?> team;
  final Value<String?> workArea;
  final Value<String?> manager;
  final Value<String?> employmentType;
  final Value<int?> defaultAttendanceGroupId;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const EmployeesCompanion({
    this.id = const Value.absent(),
    this.employeeNo = const Value.absent(),
    this.name = const Value.absent(),
    this.gender = const Value.absent(),
    this.idCardNumber = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.hireDate = const Value.absent(),
    this.status = const Value.absent(),
    this.position = const Value.absent(),
    this.team = const Value.absent(),
    this.workArea = const Value.absent(),
    this.manager = const Value.absent(),
    this.employmentType = const Value.absent(),
    this.defaultAttendanceGroupId = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  EmployeesCompanion.insert({
    this.id = const Value.absent(),
    required String employeeNo,
    required String name,
    this.gender = const Value.absent(),
    this.idCardNumber = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    required DateTime hireDate,
    this.status = const Value.absent(),
    this.position = const Value.absent(),
    this.team = const Value.absent(),
    this.workArea = const Value.absent(),
    this.manager = const Value.absent(),
    this.employmentType = const Value.absent(),
    this.defaultAttendanceGroupId = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : employeeNo = Value(employeeNo),
       name = Value(name),
       hireDate = Value(hireDate);
  static Insertable<Employee> custom({
    Expression<int>? id,
    Expression<String>? employeeNo,
    Expression<String>? name,
    Expression<String>? gender,
    Expression<String>? idCardNumber,
    Expression<DateTime>? birthDate,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<DateTime>? hireDate,
    Expression<String>? status,
    Expression<String>? position,
    Expression<String>? team,
    Expression<String>? workArea,
    Expression<String>? manager,
    Expression<String>? employmentType,
    Expression<int>? defaultAttendanceGroupId,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeNo != null) 'employee_no': employeeNo,
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
      if (idCardNumber != null) 'id_card_number': idCardNumber,
      if (birthDate != null) 'birth_date': birthDate,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (hireDate != null) 'hire_date': hireDate,
      if (status != null) 'status': status,
      if (position != null) 'position': position,
      if (team != null) 'team': team,
      if (workArea != null) 'work_area': workArea,
      if (manager != null) 'manager': manager,
      if (employmentType != null) 'employment_type': employmentType,
      if (defaultAttendanceGroupId != null)
        'default_attendance_group_id': defaultAttendanceGroupId,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  EmployeesCompanion copyWith({
    Value<int>? id,
    Value<String>? employeeNo,
    Value<String>? name,
    Value<String?>? gender,
    Value<String?>? idCardNumber,
    Value<DateTime?>? birthDate,
    Value<String?>? phone,
    Value<String?>? address,
    Value<DateTime>? hireDate,
    Value<EmployeeStatus>? status,
    Value<String?>? position,
    Value<String?>? team,
    Value<String?>? workArea,
    Value<String?>? manager,
    Value<String?>? employmentType,
    Value<int?>? defaultAttendanceGroupId,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return EmployeesCompanion(
      id: id ?? this.id,
      employeeNo: employeeNo ?? this.employeeNo,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      idCardNumber: idCardNumber ?? this.idCardNumber,
      birthDate: birthDate ?? this.birthDate,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      hireDate: hireDate ?? this.hireDate,
      status: status ?? this.status,
      position: position ?? this.position,
      team: team ?? this.team,
      workArea: workArea ?? this.workArea,
      manager: manager ?? this.manager,
      employmentType: employmentType ?? this.employmentType,
      defaultAttendanceGroupId:
          defaultAttendanceGroupId ?? this.defaultAttendanceGroupId,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeNo.present) {
      map['employee_no'] = Variable<String>(employeeNo.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (idCardNumber.present) {
      map['id_card_number'] = Variable<String>(idCardNumber.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (hireDate.present) {
      map['hire_date'] = Variable<DateTime>(hireDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $EmployeesTable.$converterstatus.toSql(status.value),
      );
    }
    if (position.present) {
      map['position'] = Variable<String>(position.value);
    }
    if (team.present) {
      map['team'] = Variable<String>(team.value);
    }
    if (workArea.present) {
      map['work_area'] = Variable<String>(workArea.value);
    }
    if (manager.present) {
      map['manager'] = Variable<String>(manager.value);
    }
    if (employmentType.present) {
      map['employment_type'] = Variable<String>(employmentType.value);
    }
    if (defaultAttendanceGroupId.present) {
      map['default_attendance_group_id'] = Variable<int>(
        defaultAttendanceGroupId.value,
      );
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmployeesCompanion(')
          ..write('id: $id, ')
          ..write('employeeNo: $employeeNo, ')
          ..write('name: $name, ')
          ..write('gender: $gender, ')
          ..write('idCardNumber: $idCardNumber, ')
          ..write('birthDate: $birthDate, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('hireDate: $hireDate, ')
          ..write('status: $status, ')
          ..write('position: $position, ')
          ..write('team: $team, ')
          ..write('workArea: $workArea, ')
          ..write('manager: $manager, ')
          ..write('employmentType: $employmentType, ')
          ..write('defaultAttendanceGroupId: $defaultAttendanceGroupId, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $AttendanceGroupMembersTable extends AttendanceGroupMembers
    with TableInfo<$AttendanceGroupMembersTable, AttendanceGroupMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceGroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _attendanceGroupIdMeta = const VerificationMeta(
    'attendanceGroupId',
  );
  @override
  late final GeneratedColumn<int> attendanceGroupId = GeneratedColumn<int>(
    'attendance_group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attendance_groups (id)',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    attendanceGroupId,
    employeeId,
    isDefault,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceGroupMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('attendance_group_id')) {
      context.handle(
        _attendanceGroupIdMeta,
        attendanceGroupId.isAcceptableOrUnknown(
          data['attendance_group_id']!,
          _attendanceGroupIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attendanceGroupIdMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {attendanceGroupId, employeeId},
  ];
  @override
  AttendanceGroupMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceGroupMember(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      attendanceGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attendance_group_id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $AttendanceGroupMembersTable createAlias(String alias) {
    return $AttendanceGroupMembersTable(attachedDatabase, alias);
  }
}

class AttendanceGroupMember extends DataClass
    implements Insertable<AttendanceGroupMember> {
  final int id;
  final int attendanceGroupId;
  final int employeeId;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const AttendanceGroupMember({
    required this.id,
    required this.attendanceGroupId,
    required this.employeeId,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['attendance_group_id'] = Variable<int>(attendanceGroupId);
    map['employee_id'] = Variable<int>(employeeId);
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  AttendanceGroupMembersCompanion toCompanion(bool nullToAbsent) {
    return AttendanceGroupMembersCompanion(
      id: Value(id),
      attendanceGroupId: Value(attendanceGroupId),
      employeeId: Value(employeeId),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory AttendanceGroupMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceGroupMember(
      id: serializer.fromJson<int>(json['id']),
      attendanceGroupId: serializer.fromJson<int>(json['attendanceGroupId']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'attendanceGroupId': serializer.toJson<int>(attendanceGroupId),
      'employeeId': serializer.toJson<int>(employeeId),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  AttendanceGroupMember copyWith({
    int? id,
    int? attendanceGroupId,
    int? employeeId,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => AttendanceGroupMember(
    id: id ?? this.id,
    attendanceGroupId: attendanceGroupId ?? this.attendanceGroupId,
    employeeId: employeeId ?? this.employeeId,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  AttendanceGroupMember copyWithCompanion(
    AttendanceGroupMembersCompanion data,
  ) {
    return AttendanceGroupMember(
      id: data.id.present ? data.id.value : this.id,
      attendanceGroupId: data.attendanceGroupId.present
          ? data.attendanceGroupId.value
          : this.attendanceGroupId,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceGroupMember(')
          ..write('id: $id, ')
          ..write('attendanceGroupId: $attendanceGroupId, ')
          ..write('employeeId: $employeeId, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    attendanceGroupId,
    employeeId,
    isDefault,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceGroupMember &&
          other.id == this.id &&
          other.attendanceGroupId == this.attendanceGroupId &&
          other.employeeId == this.employeeId &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class AttendanceGroupMembersCompanion
    extends UpdateCompanion<AttendanceGroupMember> {
  final Value<int> id;
  final Value<int> attendanceGroupId;
  final Value<int> employeeId;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const AttendanceGroupMembersCompanion({
    this.id = const Value.absent(),
    this.attendanceGroupId = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  AttendanceGroupMembersCompanion.insert({
    this.id = const Value.absent(),
    required int attendanceGroupId,
    required int employeeId,
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : attendanceGroupId = Value(attendanceGroupId),
       employeeId = Value(employeeId);
  static Insertable<AttendanceGroupMember> custom({
    Expression<int>? id,
    Expression<int>? attendanceGroupId,
    Expression<int>? employeeId,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (attendanceGroupId != null) 'attendance_group_id': attendanceGroupId,
      if (employeeId != null) 'employee_id': employeeId,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  AttendanceGroupMembersCompanion copyWith({
    Value<int>? id,
    Value<int>? attendanceGroupId,
    Value<int>? employeeId,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return AttendanceGroupMembersCompanion(
      id: id ?? this.id,
      attendanceGroupId: attendanceGroupId ?? this.attendanceGroupId,
      employeeId: employeeId ?? this.employeeId,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (attendanceGroupId.present) {
      map['attendance_group_id'] = Variable<int>(attendanceGroupId.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceGroupMembersCompanion(')
          ..write('id: $id, ')
          ..write('attendanceGroupId: $attendanceGroupId, ')
          ..write('employeeId: $employeeId, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $MonthlyAttendanceRostersTable extends MonthlyAttendanceRosters
    with TableInfo<$MonthlyAttendanceRostersTable, MonthlyAttendanceRoster> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthlyAttendanceRostersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _yearMonthMeta = const VerificationMeta(
    'yearMonth',
  );
  @override
  late final GeneratedColumn<String> yearMonth = GeneratedColumn<String>(
    'year_month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attendanceGroupIdMeta = const VerificationMeta(
    'attendanceGroupId',
  );
  @override
  late final GeneratedColumn<int> attendanceGroupId = GeneratedColumn<int>(
    'attendance_group_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attendance_groups (id)',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(DatabaseConstants.manualRosterSource),
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    yearMonth,
    attendanceGroupId,
    employeeId,
    isActive,
    source,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monthly_attendance_rosters';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthlyAttendanceRoster> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('year_month')) {
      context.handle(
        _yearMonthMeta,
        yearMonth.isAcceptableOrUnknown(data['year_month']!, _yearMonthMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMonthMeta);
    }
    if (data.containsKey('attendance_group_id')) {
      context.handle(
        _attendanceGroupIdMeta,
        attendanceGroupId.isAcceptableOrUnknown(
          data['attendance_group_id']!,
          _attendanceGroupIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attendanceGroupIdMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {yearMonth, attendanceGroupId, employeeId},
  ];
  @override
  MonthlyAttendanceRoster map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthlyAttendanceRoster(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      yearMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}year_month'],
      )!,
      attendanceGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attendance_group_id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $MonthlyAttendanceRostersTable createAlias(String alias) {
    return $MonthlyAttendanceRostersTable(attachedDatabase, alias);
  }
}

class MonthlyAttendanceRoster extends DataClass
    implements Insertable<MonthlyAttendanceRoster> {
  final int id;

  /// Stored as YYYY-MM so the month has no timezone ambiguity.
  final String yearMonth;
  final int attendanceGroupId;
  final int employeeId;
  final bool isActive;
  final String source;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const MonthlyAttendanceRoster({
    required this.id,
    required this.yearMonth,
    required this.attendanceGroupId,
    required this.employeeId,
    required this.isActive,
    required this.source,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['year_month'] = Variable<String>(yearMonth);
    map['attendance_group_id'] = Variable<int>(attendanceGroupId);
    map['employee_id'] = Variable<int>(employeeId);
    map['is_active'] = Variable<bool>(isActive);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  MonthlyAttendanceRostersCompanion toCompanion(bool nullToAbsent) {
    return MonthlyAttendanceRostersCompanion(
      id: Value(id),
      yearMonth: Value(yearMonth),
      attendanceGroupId: Value(attendanceGroupId),
      employeeId: Value(employeeId),
      isActive: Value(isActive),
      source: Value(source),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory MonthlyAttendanceRoster.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthlyAttendanceRoster(
      id: serializer.fromJson<int>(json['id']),
      yearMonth: serializer.fromJson<String>(json['yearMonth']),
      attendanceGroupId: serializer.fromJson<int>(json['attendanceGroupId']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      source: serializer.fromJson<String>(json['source']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'yearMonth': serializer.toJson<String>(yearMonth),
      'attendanceGroupId': serializer.toJson<int>(attendanceGroupId),
      'employeeId': serializer.toJson<int>(employeeId),
      'isActive': serializer.toJson<bool>(isActive),
      'source': serializer.toJson<String>(source),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  MonthlyAttendanceRoster copyWith({
    int? id,
    String? yearMonth,
    int? attendanceGroupId,
    int? employeeId,
    bool? isActive,
    String? source,
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => MonthlyAttendanceRoster(
    id: id ?? this.id,
    yearMonth: yearMonth ?? this.yearMonth,
    attendanceGroupId: attendanceGroupId ?? this.attendanceGroupId,
    employeeId: employeeId ?? this.employeeId,
    isActive: isActive ?? this.isActive,
    source: source ?? this.source,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  MonthlyAttendanceRoster copyWithCompanion(
    MonthlyAttendanceRostersCompanion data,
  ) {
    return MonthlyAttendanceRoster(
      id: data.id.present ? data.id.value : this.id,
      yearMonth: data.yearMonth.present ? data.yearMonth.value : this.yearMonth,
      attendanceGroupId: data.attendanceGroupId.present
          ? data.attendanceGroupId.value
          : this.attendanceGroupId,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      source: data.source.present ? data.source.value : this.source,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthlyAttendanceRoster(')
          ..write('id: $id, ')
          ..write('yearMonth: $yearMonth, ')
          ..write('attendanceGroupId: $attendanceGroupId, ')
          ..write('employeeId: $employeeId, ')
          ..write('isActive: $isActive, ')
          ..write('source: $source, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    yearMonth,
    attendanceGroupId,
    employeeId,
    isActive,
    source,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlyAttendanceRoster &&
          other.id == this.id &&
          other.yearMonth == this.yearMonth &&
          other.attendanceGroupId == this.attendanceGroupId &&
          other.employeeId == this.employeeId &&
          other.isActive == this.isActive &&
          other.source == this.source &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class MonthlyAttendanceRostersCompanion
    extends UpdateCompanion<MonthlyAttendanceRoster> {
  final Value<int> id;
  final Value<String> yearMonth;
  final Value<int> attendanceGroupId;
  final Value<int> employeeId;
  final Value<bool> isActive;
  final Value<String> source;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const MonthlyAttendanceRostersCompanion({
    this.id = const Value.absent(),
    this.yearMonth = const Value.absent(),
    this.attendanceGroupId = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.source = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  MonthlyAttendanceRostersCompanion.insert({
    this.id = const Value.absent(),
    required String yearMonth,
    required int attendanceGroupId,
    required int employeeId,
    this.isActive = const Value.absent(),
    this.source = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : yearMonth = Value(yearMonth),
       attendanceGroupId = Value(attendanceGroupId),
       employeeId = Value(employeeId);
  static Insertable<MonthlyAttendanceRoster> custom({
    Expression<int>? id,
    Expression<String>? yearMonth,
    Expression<int>? attendanceGroupId,
    Expression<int>? employeeId,
    Expression<bool>? isActive,
    Expression<String>? source,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (yearMonth != null) 'year_month': yearMonth,
      if (attendanceGroupId != null) 'attendance_group_id': attendanceGroupId,
      if (employeeId != null) 'employee_id': employeeId,
      if (isActive != null) 'is_active': isActive,
      if (source != null) 'source': source,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  MonthlyAttendanceRostersCompanion copyWith({
    Value<int>? id,
    Value<String>? yearMonth,
    Value<int>? attendanceGroupId,
    Value<int>? employeeId,
    Value<bool>? isActive,
    Value<String>? source,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return MonthlyAttendanceRostersCompanion(
      id: id ?? this.id,
      yearMonth: yearMonth ?? this.yearMonth,
      attendanceGroupId: attendanceGroupId ?? this.attendanceGroupId,
      employeeId: employeeId ?? this.employeeId,
      isActive: isActive ?? this.isActive,
      source: source ?? this.source,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (yearMonth.present) {
      map['year_month'] = Variable<String>(yearMonth.value);
    }
    if (attendanceGroupId.present) {
      map['attendance_group_id'] = Variable<int>(attendanceGroupId.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthlyAttendanceRostersCompanion(')
          ..write('id: $id, ')
          ..write('yearMonth: $yearMonth, ')
          ..write('attendanceGroupId: $attendanceGroupId, ')
          ..write('employeeId: $employeeId, ')
          ..write('isActive: $isActive, ')
          ..write('source: $source, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $AttendanceRecordsTable extends AttendanceRecords
    with TableInfo<$AttendanceRecordsTable, AttendanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttendanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _attendanceDateMeta = const VerificationMeta(
    'attendanceDate',
  );
  @override
  late final GeneratedColumn<DateTime> attendanceDate =
      GeneratedColumn<DateTime>(
        'attendance_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  late final GeneratedColumnWithTypeConverter<AttendanceHalfStatus, String>
  morningStatus =
      GeneratedColumn<String>(
        'morning_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('unregistered'),
      ).withConverter<AttendanceHalfStatus>(
        $AttendanceRecordsTable.$convertermorningStatus,
      );
  @override
  late final GeneratedColumnWithTypeConverter<AttendanceHalfStatus, String>
  afternoonStatus =
      GeneratedColumn<String>(
        'afternoon_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('unregistered'),
      ).withConverter<AttendanceHalfStatus>(
        $AttendanceRecordsTable.$converterafternoonStatus,
      );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    attendanceDate,
    morningStatus,
    afternoonStatus,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attendance_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttendanceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('attendance_date')) {
      context.handle(
        _attendanceDateMeta,
        attendanceDate.isAcceptableOrUnknown(
          data['attendance_date']!,
          _attendanceDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attendanceDateMeta);
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {employeeId, attendanceDate},
  ];
  @override
  AttendanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttendanceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      attendanceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}attendance_date'],
      )!,
      morningStatus: $AttendanceRecordsTable.$convertermorningStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}morning_status'],
        )!,
      ),
      afternoonStatus: $AttendanceRecordsTable.$converterafternoonStatus
          .fromSql(
            attachedDatabase.typeMapping.read(
              DriftSqlType.string,
              data['${effectivePrefix}afternoon_status'],
            )!,
          ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $AttendanceRecordsTable createAlias(String alias) {
    return $AttendanceRecordsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AttendanceHalfStatus, String, String>
  $convertermorningStatus = const EnumNameConverter<AttendanceHalfStatus>(
    AttendanceHalfStatus.values,
  );
  static JsonTypeConverter2<AttendanceHalfStatus, String, String>
  $converterafternoonStatus = const EnumNameConverter<AttendanceHalfStatus>(
    AttendanceHalfStatus.values,
  );
}

class AttendanceRecord extends DataClass
    implements Insertable<AttendanceRecord> {
  final int id;
  final int employeeId;

  /// Callers should normalize this value to a local calendar date.
  final DateTime attendanceDate;
  final AttendanceHalfStatus morningStatus;
  final AttendanceHalfStatus afternoonStatus;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.attendanceDate,
    required this.morningStatus,
    required this.afternoonStatus,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['attendance_date'] = Variable<DateTime>(attendanceDate);
    {
      map['morning_status'] = Variable<String>(
        $AttendanceRecordsTable.$convertermorningStatus.toSql(morningStatus),
      );
    }
    {
      map['afternoon_status'] = Variable<String>(
        $AttendanceRecordsTable.$converterafternoonStatus.toSql(
          afternoonStatus,
        ),
      );
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  AttendanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return AttendanceRecordsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      attendanceDate: Value(attendanceDate),
      morningStatus: Value(morningStatus),
      afternoonStatus: Value(afternoonStatus),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory AttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttendanceRecord(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      attendanceDate: serializer.fromJson<DateTime>(json['attendanceDate']),
      morningStatus: $AttendanceRecordsTable.$convertermorningStatus.fromJson(
        serializer.fromJson<String>(json['morningStatus']),
      ),
      afternoonStatus: $AttendanceRecordsTable.$converterafternoonStatus
          .fromJson(serializer.fromJson<String>(json['afternoonStatus'])),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'attendanceDate': serializer.toJson<DateTime>(attendanceDate),
      'morningStatus': serializer.toJson<String>(
        $AttendanceRecordsTable.$convertermorningStatus.toJson(morningStatus),
      ),
      'afternoonStatus': serializer.toJson<String>(
        $AttendanceRecordsTable.$converterafternoonStatus.toJson(
          afternoonStatus,
        ),
      ),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  AttendanceRecord copyWith({
    int? id,
    int? employeeId,
    DateTime? attendanceDate,
    AttendanceHalfStatus? morningStatus,
    AttendanceHalfStatus? afternoonStatus,
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => AttendanceRecord(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    attendanceDate: attendanceDate ?? this.attendanceDate,
    morningStatus: morningStatus ?? this.morningStatus,
    afternoonStatus: afternoonStatus ?? this.afternoonStatus,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  AttendanceRecord copyWithCompanion(AttendanceRecordsCompanion data) {
    return AttendanceRecord(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      attendanceDate: data.attendanceDate.present
          ? data.attendanceDate.value
          : this.attendanceDate,
      morningStatus: data.morningStatus.present
          ? data.morningStatus.value
          : this.morningStatus,
      afternoonStatus: data.afternoonStatus.present
          ? data.afternoonStatus.value
          : this.afternoonStatus,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecord(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('attendanceDate: $attendanceDate, ')
          ..write('morningStatus: $morningStatus, ')
          ..write('afternoonStatus: $afternoonStatus, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    attendanceDate,
    morningStatus,
    afternoonStatus,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttendanceRecord &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.attendanceDate == this.attendanceDate &&
          other.morningStatus == this.morningStatus &&
          other.afternoonStatus == this.afternoonStatus &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class AttendanceRecordsCompanion extends UpdateCompanion<AttendanceRecord> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<DateTime> attendanceDate;
  final Value<AttendanceHalfStatus> morningStatus;
  final Value<AttendanceHalfStatus> afternoonStatus;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const AttendanceRecordsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.attendanceDate = const Value.absent(),
    this.morningStatus = const Value.absent(),
    this.afternoonStatus = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  AttendanceRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required DateTime attendanceDate,
    this.morningStatus = const Value.absent(),
    this.afternoonStatus = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : employeeId = Value(employeeId),
       attendanceDate = Value(attendanceDate);
  static Insertable<AttendanceRecord> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<DateTime>? attendanceDate,
    Expression<String>? morningStatus,
    Expression<String>? afternoonStatus,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (attendanceDate != null) 'attendance_date': attendanceDate,
      if (morningStatus != null) 'morning_status': morningStatus,
      if (afternoonStatus != null) 'afternoon_status': afternoonStatus,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  AttendanceRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<DateTime>? attendanceDate,
    Value<AttendanceHalfStatus>? morningStatus,
    Value<AttendanceHalfStatus>? afternoonStatus,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return AttendanceRecordsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      morningStatus: morningStatus ?? this.morningStatus,
      afternoonStatus: afternoonStatus ?? this.afternoonStatus,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (attendanceDate.present) {
      map['attendance_date'] = Variable<DateTime>(attendanceDate.value);
    }
    if (morningStatus.present) {
      map['morning_status'] = Variable<String>(
        $AttendanceRecordsTable.$convertermorningStatus.toSql(
          morningStatus.value,
        ),
      );
    }
    if (afternoonStatus.present) {
      map['afternoon_status'] = Variable<String>(
        $AttendanceRecordsTable.$converterafternoonStatus.toSql(
          afternoonStatus.value,
        ),
      );
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttendanceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('attendanceDate: $attendanceDate, ')
          ..write('morningStatus: $morningStatus, ')
          ..write('afternoonStatus: $afternoonStatus, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $LeaveRecordsTable extends LeaveRecords
    with TableInfo<$LeaveRecordsTable, LeaveRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LeaveRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<LeaveType, String> leaveType =
      GeneratedColumn<String>(
        'leave_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('personal'),
      ).withConverter<LeaveType>($LeaveRecordsTable.$converterleaveType);
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LeaveHalfPeriod, String>
  startPeriod = GeneratedColumn<String>(
    'start_period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('morning'),
  ).withConverter<LeaveHalfPeriod>($LeaveRecordsTable.$converterstartPeriod);
  @override
  late final GeneratedColumnWithTypeConverter<LeaveHalfPeriod, String>
  endPeriod = GeneratedColumn<String>(
    'end_period',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('afternoon'),
  ).withConverter<LeaveHalfPeriod>($LeaveRecordsTable.$converterendPeriod);
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    leaveType,
    startDate,
    endDate,
    startPeriod,
    endPeriod,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'leave_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<LeaveRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    } else if (isInserting) {
      context.missing(_endDateMeta);
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LeaveRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LeaveRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      leaveType: $LeaveRecordsTable.$converterleaveType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}leave_type'],
        )!,
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      )!,
      startPeriod: $LeaveRecordsTable.$converterstartPeriod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}start_period'],
        )!,
      ),
      endPeriod: $LeaveRecordsTable.$converterendPeriod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}end_period'],
        )!,
      ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $LeaveRecordsTable createAlias(String alias) {
    return $LeaveRecordsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LeaveType, String, String> $converterleaveType =
      const EnumNameConverter<LeaveType>(LeaveType.values);
  static JsonTypeConverter2<LeaveHalfPeriod, String, String>
  $converterstartPeriod = const EnumNameConverter<LeaveHalfPeriod>(
    LeaveHalfPeriod.values,
  );
  static JsonTypeConverter2<LeaveHalfPeriod, String, String>
  $converterendPeriod = const EnumNameConverter<LeaveHalfPeriod>(
    LeaveHalfPeriod.values,
  );
}

class LeaveRecord extends DataClass implements Insertable<LeaveRecord> {
  final int id;
  final int employeeId;
  final LeaveType leaveType;

  /// Local calendar date of the first leave day.
  final DateTime startDate;

  /// Local calendar date of the last leave day.
  final DateTime endDate;

  /// Half-day boundary on [startDate].
  final LeaveHalfPeriod startPeriod;

  /// Half-day boundary on [endDate].
  final LeaveHalfPeriod endPeriod;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const LeaveRecord({
    required this.id,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.startPeriod,
    required this.endPeriod,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    {
      map['leave_type'] = Variable<String>(
        $LeaveRecordsTable.$converterleaveType.toSql(leaveType),
      );
    }
    map['start_date'] = Variable<DateTime>(startDate);
    map['end_date'] = Variable<DateTime>(endDate);
    {
      map['start_period'] = Variable<String>(
        $LeaveRecordsTable.$converterstartPeriod.toSql(startPeriod),
      );
    }
    {
      map['end_period'] = Variable<String>(
        $LeaveRecordsTable.$converterendPeriod.toSql(endPeriod),
      );
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  LeaveRecordsCompanion toCompanion(bool nullToAbsent) {
    return LeaveRecordsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      leaveType: Value(leaveType),
      startDate: Value(startDate),
      endDate: Value(endDate),
      startPeriod: Value(startPeriod),
      endPeriod: Value(endPeriod),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory LeaveRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LeaveRecord(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      leaveType: $LeaveRecordsTable.$converterleaveType.fromJson(
        serializer.fromJson<String>(json['leaveType']),
      ),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime>(json['endDate']),
      startPeriod: $LeaveRecordsTable.$converterstartPeriod.fromJson(
        serializer.fromJson<String>(json['startPeriod']),
      ),
      endPeriod: $LeaveRecordsTable.$converterendPeriod.fromJson(
        serializer.fromJson<String>(json['endPeriod']),
      ),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'leaveType': serializer.toJson<String>(
        $LeaveRecordsTable.$converterleaveType.toJson(leaveType),
      ),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime>(endDate),
      'startPeriod': serializer.toJson<String>(
        $LeaveRecordsTable.$converterstartPeriod.toJson(startPeriod),
      ),
      'endPeriod': serializer.toJson<String>(
        $LeaveRecordsTable.$converterendPeriod.toJson(endPeriod),
      ),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  LeaveRecord copyWith({
    int? id,
    int? employeeId,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    LeaveHalfPeriod? startPeriod,
    LeaveHalfPeriod? endPeriod,
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => LeaveRecord(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    leaveType: leaveType ?? this.leaveType,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    startPeriod: startPeriod ?? this.startPeriod,
    endPeriod: endPeriod ?? this.endPeriod,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  LeaveRecord copyWithCompanion(LeaveRecordsCompanion data) {
    return LeaveRecord(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      leaveType: data.leaveType.present ? data.leaveType.value : this.leaveType,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      startPeriod: data.startPeriod.present
          ? data.startPeriod.value
          : this.startPeriod,
      endPeriod: data.endPeriod.present ? data.endPeriod.value : this.endPeriod,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LeaveRecord(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('leaveType: $leaveType, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('startPeriod: $startPeriod, ')
          ..write('endPeriod: $endPeriod, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    leaveType,
    startDate,
    endDate,
    startPeriod,
    endPeriod,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LeaveRecord &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.leaveType == this.leaveType &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.startPeriod == this.startPeriod &&
          other.endPeriod == this.endPeriod &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class LeaveRecordsCompanion extends UpdateCompanion<LeaveRecord> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<LeaveType> leaveType;
  final Value<DateTime> startDate;
  final Value<DateTime> endDate;
  final Value<LeaveHalfPeriod> startPeriod;
  final Value<LeaveHalfPeriod> endPeriod;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const LeaveRecordsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.leaveType = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.startPeriod = const Value.absent(),
    this.endPeriod = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  LeaveRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    this.leaveType = const Value.absent(),
    required DateTime startDate,
    required DateTime endDate,
    this.startPeriod = const Value.absent(),
    this.endPeriod = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : employeeId = Value(employeeId),
       startDate = Value(startDate),
       endDate = Value(endDate);
  static Insertable<LeaveRecord> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<String>? leaveType,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? startPeriod,
    Expression<String>? endPeriod,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (leaveType != null) 'leave_type': leaveType,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (startPeriod != null) 'start_period': startPeriod,
      if (endPeriod != null) 'end_period': endPeriod,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  LeaveRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<LeaveType>? leaveType,
    Value<DateTime>? startDate,
    Value<DateTime>? endDate,
    Value<LeaveHalfPeriod>? startPeriod,
    Value<LeaveHalfPeriod>? endPeriod,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return LeaveRecordsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (leaveType.present) {
      map['leave_type'] = Variable<String>(
        $LeaveRecordsTable.$converterleaveType.toSql(leaveType.value),
      );
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (startPeriod.present) {
      map['start_period'] = Variable<String>(
        $LeaveRecordsTable.$converterstartPeriod.toSql(startPeriod.value),
      );
    }
    if (endPeriod.present) {
      map['end_period'] = Variable<String>(
        $LeaveRecordsTable.$converterendPeriod.toSql(endPeriod.value),
      );
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LeaveRecordsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('leaveType: $leaveType, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('startPeriod: $startPeriod, ')
          ..write('endPeriod: $endPeriod, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $OvertimeRecordsTable extends OvertimeRecords
    with TableInfo<$OvertimeRecordsTable, OvertimeRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OvertimeRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _overtimeDateMeta = const VerificationMeta(
    'overtimeDate',
  );
  @override
  late final GeneratedColumn<DateTime> overtimeDate = GeneratedColumn<DateTime>(
    'overtime_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMeta = const VerificationMeta(
    'startTime',
  );
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
    'start_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMeta = const VerificationMeta(
    'endTime',
  );
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
    'end_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overtimeTypeMeta = const VerificationMeta(
    'overtimeType',
  );
  @override
  late final GeneratedColumn<String> overtimeType = GeneratedColumn<String>(
    'overtime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('weekday'),
  );
  static const VerificationMeta _workContentMeta = const VerificationMeta(
    'workContent',
  );
  @override
  late final GeneratedColumn<String> workContent = GeneratedColumn<String>(
    'work_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _workLocationMeta = const VerificationMeta(
    'workLocation',
  );
  @override
  late final GeneratedColumn<String> workLocation = GeneratedColumn<String>(
    'work_location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registrantMeta = const VerificationMeta(
    'registrant',
  );
  @override
  late final GeneratedColumn<String> registrant = GeneratedColumn<String>(
    'registrant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    overtimeDate,
    startTime,
    endTime,
    durationMinutes,
    overtimeType,
    workContent,
    workLocation,
    registrant,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'overtime_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<OvertimeRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('overtime_date')) {
      context.handle(
        _overtimeDateMeta,
        overtimeDate.isAcceptableOrUnknown(
          data['overtime_date']!,
          _overtimeDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_overtimeDateMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(
        _startTimeMeta,
        startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(
        _endTimeMeta,
        endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationMinutesMeta);
    }
    if (data.containsKey('overtime_type')) {
      context.handle(
        _overtimeTypeMeta,
        overtimeType.isAcceptableOrUnknown(
          data['overtime_type']!,
          _overtimeTypeMeta,
        ),
      );
    }
    if (data.containsKey('work_content')) {
      context.handle(
        _workContentMeta,
        workContent.isAcceptableOrUnknown(
          data['work_content']!,
          _workContentMeta,
        ),
      );
    }
    if (data.containsKey('work_location')) {
      context.handle(
        _workLocationMeta,
        workLocation.isAcceptableOrUnknown(
          data['work_location']!,
          _workLocationMeta,
        ),
      );
    }
    if (data.containsKey('registrant')) {
      context.handle(
        _registrantMeta,
        registrant.isAcceptableOrUnknown(data['registrant']!, _registrantMeta),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OvertimeRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OvertimeRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      overtimeDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}overtime_date'],
      )!,
      startTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_time'],
      )!,
      endTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_time'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      overtimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overtime_type'],
      )!,
      workContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_content'],
      ),
      workLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}work_location'],
      ),
      registrant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registrant'],
      ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $OvertimeRecordsTable createAlias(String alias) {
    return $OvertimeRecordsTable(attachedDatabase, alias);
  }
}

class OvertimeRecord extends DataClass implements Insertable<OvertimeRecord> {
  final int id;
  final int employeeId;

  /// Local calendar date used by monthly overtime reports.
  final DateTime overtimeDate;

  /// Local date-time of the overtime start.
  final DateTime startTime;

  /// Local date-time of the overtime end.
  final DateTime endTime;
  final int durationMinutes;
  final String overtimeType;
  final String? workContent;
  final String? workLocation;
  final String? registrant;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const OvertimeRecord({
    required this.id,
    required this.employeeId,
    required this.overtimeDate,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.overtimeType,
    this.workContent,
    this.workLocation,
    this.registrant,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['overtime_date'] = Variable<DateTime>(overtimeDate);
    map['start_time'] = Variable<DateTime>(startTime);
    map['end_time'] = Variable<DateTime>(endTime);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['overtime_type'] = Variable<String>(overtimeType);
    if (!nullToAbsent || workContent != null) {
      map['work_content'] = Variable<String>(workContent);
    }
    if (!nullToAbsent || workLocation != null) {
      map['work_location'] = Variable<String>(workLocation);
    }
    if (!nullToAbsent || registrant != null) {
      map['registrant'] = Variable<String>(registrant);
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  OvertimeRecordsCompanion toCompanion(bool nullToAbsent) {
    return OvertimeRecordsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      overtimeDate: Value(overtimeDate),
      startTime: Value(startTime),
      endTime: Value(endTime),
      durationMinutes: Value(durationMinutes),
      overtimeType: Value(overtimeType),
      workContent: workContent == null && nullToAbsent
          ? const Value.absent()
          : Value(workContent),
      workLocation: workLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(workLocation),
      registrant: registrant == null && nullToAbsent
          ? const Value.absent()
          : Value(registrant),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory OvertimeRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OvertimeRecord(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      overtimeDate: serializer.fromJson<DateTime>(json['overtimeDate']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime>(json['endTime']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      overtimeType: serializer.fromJson<String>(json['overtimeType']),
      workContent: serializer.fromJson<String?>(json['workContent']),
      workLocation: serializer.fromJson<String?>(json['workLocation']),
      registrant: serializer.fromJson<String?>(json['registrant']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'overtimeDate': serializer.toJson<DateTime>(overtimeDate),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime>(endTime),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'overtimeType': serializer.toJson<String>(overtimeType),
      'workContent': serializer.toJson<String?>(workContent),
      'workLocation': serializer.toJson<String?>(workLocation),
      'registrant': serializer.toJson<String?>(registrant),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  OvertimeRecord copyWith({
    int? id,
    int? employeeId,
    DateTime? overtimeDate,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    String? overtimeType,
    Value<String?> workContent = const Value.absent(),
    Value<String?> workLocation = const Value.absent(),
    Value<String?> registrant = const Value.absent(),
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => OvertimeRecord(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    overtimeDate: overtimeDate ?? this.overtimeDate,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    overtimeType: overtimeType ?? this.overtimeType,
    workContent: workContent.present ? workContent.value : this.workContent,
    workLocation: workLocation.present ? workLocation.value : this.workLocation,
    registrant: registrant.present ? registrant.value : this.registrant,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  OvertimeRecord copyWithCompanion(OvertimeRecordsCompanion data) {
    return OvertimeRecord(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      overtimeDate: data.overtimeDate.present
          ? data.overtimeDate.value
          : this.overtimeDate,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      overtimeType: data.overtimeType.present
          ? data.overtimeType.value
          : this.overtimeType,
      workContent: data.workContent.present
          ? data.workContent.value
          : this.workContent,
      workLocation: data.workLocation.present
          ? data.workLocation.value
          : this.workLocation,
      registrant: data.registrant.present
          ? data.registrant.value
          : this.registrant,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OvertimeRecord(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('overtimeDate: $overtimeDate, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('overtimeType: $overtimeType, ')
          ..write('workContent: $workContent, ')
          ..write('workLocation: $workLocation, ')
          ..write('registrant: $registrant, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    overtimeDate,
    startTime,
    endTime,
    durationMinutes,
    overtimeType,
    workContent,
    workLocation,
    registrant,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OvertimeRecord &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.overtimeDate == this.overtimeDate &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.durationMinutes == this.durationMinutes &&
          other.overtimeType == this.overtimeType &&
          other.workContent == this.workContent &&
          other.workLocation == this.workLocation &&
          other.registrant == this.registrant &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class OvertimeRecordsCompanion extends UpdateCompanion<OvertimeRecord> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<DateTime> overtimeDate;
  final Value<DateTime> startTime;
  final Value<DateTime> endTime;
  final Value<int> durationMinutes;
  final Value<String> overtimeType;
  final Value<String?> workContent;
  final Value<String?> workLocation;
  final Value<String?> registrant;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const OvertimeRecordsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.overtimeDate = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.overtimeType = const Value.absent(),
    this.workContent = const Value.absent(),
    this.workLocation = const Value.absent(),
    this.registrant = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  OvertimeRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required DateTime overtimeDate,
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
    this.overtimeType = const Value.absent(),
    this.workContent = const Value.absent(),
    this.workLocation = const Value.absent(),
    this.registrant = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : employeeId = Value(employeeId),
       overtimeDate = Value(overtimeDate),
       startTime = Value(startTime),
       endTime = Value(endTime),
       durationMinutes = Value(durationMinutes);
  static Insertable<OvertimeRecord> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<DateTime>? overtimeDate,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<int>? durationMinutes,
    Expression<String>? overtimeType,
    Expression<String>? workContent,
    Expression<String>? workLocation,
    Expression<String>? registrant,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (overtimeDate != null) 'overtime_date': overtimeDate,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (overtimeType != null) 'overtime_type': overtimeType,
      if (workContent != null) 'work_content': workContent,
      if (workLocation != null) 'work_location': workLocation,
      if (registrant != null) 'registrant': registrant,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  OvertimeRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<DateTime>? overtimeDate,
    Value<DateTime>? startTime,
    Value<DateTime>? endTime,
    Value<int>? durationMinutes,
    Value<String>? overtimeType,
    Value<String?>? workContent,
    Value<String?>? workLocation,
    Value<String?>? registrant,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return OvertimeRecordsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      overtimeDate: overtimeDate ?? this.overtimeDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      overtimeType: overtimeType ?? this.overtimeType,
      workContent: workContent ?? this.workContent,
      workLocation: workLocation ?? this.workLocation,
      registrant: registrant ?? this.registrant,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (overtimeDate.present) {
      map['overtime_date'] = Variable<DateTime>(overtimeDate.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (overtimeType.present) {
      map['overtime_type'] = Variable<String>(overtimeType.value);
    }
    if (workContent.present) {
      map['work_content'] = Variable<String>(workContent.value);
    }
    if (workLocation.present) {
      map['work_location'] = Variable<String>(workLocation.value);
    }
    if (registrant.present) {
      map['registrant'] = Variable<String>(registrant.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OvertimeRecordsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('overtimeDate: $overtimeDate, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('overtimeType: $overtimeType, ')
          ..write('workContent: $workContent, ')
          ..write('workLocation: $workLocation, ')
          ..write('registrant: $registrant, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $TerminationRecordsTable extends TerminationRecords
    with TableInfo<$TerminationRecordsTable, TerminationRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TerminationRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _terminationDateMeta = const VerificationMeta(
    'terminationDate',
  );
  @override
  late final GeneratedColumn<DateTime> terminationDate =
      GeneratedColumn<DateTime>(
        'termination_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _terminationTypeMeta = const VerificationMeta(
    'terminationType',
  );
  @override
  late final GeneratedColumn<String> terminationType = GeneratedColumn<String>(
    'termination_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('personal'),
  );
  static const VerificationMeta _isInsuranceStoppedMeta =
      const VerificationMeta('isInsuranceStopped');
  @override
  late final GeneratedColumn<bool> isInsuranceStopped = GeneratedColumn<bool>(
    'is_insurance_stopped',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_insurance_stopped" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _stopInsuranceMonthMeta =
      const VerificationMeta('stopInsuranceMonth');
  @override
  late final GeneratedColumn<String> stopInsuranceMonth =
      GeneratedColumn<String>(
        'stop_insurance_month',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _toolsReturnedMeta = const VerificationMeta(
    'toolsReturned',
  );
  @override
  late final GeneratedColumn<bool> toolsReturned = GeneratedColumn<bool>(
    'tools_returned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tools_returned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _materialsTransferredMeta =
      const VerificationMeta('materialsTransferred');
  @override
  late final GeneratedColumn<bool> materialsTransferred = GeneratedColumn<bool>(
    'materials_transferred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("materials_transferred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasUnsettledItemsMeta = const VerificationMeta(
    'hasUnsettledItems',
  );
  @override
  late final GeneratedColumn<bool> hasUnsettledItems = GeneratedColumn<bool>(
    'has_unsettled_items',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_unsettled_items" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    terminationDate,
    terminationType,
    isInsuranceStopped,
    stopInsuranceMonth,
    toolsReturned,
    materialsTransferred,
    hasUnsettledItems,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'termination_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<TerminationRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('termination_date')) {
      context.handle(
        _terminationDateMeta,
        terminationDate.isAcceptableOrUnknown(
          data['termination_date']!,
          _terminationDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_terminationDateMeta);
    }
    if (data.containsKey('termination_type')) {
      context.handle(
        _terminationTypeMeta,
        terminationType.isAcceptableOrUnknown(
          data['termination_type']!,
          _terminationTypeMeta,
        ),
      );
    }
    if (data.containsKey('is_insurance_stopped')) {
      context.handle(
        _isInsuranceStoppedMeta,
        isInsuranceStopped.isAcceptableOrUnknown(
          data['is_insurance_stopped']!,
          _isInsuranceStoppedMeta,
        ),
      );
    }
    if (data.containsKey('stop_insurance_month')) {
      context.handle(
        _stopInsuranceMonthMeta,
        stopInsuranceMonth.isAcceptableOrUnknown(
          data['stop_insurance_month']!,
          _stopInsuranceMonthMeta,
        ),
      );
    }
    if (data.containsKey('tools_returned')) {
      context.handle(
        _toolsReturnedMeta,
        toolsReturned.isAcceptableOrUnknown(
          data['tools_returned']!,
          _toolsReturnedMeta,
        ),
      );
    }
    if (data.containsKey('materials_transferred')) {
      context.handle(
        _materialsTransferredMeta,
        materialsTransferred.isAcceptableOrUnknown(
          data['materials_transferred']!,
          _materialsTransferredMeta,
        ),
      );
    }
    if (data.containsKey('has_unsettled_items')) {
      context.handle(
        _hasUnsettledItemsMeta,
        hasUnsettledItems.isAcceptableOrUnknown(
          data['has_unsettled_items']!,
          _hasUnsettledItemsMeta,
        ),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TerminationRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TerminationRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      terminationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}termination_date'],
      )!,
      terminationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}termination_type'],
      )!,
      isInsuranceStopped: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_insurance_stopped'],
      )!,
      stopInsuranceMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stop_insurance_month'],
      ),
      toolsReturned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tools_returned'],
      )!,
      materialsTransferred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}materials_transferred'],
      )!,
      hasUnsettledItems: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_unsettled_items'],
      )!,
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $TerminationRecordsTable createAlias(String alias) {
    return $TerminationRecordsTable(attachedDatabase, alias);
  }
}

class TerminationRecord extends DataClass
    implements Insertable<TerminationRecord> {
  final int id;
  final int employeeId;
  final DateTime terminationDate;
  final String terminationType;
  final bool isInsuranceStopped;
  final String? stopInsuranceMonth;
  final bool toolsReturned;
  final bool materialsTransferred;
  final bool hasUnsettledItems;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Revoking a termination is represented by a soft delete.
  final bool isDeleted;
  const TerminationRecord({
    required this.id,
    required this.employeeId,
    required this.terminationDate,
    required this.terminationType,
    required this.isInsuranceStopped,
    this.stopInsuranceMonth,
    required this.toolsReturned,
    required this.materialsTransferred,
    required this.hasUnsettledItems,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['termination_date'] = Variable<DateTime>(terminationDate);
    map['termination_type'] = Variable<String>(terminationType);
    map['is_insurance_stopped'] = Variable<bool>(isInsuranceStopped);
    if (!nullToAbsent || stopInsuranceMonth != null) {
      map['stop_insurance_month'] = Variable<String>(stopInsuranceMonth);
    }
    map['tools_returned'] = Variable<bool>(toolsReturned);
    map['materials_transferred'] = Variable<bool>(materialsTransferred);
    map['has_unsettled_items'] = Variable<bool>(hasUnsettledItems);
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  TerminationRecordsCompanion toCompanion(bool nullToAbsent) {
    return TerminationRecordsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      terminationDate: Value(terminationDate),
      terminationType: Value(terminationType),
      isInsuranceStopped: Value(isInsuranceStopped),
      stopInsuranceMonth: stopInsuranceMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(stopInsuranceMonth),
      toolsReturned: Value(toolsReturned),
      materialsTransferred: Value(materialsTransferred),
      hasUnsettledItems: Value(hasUnsettledItems),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory TerminationRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TerminationRecord(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      terminationDate: serializer.fromJson<DateTime>(json['terminationDate']),
      terminationType: serializer.fromJson<String>(json['terminationType']),
      isInsuranceStopped: serializer.fromJson<bool>(json['isInsuranceStopped']),
      stopInsuranceMonth: serializer.fromJson<String?>(
        json['stopInsuranceMonth'],
      ),
      toolsReturned: serializer.fromJson<bool>(json['toolsReturned']),
      materialsTransferred: serializer.fromJson<bool>(
        json['materialsTransferred'],
      ),
      hasUnsettledItems: serializer.fromJson<bool>(json['hasUnsettledItems']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'terminationDate': serializer.toJson<DateTime>(terminationDate),
      'terminationType': serializer.toJson<String>(terminationType),
      'isInsuranceStopped': serializer.toJson<bool>(isInsuranceStopped),
      'stopInsuranceMonth': serializer.toJson<String?>(stopInsuranceMonth),
      'toolsReturned': serializer.toJson<bool>(toolsReturned),
      'materialsTransferred': serializer.toJson<bool>(materialsTransferred),
      'hasUnsettledItems': serializer.toJson<bool>(hasUnsettledItems),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  TerminationRecord copyWith({
    int? id,
    int? employeeId,
    DateTime? terminationDate,
    String? terminationType,
    bool? isInsuranceStopped,
    Value<String?> stopInsuranceMonth = const Value.absent(),
    bool? toolsReturned,
    bool? materialsTransferred,
    bool? hasUnsettledItems,
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => TerminationRecord(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    terminationDate: terminationDate ?? this.terminationDate,
    terminationType: terminationType ?? this.terminationType,
    isInsuranceStopped: isInsuranceStopped ?? this.isInsuranceStopped,
    stopInsuranceMonth: stopInsuranceMonth.present
        ? stopInsuranceMonth.value
        : this.stopInsuranceMonth,
    toolsReturned: toolsReturned ?? this.toolsReturned,
    materialsTransferred: materialsTransferred ?? this.materialsTransferred,
    hasUnsettledItems: hasUnsettledItems ?? this.hasUnsettledItems,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  TerminationRecord copyWithCompanion(TerminationRecordsCompanion data) {
    return TerminationRecord(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      terminationDate: data.terminationDate.present
          ? data.terminationDate.value
          : this.terminationDate,
      terminationType: data.terminationType.present
          ? data.terminationType.value
          : this.terminationType,
      isInsuranceStopped: data.isInsuranceStopped.present
          ? data.isInsuranceStopped.value
          : this.isInsuranceStopped,
      stopInsuranceMonth: data.stopInsuranceMonth.present
          ? data.stopInsuranceMonth.value
          : this.stopInsuranceMonth,
      toolsReturned: data.toolsReturned.present
          ? data.toolsReturned.value
          : this.toolsReturned,
      materialsTransferred: data.materialsTransferred.present
          ? data.materialsTransferred.value
          : this.materialsTransferred,
      hasUnsettledItems: data.hasUnsettledItems.present
          ? data.hasUnsettledItems.value
          : this.hasUnsettledItems,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TerminationRecord(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('terminationDate: $terminationDate, ')
          ..write('terminationType: $terminationType, ')
          ..write('isInsuranceStopped: $isInsuranceStopped, ')
          ..write('stopInsuranceMonth: $stopInsuranceMonth, ')
          ..write('toolsReturned: $toolsReturned, ')
          ..write('materialsTransferred: $materialsTransferred, ')
          ..write('hasUnsettledItems: $hasUnsettledItems, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    terminationDate,
    terminationType,
    isInsuranceStopped,
    stopInsuranceMonth,
    toolsReturned,
    materialsTransferred,
    hasUnsettledItems,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TerminationRecord &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.terminationDate == this.terminationDate &&
          other.terminationType == this.terminationType &&
          other.isInsuranceStopped == this.isInsuranceStopped &&
          other.stopInsuranceMonth == this.stopInsuranceMonth &&
          other.toolsReturned == this.toolsReturned &&
          other.materialsTransferred == this.materialsTransferred &&
          other.hasUnsettledItems == this.hasUnsettledItems &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class TerminationRecordsCompanion extends UpdateCompanion<TerminationRecord> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<DateTime> terminationDate;
  final Value<String> terminationType;
  final Value<bool> isInsuranceStopped;
  final Value<String?> stopInsuranceMonth;
  final Value<bool> toolsReturned;
  final Value<bool> materialsTransferred;
  final Value<bool> hasUnsettledItems;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const TerminationRecordsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.terminationDate = const Value.absent(),
    this.terminationType = const Value.absent(),
    this.isInsuranceStopped = const Value.absent(),
    this.stopInsuranceMonth = const Value.absent(),
    this.toolsReturned = const Value.absent(),
    this.materialsTransferred = const Value.absent(),
    this.hasUnsettledItems = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  TerminationRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required DateTime terminationDate,
    this.terminationType = const Value.absent(),
    this.isInsuranceStopped = const Value.absent(),
    this.stopInsuranceMonth = const Value.absent(),
    this.toolsReturned = const Value.absent(),
    this.materialsTransferred = const Value.absent(),
    this.hasUnsettledItems = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : employeeId = Value(employeeId),
       terminationDate = Value(terminationDate);
  static Insertable<TerminationRecord> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<DateTime>? terminationDate,
    Expression<String>? terminationType,
    Expression<bool>? isInsuranceStopped,
    Expression<String>? stopInsuranceMonth,
    Expression<bool>? toolsReturned,
    Expression<bool>? materialsTransferred,
    Expression<bool>? hasUnsettledItems,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (terminationDate != null) 'termination_date': terminationDate,
      if (terminationType != null) 'termination_type': terminationType,
      if (isInsuranceStopped != null)
        'is_insurance_stopped': isInsuranceStopped,
      if (stopInsuranceMonth != null)
        'stop_insurance_month': stopInsuranceMonth,
      if (toolsReturned != null) 'tools_returned': toolsReturned,
      if (materialsTransferred != null)
        'materials_transferred': materialsTransferred,
      if (hasUnsettledItems != null) 'has_unsettled_items': hasUnsettledItems,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  TerminationRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<DateTime>? terminationDate,
    Value<String>? terminationType,
    Value<bool>? isInsuranceStopped,
    Value<String?>? stopInsuranceMonth,
    Value<bool>? toolsReturned,
    Value<bool>? materialsTransferred,
    Value<bool>? hasUnsettledItems,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return TerminationRecordsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      terminationDate: terminationDate ?? this.terminationDate,
      terminationType: terminationType ?? this.terminationType,
      isInsuranceStopped: isInsuranceStopped ?? this.isInsuranceStopped,
      stopInsuranceMonth: stopInsuranceMonth ?? this.stopInsuranceMonth,
      toolsReturned: toolsReturned ?? this.toolsReturned,
      materialsTransferred: materialsTransferred ?? this.materialsTransferred,
      hasUnsettledItems: hasUnsettledItems ?? this.hasUnsettledItems,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (terminationDate.present) {
      map['termination_date'] = Variable<DateTime>(terminationDate.value);
    }
    if (terminationType.present) {
      map['termination_type'] = Variable<String>(terminationType.value);
    }
    if (isInsuranceStopped.present) {
      map['is_insurance_stopped'] = Variable<bool>(isInsuranceStopped.value);
    }
    if (stopInsuranceMonth.present) {
      map['stop_insurance_month'] = Variable<String>(stopInsuranceMonth.value);
    }
    if (toolsReturned.present) {
      map['tools_returned'] = Variable<bool>(toolsReturned.value);
    }
    if (materialsTransferred.present) {
      map['materials_transferred'] = Variable<bool>(materialsTransferred.value);
    }
    if (hasUnsettledItems.present) {
      map['has_unsettled_items'] = Variable<bool>(hasUnsettledItems.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TerminationRecordsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('terminationDate: $terminationDate, ')
          ..write('terminationType: $terminationType, ')
          ..write('isInsuranceStopped: $isInsuranceStopped, ')
          ..write('stopInsuranceMonth: $stopInsuranceMonth, ')
          ..write('toolsReturned: $toolsReturned, ')
          ..write('materialsTransferred: $materialsTransferred, ')
          ..write('hasUnsettledItems: $hasUnsettledItems, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $MonthlyAttendanceSummariesTable extends MonthlyAttendanceSummaries
    with TableInfo<$MonthlyAttendanceSummariesTable, MonthlyAttendanceSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MonthlyAttendanceSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _yearMonthMeta = const VerificationMeta(
    'yearMonth',
  );
  @override
  late final GeneratedColumn<String> yearMonth = GeneratedColumn<String>(
    'year_month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _attendanceGroupIdMeta = const VerificationMeta(
    'attendanceGroupId',
  );
  @override
  late final GeneratedColumn<int> attendanceGroupId = GeneratedColumn<int>(
    'attendance_group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES attendance_groups (id)',
    ),
  );
  static const VerificationMeta _participatesMeta = const VerificationMeta(
    'participates',
  );
  @override
  late final GeneratedColumn<bool> participates = GeneratedColumn<bool>(
    'participates',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("participates" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _attendanceDaysMeta = const VerificationMeta(
    'attendanceDays',
  );
  @override
  late final GeneratedColumn<double> attendanceDays = GeneratedColumn<double>(
    'attendance_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _leaveDaysMeta = const VerificationMeta(
    'leaveDays',
  );
  @override
  late final GeneratedColumn<double> leaveDays = GeneratedColumn<double>(
    'leave_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _absentDaysMeta = const VerificationMeta(
    'absentDays',
  );
  @override
  late final GeneratedColumn<double> absentDays = GeneratedColumn<double>(
    'absent_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _restDaysMeta = const VerificationMeta(
    'restDays',
  );
  @override
  late final GeneratedColumn<double> restDays = GeneratedColumn<double>(
    'rest_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _stoppedDaysMeta = const VerificationMeta(
    'stoppedDays',
  );
  @override
  late final GeneratedColumn<double> stoppedDays = GeneratedColumn<double>(
    'stopped_days',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _overtimeCountMeta = const VerificationMeta(
    'overtimeCount',
  );
  @override
  late final GeneratedColumn<int> overtimeCount = GeneratedColumn<int>(
    'overtime_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _overtimeMinutesMeta = const VerificationMeta(
    'overtimeMinutes',
  );
  @override
  late final GeneratedColumn<int> overtimeMinutes = GeneratedColumn<int>(
    'overtime_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _monthStartStatusMeta = const VerificationMeta(
    'monthStartStatus',
  );
  @override
  late final GeneratedColumn<String> monthStartStatus = GeneratedColumn<String>(
    'month_start_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _monthEndStatusMeta = const VerificationMeta(
    'monthEndStatus',
  );
  @override
  late final GeneratedColumn<String> monthEndStatus = GeneratedColumn<String>(
    'month_end_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _joinedDuringMonthMeta = const VerificationMeta(
    'joinedDuringMonth',
  );
  @override
  late final GeneratedColumn<bool> joinedDuringMonth = GeneratedColumn<bool>(
    'joined_during_month',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("joined_during_month" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _terminatedDuringMonthMeta =
      const VerificationMeta('terminatedDuringMonth');
  @override
  late final GeneratedColumn<bool> terminatedDuringMonth =
      GeneratedColumn<bool>(
        'terminated_during_month',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("terminated_during_month" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _isCompleteMeta = const VerificationMeta(
    'isComplete',
  );
  @override
  late final GeneratedColumn<bool> isComplete = GeneratedColumn<bool>(
    'is_complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_complete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _anomalyCountMeta = const VerificationMeta(
    'anomalyCount',
  );
  @override
  late final GeneratedColumn<int> anomalyCount = GeneratedColumn<int>(
    'anomaly_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MonthlySummaryStatus, String>
  status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('notGenerated'),
      ).withConverter<MonthlySummaryStatus>(
        $MonthlyAttendanceSummariesTable.$converterstatus,
      );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> generatedAt = GeneratedColumn<DateTime>(
    'generated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    yearMonth,
    employeeId,
    attendanceGroupId,
    participates,
    attendanceDays,
    leaveDays,
    absentDays,
    restDays,
    stoppedDays,
    overtimeCount,
    overtimeMinutes,
    monthStartStatus,
    monthEndStatus,
    joinedDuringMonth,
    terminatedDuringMonth,
    isComplete,
    anomalyCount,
    status,
    generatedAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'monthly_attendance_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MonthlyAttendanceSummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('year_month')) {
      context.handle(
        _yearMonthMeta,
        yearMonth.isAcceptableOrUnknown(data['year_month']!, _yearMonthMeta),
      );
    } else if (isInserting) {
      context.missing(_yearMonthMeta);
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('attendance_group_id')) {
      context.handle(
        _attendanceGroupIdMeta,
        attendanceGroupId.isAcceptableOrUnknown(
          data['attendance_group_id']!,
          _attendanceGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('participates')) {
      context.handle(
        _participatesMeta,
        participates.isAcceptableOrUnknown(
          data['participates']!,
          _participatesMeta,
        ),
      );
    }
    if (data.containsKey('attendance_days')) {
      context.handle(
        _attendanceDaysMeta,
        attendanceDays.isAcceptableOrUnknown(
          data['attendance_days']!,
          _attendanceDaysMeta,
        ),
      );
    }
    if (data.containsKey('leave_days')) {
      context.handle(
        _leaveDaysMeta,
        leaveDays.isAcceptableOrUnknown(data['leave_days']!, _leaveDaysMeta),
      );
    }
    if (data.containsKey('absent_days')) {
      context.handle(
        _absentDaysMeta,
        absentDays.isAcceptableOrUnknown(data['absent_days']!, _absentDaysMeta),
      );
    }
    if (data.containsKey('rest_days')) {
      context.handle(
        _restDaysMeta,
        restDays.isAcceptableOrUnknown(data['rest_days']!, _restDaysMeta),
      );
    }
    if (data.containsKey('stopped_days')) {
      context.handle(
        _stoppedDaysMeta,
        stoppedDays.isAcceptableOrUnknown(
          data['stopped_days']!,
          _stoppedDaysMeta,
        ),
      );
    }
    if (data.containsKey('overtime_count')) {
      context.handle(
        _overtimeCountMeta,
        overtimeCount.isAcceptableOrUnknown(
          data['overtime_count']!,
          _overtimeCountMeta,
        ),
      );
    }
    if (data.containsKey('overtime_minutes')) {
      context.handle(
        _overtimeMinutesMeta,
        overtimeMinutes.isAcceptableOrUnknown(
          data['overtime_minutes']!,
          _overtimeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('month_start_status')) {
      context.handle(
        _monthStartStatusMeta,
        monthStartStatus.isAcceptableOrUnknown(
          data['month_start_status']!,
          _monthStartStatusMeta,
        ),
      );
    }
    if (data.containsKey('month_end_status')) {
      context.handle(
        _monthEndStatusMeta,
        monthEndStatus.isAcceptableOrUnknown(
          data['month_end_status']!,
          _monthEndStatusMeta,
        ),
      );
    }
    if (data.containsKey('joined_during_month')) {
      context.handle(
        _joinedDuringMonthMeta,
        joinedDuringMonth.isAcceptableOrUnknown(
          data['joined_during_month']!,
          _joinedDuringMonthMeta,
        ),
      );
    }
    if (data.containsKey('terminated_during_month')) {
      context.handle(
        _terminatedDuringMonthMeta,
        terminatedDuringMonth.isAcceptableOrUnknown(
          data['terminated_during_month']!,
          _terminatedDuringMonthMeta,
        ),
      );
    }
    if (data.containsKey('is_complete')) {
      context.handle(
        _isCompleteMeta,
        isComplete.isAcceptableOrUnknown(data['is_complete']!, _isCompleteMeta),
      );
    }
    if (data.containsKey('anomaly_count')) {
      context.handle(
        _anomalyCountMeta,
        anomalyCount.isAcceptableOrUnknown(
          data['anomaly_count']!,
          _anomalyCountMeta,
        ),
      );
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {yearMonth, employeeId, attendanceGroupId},
  ];
  @override
  MonthlyAttendanceSummary map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MonthlyAttendanceSummary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      yearMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}year_month'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      attendanceGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attendance_group_id'],
      ),
      participates: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}participates'],
      )!,
      attendanceDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}attendance_days'],
      )!,
      leaveDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}leave_days'],
      )!,
      absentDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}absent_days'],
      )!,
      restDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rest_days'],
      )!,
      stoppedDays: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stopped_days'],
      )!,
      overtimeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_count'],
      )!,
      overtimeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overtime_minutes'],
      )!,
      monthStartStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_start_status'],
      ),
      monthEndStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_end_status'],
      ),
      joinedDuringMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}joined_during_month'],
      )!,
      terminatedDuringMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}terminated_during_month'],
      )!,
      isComplete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_complete'],
      )!,
      anomalyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anomaly_count'],
      )!,
      status: $MonthlyAttendanceSummariesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}generated_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $MonthlyAttendanceSummariesTable createAlias(String alias) {
    return $MonthlyAttendanceSummariesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<MonthlySummaryStatus, String, String>
  $converterstatus = const EnumNameConverter<MonthlySummaryStatus>(
    MonthlySummaryStatus.values,
  );
}

class MonthlyAttendanceSummary extends DataClass
    implements Insertable<MonthlyAttendanceSummary> {
  final int id;
  final String yearMonth;
  final int employeeId;
  final int? attendanceGroupId;
  final bool participates;
  final double attendanceDays;
  final double leaveDays;
  final double absentDays;
  final double restDays;
  final double stoppedDays;
  final int overtimeCount;
  final int overtimeMinutes;
  final String? monthStartStatus;
  final String? monthEndStatus;
  final bool joinedDuringMonth;
  final bool terminatedDuringMonth;
  final bool isComplete;
  final int anomalyCount;
  final MonthlySummaryStatus status;
  final DateTime? generatedAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const MonthlyAttendanceSummary({
    required this.id,
    required this.yearMonth,
    required this.employeeId,
    this.attendanceGroupId,
    required this.participates,
    required this.attendanceDays,
    required this.leaveDays,
    required this.absentDays,
    required this.restDays,
    required this.stoppedDays,
    required this.overtimeCount,
    required this.overtimeMinutes,
    this.monthStartStatus,
    this.monthEndStatus,
    required this.joinedDuringMonth,
    required this.terminatedDuringMonth,
    required this.isComplete,
    required this.anomalyCount,
    required this.status,
    this.generatedAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['year_month'] = Variable<String>(yearMonth);
    map['employee_id'] = Variable<int>(employeeId);
    if (!nullToAbsent || attendanceGroupId != null) {
      map['attendance_group_id'] = Variable<int>(attendanceGroupId);
    }
    map['participates'] = Variable<bool>(participates);
    map['attendance_days'] = Variable<double>(attendanceDays);
    map['leave_days'] = Variable<double>(leaveDays);
    map['absent_days'] = Variable<double>(absentDays);
    map['rest_days'] = Variable<double>(restDays);
    map['stopped_days'] = Variable<double>(stoppedDays);
    map['overtime_count'] = Variable<int>(overtimeCount);
    map['overtime_minutes'] = Variable<int>(overtimeMinutes);
    if (!nullToAbsent || monthStartStatus != null) {
      map['month_start_status'] = Variable<String>(monthStartStatus);
    }
    if (!nullToAbsent || monthEndStatus != null) {
      map['month_end_status'] = Variable<String>(monthEndStatus);
    }
    map['joined_during_month'] = Variable<bool>(joinedDuringMonth);
    map['terminated_during_month'] = Variable<bool>(terminatedDuringMonth);
    map['is_complete'] = Variable<bool>(isComplete);
    map['anomaly_count'] = Variable<int>(anomalyCount);
    {
      map['status'] = Variable<String>(
        $MonthlyAttendanceSummariesTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || generatedAt != null) {
      map['generated_at'] = Variable<DateTime>(generatedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  MonthlyAttendanceSummariesCompanion toCompanion(bool nullToAbsent) {
    return MonthlyAttendanceSummariesCompanion(
      id: Value(id),
      yearMonth: Value(yearMonth),
      employeeId: Value(employeeId),
      attendanceGroupId: attendanceGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(attendanceGroupId),
      participates: Value(participates),
      attendanceDays: Value(attendanceDays),
      leaveDays: Value(leaveDays),
      absentDays: Value(absentDays),
      restDays: Value(restDays),
      stoppedDays: Value(stoppedDays),
      overtimeCount: Value(overtimeCount),
      overtimeMinutes: Value(overtimeMinutes),
      monthStartStatus: monthStartStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(monthStartStatus),
      monthEndStatus: monthEndStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(monthEndStatus),
      joinedDuringMonth: Value(joinedDuringMonth),
      terminatedDuringMonth: Value(terminatedDuringMonth),
      isComplete: Value(isComplete),
      anomalyCount: Value(anomalyCount),
      status: Value(status),
      generatedAt: generatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(generatedAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory MonthlyAttendanceSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MonthlyAttendanceSummary(
      id: serializer.fromJson<int>(json['id']),
      yearMonth: serializer.fromJson<String>(json['yearMonth']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      attendanceGroupId: serializer.fromJson<int?>(json['attendanceGroupId']),
      participates: serializer.fromJson<bool>(json['participates']),
      attendanceDays: serializer.fromJson<double>(json['attendanceDays']),
      leaveDays: serializer.fromJson<double>(json['leaveDays']),
      absentDays: serializer.fromJson<double>(json['absentDays']),
      restDays: serializer.fromJson<double>(json['restDays']),
      stoppedDays: serializer.fromJson<double>(json['stoppedDays']),
      overtimeCount: serializer.fromJson<int>(json['overtimeCount']),
      overtimeMinutes: serializer.fromJson<int>(json['overtimeMinutes']),
      monthStartStatus: serializer.fromJson<String?>(json['monthStartStatus']),
      monthEndStatus: serializer.fromJson<String?>(json['monthEndStatus']),
      joinedDuringMonth: serializer.fromJson<bool>(json['joinedDuringMonth']),
      terminatedDuringMonth: serializer.fromJson<bool>(
        json['terminatedDuringMonth'],
      ),
      isComplete: serializer.fromJson<bool>(json['isComplete']),
      anomalyCount: serializer.fromJson<int>(json['anomalyCount']),
      status: $MonthlyAttendanceSummariesTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      generatedAt: serializer.fromJson<DateTime?>(json['generatedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'yearMonth': serializer.toJson<String>(yearMonth),
      'employeeId': serializer.toJson<int>(employeeId),
      'attendanceGroupId': serializer.toJson<int?>(attendanceGroupId),
      'participates': serializer.toJson<bool>(participates),
      'attendanceDays': serializer.toJson<double>(attendanceDays),
      'leaveDays': serializer.toJson<double>(leaveDays),
      'absentDays': serializer.toJson<double>(absentDays),
      'restDays': serializer.toJson<double>(restDays),
      'stoppedDays': serializer.toJson<double>(stoppedDays),
      'overtimeCount': serializer.toJson<int>(overtimeCount),
      'overtimeMinutes': serializer.toJson<int>(overtimeMinutes),
      'monthStartStatus': serializer.toJson<String?>(monthStartStatus),
      'monthEndStatus': serializer.toJson<String?>(monthEndStatus),
      'joinedDuringMonth': serializer.toJson<bool>(joinedDuringMonth),
      'terminatedDuringMonth': serializer.toJson<bool>(terminatedDuringMonth),
      'isComplete': serializer.toJson<bool>(isComplete),
      'anomalyCount': serializer.toJson<int>(anomalyCount),
      'status': serializer.toJson<String>(
        $MonthlyAttendanceSummariesTable.$converterstatus.toJson(status),
      ),
      'generatedAt': serializer.toJson<DateTime?>(generatedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  MonthlyAttendanceSummary copyWith({
    int? id,
    String? yearMonth,
    int? employeeId,
    Value<int?> attendanceGroupId = const Value.absent(),
    bool? participates,
    double? attendanceDays,
    double? leaveDays,
    double? absentDays,
    double? restDays,
    double? stoppedDays,
    int? overtimeCount,
    int? overtimeMinutes,
    Value<String?> monthStartStatus = const Value.absent(),
    Value<String?> monthEndStatus = const Value.absent(),
    bool? joinedDuringMonth,
    bool? terminatedDuringMonth,
    bool? isComplete,
    int? anomalyCount,
    MonthlySummaryStatus? status,
    Value<DateTime?> generatedAt = const Value.absent(),
    DateTime? updatedAt,
    bool? isDeleted,
  }) => MonthlyAttendanceSummary(
    id: id ?? this.id,
    yearMonth: yearMonth ?? this.yearMonth,
    employeeId: employeeId ?? this.employeeId,
    attendanceGroupId: attendanceGroupId.present
        ? attendanceGroupId.value
        : this.attendanceGroupId,
    participates: participates ?? this.participates,
    attendanceDays: attendanceDays ?? this.attendanceDays,
    leaveDays: leaveDays ?? this.leaveDays,
    absentDays: absentDays ?? this.absentDays,
    restDays: restDays ?? this.restDays,
    stoppedDays: stoppedDays ?? this.stoppedDays,
    overtimeCount: overtimeCount ?? this.overtimeCount,
    overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
    monthStartStatus: monthStartStatus.present
        ? monthStartStatus.value
        : this.monthStartStatus,
    monthEndStatus: monthEndStatus.present
        ? monthEndStatus.value
        : this.monthEndStatus,
    joinedDuringMonth: joinedDuringMonth ?? this.joinedDuringMonth,
    terminatedDuringMonth: terminatedDuringMonth ?? this.terminatedDuringMonth,
    isComplete: isComplete ?? this.isComplete,
    anomalyCount: anomalyCount ?? this.anomalyCount,
    status: status ?? this.status,
    generatedAt: generatedAt.present ? generatedAt.value : this.generatedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  MonthlyAttendanceSummary copyWithCompanion(
    MonthlyAttendanceSummariesCompanion data,
  ) {
    return MonthlyAttendanceSummary(
      id: data.id.present ? data.id.value : this.id,
      yearMonth: data.yearMonth.present ? data.yearMonth.value : this.yearMonth,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      attendanceGroupId: data.attendanceGroupId.present
          ? data.attendanceGroupId.value
          : this.attendanceGroupId,
      participates: data.participates.present
          ? data.participates.value
          : this.participates,
      attendanceDays: data.attendanceDays.present
          ? data.attendanceDays.value
          : this.attendanceDays,
      leaveDays: data.leaveDays.present ? data.leaveDays.value : this.leaveDays,
      absentDays: data.absentDays.present
          ? data.absentDays.value
          : this.absentDays,
      restDays: data.restDays.present ? data.restDays.value : this.restDays,
      stoppedDays: data.stoppedDays.present
          ? data.stoppedDays.value
          : this.stoppedDays,
      overtimeCount: data.overtimeCount.present
          ? data.overtimeCount.value
          : this.overtimeCount,
      overtimeMinutes: data.overtimeMinutes.present
          ? data.overtimeMinutes.value
          : this.overtimeMinutes,
      monthStartStatus: data.monthStartStatus.present
          ? data.monthStartStatus.value
          : this.monthStartStatus,
      monthEndStatus: data.monthEndStatus.present
          ? data.monthEndStatus.value
          : this.monthEndStatus,
      joinedDuringMonth: data.joinedDuringMonth.present
          ? data.joinedDuringMonth.value
          : this.joinedDuringMonth,
      terminatedDuringMonth: data.terminatedDuringMonth.present
          ? data.terminatedDuringMonth.value
          : this.terminatedDuringMonth,
      isComplete: data.isComplete.present
          ? data.isComplete.value
          : this.isComplete,
      anomalyCount: data.anomalyCount.present
          ? data.anomalyCount.value
          : this.anomalyCount,
      status: data.status.present ? data.status.value : this.status,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MonthlyAttendanceSummary(')
          ..write('id: $id, ')
          ..write('yearMonth: $yearMonth, ')
          ..write('employeeId: $employeeId, ')
          ..write('attendanceGroupId: $attendanceGroupId, ')
          ..write('participates: $participates, ')
          ..write('attendanceDays: $attendanceDays, ')
          ..write('leaveDays: $leaveDays, ')
          ..write('absentDays: $absentDays, ')
          ..write('restDays: $restDays, ')
          ..write('stoppedDays: $stoppedDays, ')
          ..write('overtimeCount: $overtimeCount, ')
          ..write('overtimeMinutes: $overtimeMinutes, ')
          ..write('monthStartStatus: $monthStartStatus, ')
          ..write('monthEndStatus: $monthEndStatus, ')
          ..write('joinedDuringMonth: $joinedDuringMonth, ')
          ..write('terminatedDuringMonth: $terminatedDuringMonth, ')
          ..write('isComplete: $isComplete, ')
          ..write('anomalyCount: $anomalyCount, ')
          ..write('status: $status, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    yearMonth,
    employeeId,
    attendanceGroupId,
    participates,
    attendanceDays,
    leaveDays,
    absentDays,
    restDays,
    stoppedDays,
    overtimeCount,
    overtimeMinutes,
    monthStartStatus,
    monthEndStatus,
    joinedDuringMonth,
    terminatedDuringMonth,
    isComplete,
    anomalyCount,
    status,
    generatedAt,
    updatedAt,
    isDeleted,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MonthlyAttendanceSummary &&
          other.id == this.id &&
          other.yearMonth == this.yearMonth &&
          other.employeeId == this.employeeId &&
          other.attendanceGroupId == this.attendanceGroupId &&
          other.participates == this.participates &&
          other.attendanceDays == this.attendanceDays &&
          other.leaveDays == this.leaveDays &&
          other.absentDays == this.absentDays &&
          other.restDays == this.restDays &&
          other.stoppedDays == this.stoppedDays &&
          other.overtimeCount == this.overtimeCount &&
          other.overtimeMinutes == this.overtimeMinutes &&
          other.monthStartStatus == this.monthStartStatus &&
          other.monthEndStatus == this.monthEndStatus &&
          other.joinedDuringMonth == this.joinedDuringMonth &&
          other.terminatedDuringMonth == this.terminatedDuringMonth &&
          other.isComplete == this.isComplete &&
          other.anomalyCount == this.anomalyCount &&
          other.status == this.status &&
          other.generatedAt == this.generatedAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class MonthlyAttendanceSummariesCompanion
    extends UpdateCompanion<MonthlyAttendanceSummary> {
  final Value<int> id;
  final Value<String> yearMonth;
  final Value<int> employeeId;
  final Value<int?> attendanceGroupId;
  final Value<bool> participates;
  final Value<double> attendanceDays;
  final Value<double> leaveDays;
  final Value<double> absentDays;
  final Value<double> restDays;
  final Value<double> stoppedDays;
  final Value<int> overtimeCount;
  final Value<int> overtimeMinutes;
  final Value<String?> monthStartStatus;
  final Value<String?> monthEndStatus;
  final Value<bool> joinedDuringMonth;
  final Value<bool> terminatedDuringMonth;
  final Value<bool> isComplete;
  final Value<int> anomalyCount;
  final Value<MonthlySummaryStatus> status;
  final Value<DateTime?> generatedAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const MonthlyAttendanceSummariesCompanion({
    this.id = const Value.absent(),
    this.yearMonth = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.attendanceGroupId = const Value.absent(),
    this.participates = const Value.absent(),
    this.attendanceDays = const Value.absent(),
    this.leaveDays = const Value.absent(),
    this.absentDays = const Value.absent(),
    this.restDays = const Value.absent(),
    this.stoppedDays = const Value.absent(),
    this.overtimeCount = const Value.absent(),
    this.overtimeMinutes = const Value.absent(),
    this.monthStartStatus = const Value.absent(),
    this.monthEndStatus = const Value.absent(),
    this.joinedDuringMonth = const Value.absent(),
    this.terminatedDuringMonth = const Value.absent(),
    this.isComplete = const Value.absent(),
    this.anomalyCount = const Value.absent(),
    this.status = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  MonthlyAttendanceSummariesCompanion.insert({
    this.id = const Value.absent(),
    required String yearMonth,
    required int employeeId,
    this.attendanceGroupId = const Value.absent(),
    this.participates = const Value.absent(),
    this.attendanceDays = const Value.absent(),
    this.leaveDays = const Value.absent(),
    this.absentDays = const Value.absent(),
    this.restDays = const Value.absent(),
    this.stoppedDays = const Value.absent(),
    this.overtimeCount = const Value.absent(),
    this.overtimeMinutes = const Value.absent(),
    this.monthStartStatus = const Value.absent(),
    this.monthEndStatus = const Value.absent(),
    this.joinedDuringMonth = const Value.absent(),
    this.terminatedDuringMonth = const Value.absent(),
    this.isComplete = const Value.absent(),
    this.anomalyCount = const Value.absent(),
    this.status = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : yearMonth = Value(yearMonth),
       employeeId = Value(employeeId);
  static Insertable<MonthlyAttendanceSummary> custom({
    Expression<int>? id,
    Expression<String>? yearMonth,
    Expression<int>? employeeId,
    Expression<int>? attendanceGroupId,
    Expression<bool>? participates,
    Expression<double>? attendanceDays,
    Expression<double>? leaveDays,
    Expression<double>? absentDays,
    Expression<double>? restDays,
    Expression<double>? stoppedDays,
    Expression<int>? overtimeCount,
    Expression<int>? overtimeMinutes,
    Expression<String>? monthStartStatus,
    Expression<String>? monthEndStatus,
    Expression<bool>? joinedDuringMonth,
    Expression<bool>? terminatedDuringMonth,
    Expression<bool>? isComplete,
    Expression<int>? anomalyCount,
    Expression<String>? status,
    Expression<DateTime>? generatedAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (yearMonth != null) 'year_month': yearMonth,
      if (employeeId != null) 'employee_id': employeeId,
      if (attendanceGroupId != null) 'attendance_group_id': attendanceGroupId,
      if (participates != null) 'participates': participates,
      if (attendanceDays != null) 'attendance_days': attendanceDays,
      if (leaveDays != null) 'leave_days': leaveDays,
      if (absentDays != null) 'absent_days': absentDays,
      if (restDays != null) 'rest_days': restDays,
      if (stoppedDays != null) 'stopped_days': stoppedDays,
      if (overtimeCount != null) 'overtime_count': overtimeCount,
      if (overtimeMinutes != null) 'overtime_minutes': overtimeMinutes,
      if (monthStartStatus != null) 'month_start_status': monthStartStatus,
      if (monthEndStatus != null) 'month_end_status': monthEndStatus,
      if (joinedDuringMonth != null) 'joined_during_month': joinedDuringMonth,
      if (terminatedDuringMonth != null)
        'terminated_during_month': terminatedDuringMonth,
      if (isComplete != null) 'is_complete': isComplete,
      if (anomalyCount != null) 'anomaly_count': anomalyCount,
      if (status != null) 'status': status,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  MonthlyAttendanceSummariesCompanion copyWith({
    Value<int>? id,
    Value<String>? yearMonth,
    Value<int>? employeeId,
    Value<int?>? attendanceGroupId,
    Value<bool>? participates,
    Value<double>? attendanceDays,
    Value<double>? leaveDays,
    Value<double>? absentDays,
    Value<double>? restDays,
    Value<double>? stoppedDays,
    Value<int>? overtimeCount,
    Value<int>? overtimeMinutes,
    Value<String?>? monthStartStatus,
    Value<String?>? monthEndStatus,
    Value<bool>? joinedDuringMonth,
    Value<bool>? terminatedDuringMonth,
    Value<bool>? isComplete,
    Value<int>? anomalyCount,
    Value<MonthlySummaryStatus>? status,
    Value<DateTime?>? generatedAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return MonthlyAttendanceSummariesCompanion(
      id: id ?? this.id,
      yearMonth: yearMonth ?? this.yearMonth,
      employeeId: employeeId ?? this.employeeId,
      attendanceGroupId: attendanceGroupId ?? this.attendanceGroupId,
      participates: participates ?? this.participates,
      attendanceDays: attendanceDays ?? this.attendanceDays,
      leaveDays: leaveDays ?? this.leaveDays,
      absentDays: absentDays ?? this.absentDays,
      restDays: restDays ?? this.restDays,
      stoppedDays: stoppedDays ?? this.stoppedDays,
      overtimeCount: overtimeCount ?? this.overtimeCount,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      monthStartStatus: monthStartStatus ?? this.monthStartStatus,
      monthEndStatus: monthEndStatus ?? this.monthEndStatus,
      joinedDuringMonth: joinedDuringMonth ?? this.joinedDuringMonth,
      terminatedDuringMonth:
          terminatedDuringMonth ?? this.terminatedDuringMonth,
      isComplete: isComplete ?? this.isComplete,
      anomalyCount: anomalyCount ?? this.anomalyCount,
      status: status ?? this.status,
      generatedAt: generatedAt ?? this.generatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (yearMonth.present) {
      map['year_month'] = Variable<String>(yearMonth.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (attendanceGroupId.present) {
      map['attendance_group_id'] = Variable<int>(attendanceGroupId.value);
    }
    if (participates.present) {
      map['participates'] = Variable<bool>(participates.value);
    }
    if (attendanceDays.present) {
      map['attendance_days'] = Variable<double>(attendanceDays.value);
    }
    if (leaveDays.present) {
      map['leave_days'] = Variable<double>(leaveDays.value);
    }
    if (absentDays.present) {
      map['absent_days'] = Variable<double>(absentDays.value);
    }
    if (restDays.present) {
      map['rest_days'] = Variable<double>(restDays.value);
    }
    if (stoppedDays.present) {
      map['stopped_days'] = Variable<double>(stoppedDays.value);
    }
    if (overtimeCount.present) {
      map['overtime_count'] = Variable<int>(overtimeCount.value);
    }
    if (overtimeMinutes.present) {
      map['overtime_minutes'] = Variable<int>(overtimeMinutes.value);
    }
    if (monthStartStatus.present) {
      map['month_start_status'] = Variable<String>(monthStartStatus.value);
    }
    if (monthEndStatus.present) {
      map['month_end_status'] = Variable<String>(monthEndStatus.value);
    }
    if (joinedDuringMonth.present) {
      map['joined_during_month'] = Variable<bool>(joinedDuringMonth.value);
    }
    if (terminatedDuringMonth.present) {
      map['terminated_during_month'] = Variable<bool>(
        terminatedDuringMonth.value,
      );
    }
    if (isComplete.present) {
      map['is_complete'] = Variable<bool>(isComplete.value);
    }
    if (anomalyCount.present) {
      map['anomaly_count'] = Variable<int>(anomalyCount.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MonthlyAttendanceSummariesTable.$converterstatus.toSql(status.value),
      );
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<DateTime>(generatedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MonthlyAttendanceSummariesCompanion(')
          ..write('id: $id, ')
          ..write('yearMonth: $yearMonth, ')
          ..write('employeeId: $employeeId, ')
          ..write('attendanceGroupId: $attendanceGroupId, ')
          ..write('participates: $participates, ')
          ..write('attendanceDays: $attendanceDays, ')
          ..write('leaveDays: $leaveDays, ')
          ..write('absentDays: $absentDays, ')
          ..write('restDays: $restDays, ')
          ..write('stoppedDays: $stoppedDays, ')
          ..write('overtimeCount: $overtimeCount, ')
          ..write('overtimeMinutes: $overtimeMinutes, ')
          ..write('monthStartStatus: $monthStartStatus, ')
          ..write('monthEndStatus: $monthEndStatus, ')
          ..write('joinedDuringMonth: $joinedDuringMonth, ')
          ..write('terminatedDuringMonth: $terminatedDuringMonth, ')
          ..write('isComplete: $isComplete, ')
          ..write('anomalyCount: $anomalyCount, ')
          ..write('status: $status, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $InsuranceProfilesTable extends InsuranceProfiles
    with TableInfo<$InsuranceProfilesTable, InsuranceProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InsuranceProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _isInsuredMeta = const VerificationMeta(
    'isInsured',
  );
  @override
  late final GeneratedColumn<bool> isInsured = GeneratedColumn<bool>(
    'is_insured',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_insured" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _insuranceTypeMeta = const VerificationMeta(
    'insuranceType',
  );
  @override
  late final GeneratedColumn<String> insuranceType = GeneratedColumn<String>(
    'insurance_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contributionBaseMeta = const VerificationMeta(
    'contributionBase',
  );
  @override
  late final GeneratedColumn<double> contributionBase = GeneratedColumn<double>(
    'contribution_base',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effectiveMonthMeta = const VerificationMeta(
    'effectiveMonth',
  );
  @override
  late final GeneratedColumn<String> effectiveMonth = GeneratedColumn<String>(
    'effective_month',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    isInsured,
    insuranceType,
    contributionBase,
    effectiveMonth,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'insurance_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<InsuranceProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('is_insured')) {
      context.handle(
        _isInsuredMeta,
        isInsured.isAcceptableOrUnknown(data['is_insured']!, _isInsuredMeta),
      );
    }
    if (data.containsKey('insurance_type')) {
      context.handle(
        _insuranceTypeMeta,
        insuranceType.isAcceptableOrUnknown(
          data['insurance_type']!,
          _insuranceTypeMeta,
        ),
      );
    }
    if (data.containsKey('contribution_base')) {
      context.handle(
        _contributionBaseMeta,
        contributionBase.isAcceptableOrUnknown(
          data['contribution_base']!,
          _contributionBaseMeta,
        ),
      );
    }
    if (data.containsKey('effective_month')) {
      context.handle(
        _effectiveMonthMeta,
        effectiveMonth.isAcceptableOrUnknown(
          data['effective_month']!,
          _effectiveMonthMeta,
        ),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {employeeId},
  ];
  @override
  InsuranceProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InsuranceProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      isInsured: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_insured'],
      )!,
      insuranceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}insurance_type'],
      ),
      contributionBase: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}contribution_base'],
      ),
      effectiveMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_month'],
      ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $InsuranceProfilesTable createAlias(String alias) {
    return $InsuranceProfilesTable(attachedDatabase, alias);
  }
}

class InsuranceProfile extends DataClass
    implements Insertable<InsuranceProfile> {
  final int id;
  final int employeeId;
  final bool isInsured;
  final String? insuranceType;
  final double? contributionBase;
  final String? effectiveMonth;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const InsuranceProfile({
    required this.id,
    required this.employeeId,
    required this.isInsured,
    this.insuranceType,
    this.contributionBase,
    this.effectiveMonth,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['is_insured'] = Variable<bool>(isInsured);
    if (!nullToAbsent || insuranceType != null) {
      map['insurance_type'] = Variable<String>(insuranceType);
    }
    if (!nullToAbsent || contributionBase != null) {
      map['contribution_base'] = Variable<double>(contributionBase);
    }
    if (!nullToAbsent || effectiveMonth != null) {
      map['effective_month'] = Variable<String>(effectiveMonth);
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  InsuranceProfilesCompanion toCompanion(bool nullToAbsent) {
    return InsuranceProfilesCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      isInsured: Value(isInsured),
      insuranceType: insuranceType == null && nullToAbsent
          ? const Value.absent()
          : Value(insuranceType),
      contributionBase: contributionBase == null && nullToAbsent
          ? const Value.absent()
          : Value(contributionBase),
      effectiveMonth: effectiveMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(effectiveMonth),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory InsuranceProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InsuranceProfile(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      isInsured: serializer.fromJson<bool>(json['isInsured']),
      insuranceType: serializer.fromJson<String?>(json['insuranceType']),
      contributionBase: serializer.fromJson<double?>(json['contributionBase']),
      effectiveMonth: serializer.fromJson<String?>(json['effectiveMonth']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'isInsured': serializer.toJson<bool>(isInsured),
      'insuranceType': serializer.toJson<String?>(insuranceType),
      'contributionBase': serializer.toJson<double?>(contributionBase),
      'effectiveMonth': serializer.toJson<String?>(effectiveMonth),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  InsuranceProfile copyWith({
    int? id,
    int? employeeId,
    bool? isInsured,
    Value<String?> insuranceType = const Value.absent(),
    Value<double?> contributionBase = const Value.absent(),
    Value<String?> effectiveMonth = const Value.absent(),
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => InsuranceProfile(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    isInsured: isInsured ?? this.isInsured,
    insuranceType: insuranceType.present
        ? insuranceType.value
        : this.insuranceType,
    contributionBase: contributionBase.present
        ? contributionBase.value
        : this.contributionBase,
    effectiveMonth: effectiveMonth.present
        ? effectiveMonth.value
        : this.effectiveMonth,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  InsuranceProfile copyWithCompanion(InsuranceProfilesCompanion data) {
    return InsuranceProfile(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      isInsured: data.isInsured.present ? data.isInsured.value : this.isInsured,
      insuranceType: data.insuranceType.present
          ? data.insuranceType.value
          : this.insuranceType,
      contributionBase: data.contributionBase.present
          ? data.contributionBase.value
          : this.contributionBase,
      effectiveMonth: data.effectiveMonth.present
          ? data.effectiveMonth.value
          : this.effectiveMonth,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InsuranceProfile(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('isInsured: $isInsured, ')
          ..write('insuranceType: $insuranceType, ')
          ..write('contributionBase: $contributionBase, ')
          ..write('effectiveMonth: $effectiveMonth, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    isInsured,
    insuranceType,
    contributionBase,
    effectiveMonth,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InsuranceProfile &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.isInsured == this.isInsured &&
          other.insuranceType == this.insuranceType &&
          other.contributionBase == this.contributionBase &&
          other.effectiveMonth == this.effectiveMonth &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class InsuranceProfilesCompanion extends UpdateCompanion<InsuranceProfile> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<bool> isInsured;
  final Value<String?> insuranceType;
  final Value<double?> contributionBase;
  final Value<String?> effectiveMonth;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const InsuranceProfilesCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.isInsured = const Value.absent(),
    this.insuranceType = const Value.absent(),
    this.contributionBase = const Value.absent(),
    this.effectiveMonth = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  InsuranceProfilesCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    this.isInsured = const Value.absent(),
    this.insuranceType = const Value.absent(),
    this.contributionBase = const Value.absent(),
    this.effectiveMonth = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : employeeId = Value(employeeId);
  static Insertable<InsuranceProfile> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<bool>? isInsured,
    Expression<String>? insuranceType,
    Expression<double>? contributionBase,
    Expression<String>? effectiveMonth,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (isInsured != null) 'is_insured': isInsured,
      if (insuranceType != null) 'insurance_type': insuranceType,
      if (contributionBase != null) 'contribution_base': contributionBase,
      if (effectiveMonth != null) 'effective_month': effectiveMonth,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  InsuranceProfilesCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<bool>? isInsured,
    Value<String?>? insuranceType,
    Value<double?>? contributionBase,
    Value<String?>? effectiveMonth,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return InsuranceProfilesCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      isInsured: isInsured ?? this.isInsured,
      insuranceType: insuranceType ?? this.insuranceType,
      contributionBase: contributionBase ?? this.contributionBase,
      effectiveMonth: effectiveMonth ?? this.effectiveMonth,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (isInsured.present) {
      map['is_insured'] = Variable<bool>(isInsured.value);
    }
    if (insuranceType.present) {
      map['insurance_type'] = Variable<String>(insuranceType.value);
    }
    if (contributionBase.present) {
      map['contribution_base'] = Variable<double>(contributionBase.value);
    }
    if (effectiveMonth.present) {
      map['effective_month'] = Variable<String>(effectiveMonth.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InsuranceProfilesCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('isInsured: $isInsured, ')
          ..write('insuranceType: $insuranceType, ')
          ..write('contributionBase: $contributionBase, ')
          ..write('effectiveMonth: $effectiveMonth, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $InsuranceChangeRecordsTable extends InsuranceChangeRecords
    with TableInfo<$InsuranceChangeRecordsTable, InsuranceChangeRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InsuranceChangeRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _changeTypeMeta = const VerificationMeta(
    'changeType',
  );
  @override
  late final GeneratedColumn<String> changeType = GeneratedColumn<String>(
    'change_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _processingStatusMeta = const VerificationMeta(
    'processingStatus',
  );
  @override
  late final GeneratedColumn<String> processingStatus = GeneratedColumn<String>(
    'processing_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _insuranceTypeMeta = const VerificationMeta(
    'insuranceType',
  );
  @override
  late final GeneratedColumn<String> insuranceType = GeneratedColumn<String>(
    'insurance_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contributionBaseMeta = const VerificationMeta(
    'contributionBase',
  );
  @override
  late final GeneratedColumn<double> contributionBase = GeneratedColumn<double>(
    'contribution_base',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effectiveMonthMeta = const VerificationMeta(
    'effectiveMonth',
  );
  @override
  late final GeneratedColumn<String> effectiveMonth = GeneratedColumn<String>(
    'effective_month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    changeType,
    processingStatus,
    insuranceType,
    contributionBase,
    effectiveMonth,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'insurance_change_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<InsuranceChangeRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('change_type')) {
      context.handle(
        _changeTypeMeta,
        changeType.isAcceptableOrUnknown(data['change_type']!, _changeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_changeTypeMeta);
    }
    if (data.containsKey('processing_status')) {
      context.handle(
        _processingStatusMeta,
        processingStatus.isAcceptableOrUnknown(
          data['processing_status']!,
          _processingStatusMeta,
        ),
      );
    }
    if (data.containsKey('insurance_type')) {
      context.handle(
        _insuranceTypeMeta,
        insuranceType.isAcceptableOrUnknown(
          data['insurance_type']!,
          _insuranceTypeMeta,
        ),
      );
    }
    if (data.containsKey('contribution_base')) {
      context.handle(
        _contributionBaseMeta,
        contributionBase.isAcceptableOrUnknown(
          data['contribution_base']!,
          _contributionBaseMeta,
        ),
      );
    }
    if (data.containsKey('effective_month')) {
      context.handle(
        _effectiveMonthMeta,
        effectiveMonth.isAcceptableOrUnknown(
          data['effective_month']!,
          _effectiveMonthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveMonthMeta);
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InsuranceChangeRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InsuranceChangeRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      changeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change_type'],
      )!,
      processingStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}processing_status'],
      )!,
      insuranceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}insurance_type'],
      ),
      contributionBase: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}contribution_base'],
      ),
      effectiveMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_month'],
      )!,
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $InsuranceChangeRecordsTable createAlias(String alias) {
    return $InsuranceChangeRecordsTable(attachedDatabase, alias);
  }
}

class InsuranceChangeRecord extends DataClass
    implements Insertable<InsuranceChangeRecord> {
  final int id;
  final int employeeId;
  final String changeType;
  final String processingStatus;
  final String? insuranceType;
  final double? contributionBase;
  final String effectiveMonth;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const InsuranceChangeRecord({
    required this.id,
    required this.employeeId,
    required this.changeType,
    required this.processingStatus,
    this.insuranceType,
    this.contributionBase,
    required this.effectiveMonth,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    map['change_type'] = Variable<String>(changeType);
    map['processing_status'] = Variable<String>(processingStatus);
    if (!nullToAbsent || insuranceType != null) {
      map['insurance_type'] = Variable<String>(insuranceType);
    }
    if (!nullToAbsent || contributionBase != null) {
      map['contribution_base'] = Variable<double>(contributionBase);
    }
    map['effective_month'] = Variable<String>(effectiveMonth);
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  InsuranceChangeRecordsCompanion toCompanion(bool nullToAbsent) {
    return InsuranceChangeRecordsCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      changeType: Value(changeType),
      processingStatus: Value(processingStatus),
      insuranceType: insuranceType == null && nullToAbsent
          ? const Value.absent()
          : Value(insuranceType),
      contributionBase: contributionBase == null && nullToAbsent
          ? const Value.absent()
          : Value(contributionBase),
      effectiveMonth: Value(effectiveMonth),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory InsuranceChangeRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InsuranceChangeRecord(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      changeType: serializer.fromJson<String>(json['changeType']),
      processingStatus: serializer.fromJson<String>(json['processingStatus']),
      insuranceType: serializer.fromJson<String?>(json['insuranceType']),
      contributionBase: serializer.fromJson<double?>(json['contributionBase']),
      effectiveMonth: serializer.fromJson<String>(json['effectiveMonth']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'changeType': serializer.toJson<String>(changeType),
      'processingStatus': serializer.toJson<String>(processingStatus),
      'insuranceType': serializer.toJson<String?>(insuranceType),
      'contributionBase': serializer.toJson<double?>(contributionBase),
      'effectiveMonth': serializer.toJson<String>(effectiveMonth),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  InsuranceChangeRecord copyWith({
    int? id,
    int? employeeId,
    String? changeType,
    String? processingStatus,
    Value<String?> insuranceType = const Value.absent(),
    Value<double?> contributionBase = const Value.absent(),
    String? effectiveMonth,
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => InsuranceChangeRecord(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    changeType: changeType ?? this.changeType,
    processingStatus: processingStatus ?? this.processingStatus,
    insuranceType: insuranceType.present
        ? insuranceType.value
        : this.insuranceType,
    contributionBase: contributionBase.present
        ? contributionBase.value
        : this.contributionBase,
    effectiveMonth: effectiveMonth ?? this.effectiveMonth,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  InsuranceChangeRecord copyWithCompanion(
    InsuranceChangeRecordsCompanion data,
  ) {
    return InsuranceChangeRecord(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      changeType: data.changeType.present
          ? data.changeType.value
          : this.changeType,
      processingStatus: data.processingStatus.present
          ? data.processingStatus.value
          : this.processingStatus,
      insuranceType: data.insuranceType.present
          ? data.insuranceType.value
          : this.insuranceType,
      contributionBase: data.contributionBase.present
          ? data.contributionBase.value
          : this.contributionBase,
      effectiveMonth: data.effectiveMonth.present
          ? data.effectiveMonth.value
          : this.effectiveMonth,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InsuranceChangeRecord(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('changeType: $changeType, ')
          ..write('processingStatus: $processingStatus, ')
          ..write('insuranceType: $insuranceType, ')
          ..write('contributionBase: $contributionBase, ')
          ..write('effectiveMonth: $effectiveMonth, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    changeType,
    processingStatus,
    insuranceType,
    contributionBase,
    effectiveMonth,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InsuranceChangeRecord &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.changeType == this.changeType &&
          other.processingStatus == this.processingStatus &&
          other.insuranceType == this.insuranceType &&
          other.contributionBase == this.contributionBase &&
          other.effectiveMonth == this.effectiveMonth &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class InsuranceChangeRecordsCompanion
    extends UpdateCompanion<InsuranceChangeRecord> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<String> changeType;
  final Value<String> processingStatus;
  final Value<String?> insuranceType;
  final Value<double?> contributionBase;
  final Value<String> effectiveMonth;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const InsuranceChangeRecordsCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.changeType = const Value.absent(),
    this.processingStatus = const Value.absent(),
    this.insuranceType = const Value.absent(),
    this.contributionBase = const Value.absent(),
    this.effectiveMonth = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  InsuranceChangeRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    required String changeType,
    this.processingStatus = const Value.absent(),
    this.insuranceType = const Value.absent(),
    this.contributionBase = const Value.absent(),
    required String effectiveMonth,
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : employeeId = Value(employeeId),
       changeType = Value(changeType),
       effectiveMonth = Value(effectiveMonth);
  static Insertable<InsuranceChangeRecord> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<String>? changeType,
    Expression<String>? processingStatus,
    Expression<String>? insuranceType,
    Expression<double>? contributionBase,
    Expression<String>? effectiveMonth,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (changeType != null) 'change_type': changeType,
      if (processingStatus != null) 'processing_status': processingStatus,
      if (insuranceType != null) 'insurance_type': insuranceType,
      if (contributionBase != null) 'contribution_base': contributionBase,
      if (effectiveMonth != null) 'effective_month': effectiveMonth,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  InsuranceChangeRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<String>? changeType,
    Value<String>? processingStatus,
    Value<String?>? insuranceType,
    Value<double?>? contributionBase,
    Value<String>? effectiveMonth,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return InsuranceChangeRecordsCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      changeType: changeType ?? this.changeType,
      processingStatus: processingStatus ?? this.processingStatus,
      insuranceType: insuranceType ?? this.insuranceType,
      contributionBase: contributionBase ?? this.contributionBase,
      effectiveMonth: effectiveMonth ?? this.effectiveMonth,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (changeType.present) {
      map['change_type'] = Variable<String>(changeType.value);
    }
    if (processingStatus.present) {
      map['processing_status'] = Variable<String>(processingStatus.value);
    }
    if (insuranceType.present) {
      map['insurance_type'] = Variable<String>(insuranceType.value);
    }
    if (contributionBase.present) {
      map['contribution_base'] = Variable<double>(contributionBase.value);
    }
    if (effectiveMonth.present) {
      map['effective_month'] = Variable<String>(effectiveMonth.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InsuranceChangeRecordsCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('changeType: $changeType, ')
          ..write('processingStatus: $processingStatus, ')
          ..write('insuranceType: $insuranceType, ')
          ..write('contributionBase: $contributionBase, ')
          ..write('effectiveMonth: $effectiveMonth, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $SocialSecurityBaseHistoryTable extends SocialSecurityBaseHistory
    with
        TableInfo<
          $SocialSecurityBaseHistoryTable,
          SocialSecurityBaseHistoryData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SocialSecurityBaseHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _employeeIdMeta = const VerificationMeta(
    'employeeId',
  );
  @override
  late final GeneratedColumn<int> employeeId = GeneratedColumn<int>(
    'employee_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES employees (id)',
    ),
  );
  static const VerificationMeta _insuranceTypeMeta = const VerificationMeta(
    'insuranceType',
  );
  @override
  late final GeneratedColumn<String> insuranceType = GeneratedColumn<String>(
    'insurance_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contributionBaseMeta = const VerificationMeta(
    'contributionBase',
  );
  @override
  late final GeneratedColumn<double> contributionBase = GeneratedColumn<double>(
    'contribution_base',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effectiveMonthMeta = const VerificationMeta(
    'effectiveMonth',
  );
  @override
  late final GeneratedColumn<String> effectiveMonth = GeneratedColumn<String>(
    'effective_month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    employeeId,
    insuranceType,
    contributionBase,
    effectiveMonth,
    source,
    createdAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'social_security_base_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<SocialSecurityBaseHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('employee_id')) {
      context.handle(
        _employeeIdMeta,
        employeeId.isAcceptableOrUnknown(data['employee_id']!, _employeeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_employeeIdMeta);
    }
    if (data.containsKey('insurance_type')) {
      context.handle(
        _insuranceTypeMeta,
        insuranceType.isAcceptableOrUnknown(
          data['insurance_type']!,
          _insuranceTypeMeta,
        ),
      );
    }
    if (data.containsKey('contribution_base')) {
      context.handle(
        _contributionBaseMeta,
        contributionBase.isAcceptableOrUnknown(
          data['contribution_base']!,
          _contributionBaseMeta,
        ),
      );
    }
    if (data.containsKey('effective_month')) {
      context.handle(
        _effectiveMonthMeta,
        effectiveMonth.isAcceptableOrUnknown(
          data['effective_month']!,
          _effectiveMonthMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_effectiveMonthMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SocialSecurityBaseHistoryData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SocialSecurityBaseHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      employeeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}employee_id'],
      )!,
      insuranceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}insurance_type'],
      ),
      contributionBase: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}contribution_base'],
      ),
      effectiveMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effective_month'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $SocialSecurityBaseHistoryTable createAlias(String alias) {
    return $SocialSecurityBaseHistoryTable(attachedDatabase, alias);
  }
}

class SocialSecurityBaseHistoryData extends DataClass
    implements Insertable<SocialSecurityBaseHistoryData> {
  final int id;
  final int employeeId;
  final String? insuranceType;
  final double? contributionBase;
  final String effectiveMonth;
  final String? source;
  final DateTime createdAt;
  final bool isDeleted;
  const SocialSecurityBaseHistoryData({
    required this.id,
    required this.employeeId,
    this.insuranceType,
    this.contributionBase,
    required this.effectiveMonth,
    this.source,
    required this.createdAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['employee_id'] = Variable<int>(employeeId);
    if (!nullToAbsent || insuranceType != null) {
      map['insurance_type'] = Variable<String>(insuranceType);
    }
    if (!nullToAbsent || contributionBase != null) {
      map['contribution_base'] = Variable<double>(contributionBase);
    }
    map['effective_month'] = Variable<String>(effectiveMonth);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  SocialSecurityBaseHistoryCompanion toCompanion(bool nullToAbsent) {
    return SocialSecurityBaseHistoryCompanion(
      id: Value(id),
      employeeId: Value(employeeId),
      insuranceType: insuranceType == null && nullToAbsent
          ? const Value.absent()
          : Value(insuranceType),
      contributionBase: contributionBase == null && nullToAbsent
          ? const Value.absent()
          : Value(contributionBase),
      effectiveMonth: Value(effectiveMonth),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      createdAt: Value(createdAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory SocialSecurityBaseHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SocialSecurityBaseHistoryData(
      id: serializer.fromJson<int>(json['id']),
      employeeId: serializer.fromJson<int>(json['employeeId']),
      insuranceType: serializer.fromJson<String?>(json['insuranceType']),
      contributionBase: serializer.fromJson<double?>(json['contributionBase']),
      effectiveMonth: serializer.fromJson<String>(json['effectiveMonth']),
      source: serializer.fromJson<String?>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'employeeId': serializer.toJson<int>(employeeId),
      'insuranceType': serializer.toJson<String?>(insuranceType),
      'contributionBase': serializer.toJson<double?>(contributionBase),
      'effectiveMonth': serializer.toJson<String>(effectiveMonth),
      'source': serializer.toJson<String?>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  SocialSecurityBaseHistoryData copyWith({
    int? id,
    int? employeeId,
    Value<String?> insuranceType = const Value.absent(),
    Value<double?> contributionBase = const Value.absent(),
    String? effectiveMonth,
    Value<String?> source = const Value.absent(),
    DateTime? createdAt,
    bool? isDeleted,
  }) => SocialSecurityBaseHistoryData(
    id: id ?? this.id,
    employeeId: employeeId ?? this.employeeId,
    insuranceType: insuranceType.present
        ? insuranceType.value
        : this.insuranceType,
    contributionBase: contributionBase.present
        ? contributionBase.value
        : this.contributionBase,
    effectiveMonth: effectiveMonth ?? this.effectiveMonth,
    source: source.present ? source.value : this.source,
    createdAt: createdAt ?? this.createdAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  SocialSecurityBaseHistoryData copyWithCompanion(
    SocialSecurityBaseHistoryCompanion data,
  ) {
    return SocialSecurityBaseHistoryData(
      id: data.id.present ? data.id.value : this.id,
      employeeId: data.employeeId.present
          ? data.employeeId.value
          : this.employeeId,
      insuranceType: data.insuranceType.present
          ? data.insuranceType.value
          : this.insuranceType,
      contributionBase: data.contributionBase.present
          ? data.contributionBase.value
          : this.contributionBase,
      effectiveMonth: data.effectiveMonth.present
          ? data.effectiveMonth.value
          : this.effectiveMonth,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SocialSecurityBaseHistoryData(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('insuranceType: $insuranceType, ')
          ..write('contributionBase: $contributionBase, ')
          ..write('effectiveMonth: $effectiveMonth, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    employeeId,
    insuranceType,
    contributionBase,
    effectiveMonth,
    source,
    createdAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SocialSecurityBaseHistoryData &&
          other.id == this.id &&
          other.employeeId == this.employeeId &&
          other.insuranceType == this.insuranceType &&
          other.contributionBase == this.contributionBase &&
          other.effectiveMonth == this.effectiveMonth &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.isDeleted == this.isDeleted);
}

class SocialSecurityBaseHistoryCompanion
    extends UpdateCompanion<SocialSecurityBaseHistoryData> {
  final Value<int> id;
  final Value<int> employeeId;
  final Value<String?> insuranceType;
  final Value<double?> contributionBase;
  final Value<String> effectiveMonth;
  final Value<String?> source;
  final Value<DateTime> createdAt;
  final Value<bool> isDeleted;
  const SocialSecurityBaseHistoryCompanion({
    this.id = const Value.absent(),
    this.employeeId = const Value.absent(),
    this.insuranceType = const Value.absent(),
    this.contributionBase = const Value.absent(),
    this.effectiveMonth = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  SocialSecurityBaseHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int employeeId,
    this.insuranceType = const Value.absent(),
    this.contributionBase = const Value.absent(),
    required String effectiveMonth,
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : employeeId = Value(employeeId),
       effectiveMonth = Value(effectiveMonth);
  static Insertable<SocialSecurityBaseHistoryData> custom({
    Expression<int>? id,
    Expression<int>? employeeId,
    Expression<String>? insuranceType,
    Expression<double>? contributionBase,
    Expression<String>? effectiveMonth,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (employeeId != null) 'employee_id': employeeId,
      if (insuranceType != null) 'insurance_type': insuranceType,
      if (contributionBase != null) 'contribution_base': contributionBase,
      if (effectiveMonth != null) 'effective_month': effectiveMonth,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  SocialSecurityBaseHistoryCompanion copyWith({
    Value<int>? id,
    Value<int>? employeeId,
    Value<String?>? insuranceType,
    Value<double?>? contributionBase,
    Value<String>? effectiveMonth,
    Value<String?>? source,
    Value<DateTime>? createdAt,
    Value<bool>? isDeleted,
  }) {
    return SocialSecurityBaseHistoryCompanion(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      insuranceType: insuranceType ?? this.insuranceType,
      contributionBase: contributionBase ?? this.contributionBase,
      effectiveMonth: effectiveMonth ?? this.effectiveMonth,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (employeeId.present) {
      map['employee_id'] = Variable<int>(employeeId.value);
    }
    if (insuranceType.present) {
      map['insurance_type'] = Variable<String>(insuranceType.value);
    }
    if (contributionBase.present) {
      map['contribution_base'] = Variable<double>(contributionBase.value);
    }
    if (effectiveMonth.present) {
      map['effective_month'] = Variable<String>(effectiveMonth.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SocialSecurityBaseHistoryCompanion(')
          ..write('id: $id, ')
          ..write('employeeId: $employeeId, ')
          ..write('insuranceType: $insuranceType, ')
          ..write('contributionBase: $contributionBase, ')
          ..write('effectiveMonth: $effectiveMonth, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $OperationLogsTable extends OperationLogs
    with TableInfo<$OperationLogsTable, OperationLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
    'entity_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operationType,
    entityType,
    entityId,
    detail,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operation_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperationLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperationLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperationLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_id'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OperationLogsTable createAlias(String alias) {
    return $OperationLogsTable(attachedDatabase, alias);
  }
}

class OperationLog extends DataClass implements Insertable<OperationLog> {
  final int id;
  final String operationType;
  final String entityType;
  final int? entityId;
  final String? detail;
  final DateTime createdAt;
  const OperationLog({
    required this.id,
    required this.operationType,
    required this.entityType,
    this.entityId,
    this.detail,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation_type'] = Variable<String>(operationType);
    map['entity_type'] = Variable<String>(entityType);
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<int>(entityId);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OperationLogsCompanion toCompanion(bool nullToAbsent) {
    return OperationLogsCompanion(
      id: Value(id),
      operationType: Value(operationType),
      entityType: Value(entityType),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      createdAt: Value(createdAt),
    );
  }

  factory OperationLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperationLog(
      id: serializer.fromJson<int>(json['id']),
      operationType: serializer.fromJson<String>(json['operationType']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<int?>(json['entityId']),
      detail: serializer.fromJson<String?>(json['detail']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operationType': serializer.toJson<String>(operationType),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<int?>(entityId),
      'detail': serializer.toJson<String?>(detail),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OperationLog copyWith({
    int? id,
    String? operationType,
    String? entityType,
    Value<int?> entityId = const Value.absent(),
    Value<String?> detail = const Value.absent(),
    DateTime? createdAt,
  }) => OperationLog(
    id: id ?? this.id,
    operationType: operationType ?? this.operationType,
    entityType: entityType ?? this.entityType,
    entityId: entityId.present ? entityId.value : this.entityId,
    detail: detail.present ? detail.value : this.detail,
    createdAt: createdAt ?? this.createdAt,
  );
  OperationLog copyWithCompanion(OperationLogsCompanion data) {
    return OperationLog(
      id: data.id.present ? data.id.value : this.id,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      detail: data.detail.present ? data.detail.value : this.detail,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperationLog(')
          ..write('id: $id, ')
          ..write('operationType: $operationType, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('detail: $detail, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, operationType, entityType, entityId, detail, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperationLog &&
          other.id == this.id &&
          other.operationType == this.operationType &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.detail == this.detail &&
          other.createdAt == this.createdAt);
}

class OperationLogsCompanion extends UpdateCompanion<OperationLog> {
  final Value<int> id;
  final Value<String> operationType;
  final Value<String> entityType;
  final Value<int?> entityId;
  final Value<String?> detail;
  final Value<DateTime> createdAt;
  const OperationLogsCompanion({
    this.id = const Value.absent(),
    this.operationType = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.detail = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OperationLogsCompanion.insert({
    this.id = const Value.absent(),
    required String operationType,
    required String entityType,
    this.entityId = const Value.absent(),
    this.detail = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : operationType = Value(operationType),
       entityType = Value(entityType);
  static Insertable<OperationLog> custom({
    Expression<int>? id,
    Expression<String>? operationType,
    Expression<String>? entityType,
    Expression<int>? entityId,
    Expression<String>? detail,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operationType != null) 'operation_type': operationType,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (detail != null) 'detail': detail,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OperationLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? operationType,
    Value<String>? entityType,
    Value<int?>? entityId,
    Value<String?>? detail,
    Value<DateTime>? createdAt,
  }) {
    return OperationLogsCompanion(
      id: id ?? this.id,
      operationType: operationType ?? this.operationType,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      detail: detail ?? this.detail,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationLogsCompanion(')
          ..write('id: $id, ')
          ..write('operationType: $operationType, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('detail: $detail, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DictionaryItemsTable extends DictionaryItems
    with TableInfo<$DictionaryItemsTable, DictionaryItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dictionaryTypeMeta = const VerificationMeta(
    'dictionaryType',
  );
  @override
  late final GeneratedColumn<String> dictionaryType = GeneratedColumn<String>(
    'dictionary_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemKeyMeta = const VerificationMeta(
    'itemKey',
  );
  @override
  late final GeneratedColumn<String> itemKey = GeneratedColumn<String>(
    'item_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemLabelMeta = const VerificationMeta(
    'itemLabel',
  );
  @override
  late final GeneratedColumn<String> itemLabel = GeneratedColumn<String>(
    'item_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dictionaryType,
    itemKey,
    itemLabel,
    sortOrder,
    isEnabled,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DictionaryItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dictionary_type')) {
      context.handle(
        _dictionaryTypeMeta,
        dictionaryType.isAcceptableOrUnknown(
          data['dictionary_type']!,
          _dictionaryTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dictionaryTypeMeta);
    }
    if (data.containsKey('item_key')) {
      context.handle(
        _itemKeyMeta,
        itemKey.isAcceptableOrUnknown(data['item_key']!, _itemKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKeyMeta);
    }
    if (data.containsKey('item_label')) {
      context.handle(
        _itemLabelMeta,
        itemLabel.isAcceptableOrUnknown(data['item_label']!, _itemLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_itemLabelMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {dictionaryType, itemKey},
  ];
  @override
  DictionaryItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dictionaryType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dictionary_type'],
      )!,
      itemKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_key'],
      )!,
      itemLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_label'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $DictionaryItemsTable createAlias(String alias) {
    return $DictionaryItemsTable(attachedDatabase, alias);
  }
}

class DictionaryItem extends DataClass implements Insertable<DictionaryItem> {
  final int id;
  final String dictionaryType;
  final String itemKey;
  final String itemLabel;
  final int sortOrder;
  final bool isEnabled;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const DictionaryItem({
    required this.id,
    required this.dictionaryType,
    required this.itemKey,
    required this.itemLabel,
    required this.sortOrder,
    required this.isEnabled,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dictionary_type'] = Variable<String>(dictionaryType);
    map['item_key'] = Variable<String>(itemKey);
    map['item_label'] = Variable<String>(itemLabel);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_enabled'] = Variable<bool>(isEnabled);
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  DictionaryItemsCompanion toCompanion(bool nullToAbsent) {
    return DictionaryItemsCompanion(
      id: Value(id),
      dictionaryType: Value(dictionaryType),
      itemKey: Value(itemKey),
      itemLabel: Value(itemLabel),
      sortOrder: Value(sortOrder),
      isEnabled: Value(isEnabled),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory DictionaryItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryItem(
      id: serializer.fromJson<int>(json['id']),
      dictionaryType: serializer.fromJson<String>(json['dictionaryType']),
      itemKey: serializer.fromJson<String>(json['itemKey']),
      itemLabel: serializer.fromJson<String>(json['itemLabel']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dictionaryType': serializer.toJson<String>(dictionaryType),
      'itemKey': serializer.toJson<String>(itemKey),
      'itemLabel': serializer.toJson<String>(itemLabel),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  DictionaryItem copyWith({
    int? id,
    String? dictionaryType,
    String? itemKey,
    String? itemLabel,
    int? sortOrder,
    bool? isEnabled,
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => DictionaryItem(
    id: id ?? this.id,
    dictionaryType: dictionaryType ?? this.dictionaryType,
    itemKey: itemKey ?? this.itemKey,
    itemLabel: itemLabel ?? this.itemLabel,
    sortOrder: sortOrder ?? this.sortOrder,
    isEnabled: isEnabled ?? this.isEnabled,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  DictionaryItem copyWithCompanion(DictionaryItemsCompanion data) {
    return DictionaryItem(
      id: data.id.present ? data.id.value : this.id,
      dictionaryType: data.dictionaryType.present
          ? data.dictionaryType.value
          : this.dictionaryType,
      itemKey: data.itemKey.present ? data.itemKey.value : this.itemKey,
      itemLabel: data.itemLabel.present ? data.itemLabel.value : this.itemLabel,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryItem(')
          ..write('id: $id, ')
          ..write('dictionaryType: $dictionaryType, ')
          ..write('itemKey: $itemKey, ')
          ..write('itemLabel: $itemLabel, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dictionaryType,
    itemKey,
    itemLabel,
    sortOrder,
    isEnabled,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryItem &&
          other.id == this.id &&
          other.dictionaryType == this.dictionaryType &&
          other.itemKey == this.itemKey &&
          other.itemLabel == this.itemLabel &&
          other.sortOrder == this.sortOrder &&
          other.isEnabled == this.isEnabled &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class DictionaryItemsCompanion extends UpdateCompanion<DictionaryItem> {
  final Value<int> id;
  final Value<String> dictionaryType;
  final Value<String> itemKey;
  final Value<String> itemLabel;
  final Value<int> sortOrder;
  final Value<bool> isEnabled;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const DictionaryItemsCompanion({
    this.id = const Value.absent(),
    this.dictionaryType = const Value.absent(),
    this.itemKey = const Value.absent(),
    this.itemLabel = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  DictionaryItemsCompanion.insert({
    this.id = const Value.absent(),
    required String dictionaryType,
    required String itemKey,
    required String itemLabel,
    this.sortOrder = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : dictionaryType = Value(dictionaryType),
       itemKey = Value(itemKey),
       itemLabel = Value(itemLabel);
  static Insertable<DictionaryItem> custom({
    Expression<int>? id,
    Expression<String>? dictionaryType,
    Expression<String>? itemKey,
    Expression<String>? itemLabel,
    Expression<int>? sortOrder,
    Expression<bool>? isEnabled,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dictionaryType != null) 'dictionary_type': dictionaryType,
      if (itemKey != null) 'item_key': itemKey,
      if (itemLabel != null) 'item_label': itemLabel,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  DictionaryItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? dictionaryType,
    Value<String>? itemKey,
    Value<String>? itemLabel,
    Value<int>? sortOrder,
    Value<bool>? isEnabled,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return DictionaryItemsCompanion(
      id: id ?? this.id,
      dictionaryType: dictionaryType ?? this.dictionaryType,
      itemKey: itemKey ?? this.itemKey,
      itemLabel: itemLabel ?? this.itemLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      isEnabled: isEnabled ?? this.isEnabled,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dictionaryType.present) {
      map['dictionary_type'] = Variable<String>(dictionaryType.value);
    }
    if (itemKey.present) {
      map['item_key'] = Variable<String>(itemKey.value);
    }
    if (itemLabel.present) {
      map['item_label'] = Variable<String>(itemLabel.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryItemsCompanion(')
          ..write('id: $id, ')
          ..write('dictionaryType: $dictionaryType, ')
          ..write('itemKey: $itemKey, ')
          ..write('itemLabel: $itemLabel, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _settingKeyMeta = const VerificationMeta(
    'settingKey',
  );
  @override
  late final GeneratedColumn<String> settingKey = GeneratedColumn<String>(
    'setting_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _settingValueMeta = const VerificationMeta(
    'settingValue',
  );
  @override
  late final GeneratedColumn<String> settingValue = GeneratedColumn<String>(
    'setting_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    settingKey,
    settingValue,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('setting_key')) {
      context.handle(
        _settingKeyMeta,
        settingKey.isAcceptableOrUnknown(data['setting_key']!, _settingKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_settingKeyMeta);
    }
    if (data.containsKey('setting_value')) {
      context.handle(
        _settingValueMeta,
        settingValue.isAcceptableOrUnknown(
          data['setting_value']!,
          _settingValueMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      settingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_key'],
      )!,
      settingValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_value'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final String settingKey;
  final String? settingValue;
  final DateTime updatedAt;
  const AppSetting({
    required this.id,
    required this.settingKey,
    this.settingValue,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['setting_key'] = Variable<String>(settingKey);
    if (!nullToAbsent || settingValue != null) {
      map['setting_value'] = Variable<String>(settingValue);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      settingKey: Value(settingKey),
      settingValue: settingValue == null && nullToAbsent
          ? const Value.absent()
          : Value(settingValue),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      settingKey: serializer.fromJson<String>(json['settingKey']),
      settingValue: serializer.fromJson<String?>(json['settingValue']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'settingKey': serializer.toJson<String>(settingKey),
      'settingValue': serializer.toJson<String?>(settingValue),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSetting copyWith({
    int? id,
    String? settingKey,
    Value<String?> settingValue = const Value.absent(),
    DateTime? updatedAt,
  }) => AppSetting(
    id: id ?? this.id,
    settingKey: settingKey ?? this.settingKey,
    settingValue: settingValue.present ? settingValue.value : this.settingValue,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      settingKey: data.settingKey.present
          ? data.settingKey.value
          : this.settingKey,
      settingValue: data.settingValue.present
          ? data.settingValue.value
          : this.settingValue,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, settingKey, settingValue, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.settingKey == this.settingKey &&
          other.settingValue == this.settingValue &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<String> settingKey;
  final Value<String?> settingValue;
  final Value<DateTime> updatedAt;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.settingKey = const Value.absent(),
    this.settingValue = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String settingKey,
    this.settingValue = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : settingKey = Value(settingKey);
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<String>? settingKey,
    Expression<String>? settingValue,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (settingKey != null) 'setting_key': settingKey,
      if (settingValue != null) 'setting_value': settingValue,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? settingKey,
    Value<String?>? settingValue,
    Value<DateTime>? updatedAt,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (settingKey.present) {
      map['setting_key'] = Variable<String>(settingKey.value);
    }
    if (settingValue.present) {
      map['setting_value'] = Variable<String>(settingValue.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderTypeMeta = const VerificationMeta(
    'reminderType',
  );
  @override
  late final GeneratedColumn<String> reminderType = GeneratedColumn<String>(
    'reminder_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leadDaysMeta = const VerificationMeta(
    'leadDays',
  );
  @override
  late final GeneratedColumn<int> leadDays = GeneratedColumn<int>(
    'lead_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repeatRuleMeta = const VerificationMeta(
    'repeatRule',
  );
  @override
  late final GeneratedColumn<String> repeatRule = GeneratedColumn<String>(
    'repeat_rule',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceEntityTypeMeta = const VerificationMeta(
    'sourceEntityType',
  );
  @override
  late final GeneratedColumn<String> sourceEntityType = GeneratedColumn<String>(
    'source_entity_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceEntityIdMeta = const VerificationMeta(
    'sourceEntityId',
  );
  @override
  late final GeneratedColumn<int> sourceEntityId = GeneratedColumn<int>(
    'source_entity_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remarkMeta = const VerificationMeta('remark');
  @override
  late final GeneratedColumn<String> remark = GeneratedColumn<String>(
    'remark',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    reminderType,
    dueDate,
    leadDays,
    repeatRule,
    isEnabled,
    isCompleted,
    sourceEntityType,
    sourceEntityId,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('reminder_type')) {
      context.handle(
        _reminderTypeMeta,
        reminderType.isAcceptableOrUnknown(
          data['reminder_type']!,
          _reminderTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reminderTypeMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('lead_days')) {
      context.handle(
        _leadDaysMeta,
        leadDays.isAcceptableOrUnknown(data['lead_days']!, _leadDaysMeta),
      );
    }
    if (data.containsKey('repeat_rule')) {
      context.handle(
        _repeatRuleMeta,
        repeatRule.isAcceptableOrUnknown(data['repeat_rule']!, _repeatRuleMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('source_entity_type')) {
      context.handle(
        _sourceEntityTypeMeta,
        sourceEntityType.isAcceptableOrUnknown(
          data['source_entity_type']!,
          _sourceEntityTypeMeta,
        ),
      );
    }
    if (data.containsKey('source_entity_id')) {
      context.handle(
        _sourceEntityIdMeta,
        sourceEntityId.isAcceptableOrUnknown(
          data['source_entity_id']!,
          _sourceEntityIdMeta,
        ),
      );
    }
    if (data.containsKey('remark')) {
      context.handle(
        _remarkMeta,
        remark.isAcceptableOrUnknown(data['remark']!, _remarkMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      reminderType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_type'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      leadDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lead_days'],
      )!,
      repeatRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_rule'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      sourceEntityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_entity_type'],
      ),
      sourceEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_entity_id'],
      ),
      remark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remark'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final int id;
  final String title;
  final String reminderType;
  final DateTime? dueDate;
  final int leadDays;
  final String? repeatRule;
  final bool isEnabled;
  final bool isCompleted;
  final String? sourceEntityType;
  final int? sourceEntityId;
  final String? remark;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const Reminder({
    required this.id,
    required this.title,
    required this.reminderType,
    this.dueDate,
    required this.leadDays,
    this.repeatRule,
    required this.isEnabled,
    required this.isCompleted,
    this.sourceEntityType,
    this.sourceEntityId,
    this.remark,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['reminder_type'] = Variable<String>(reminderType);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['lead_days'] = Variable<int>(leadDays);
    if (!nullToAbsent || repeatRule != null) {
      map['repeat_rule'] = Variable<String>(repeatRule);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || sourceEntityType != null) {
      map['source_entity_type'] = Variable<String>(sourceEntityType);
    }
    if (!nullToAbsent || sourceEntityId != null) {
      map['source_entity_id'] = Variable<int>(sourceEntityId);
    }
    if (!nullToAbsent || remark != null) {
      map['remark'] = Variable<String>(remark);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      title: Value(title),
      reminderType: Value(reminderType),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      leadDays: Value(leadDays),
      repeatRule: repeatRule == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatRule),
      isEnabled: Value(isEnabled),
      isCompleted: Value(isCompleted),
      sourceEntityType: sourceEntityType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceEntityType),
      sourceEntityId: sourceEntityId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceEntityId),
      remark: remark == null && nullToAbsent
          ? const Value.absent()
          : Value(remark),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      reminderType: serializer.fromJson<String>(json['reminderType']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      leadDays: serializer.fromJson<int>(json['leadDays']),
      repeatRule: serializer.fromJson<String?>(json['repeatRule']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      sourceEntityType: serializer.fromJson<String?>(json['sourceEntityType']),
      sourceEntityId: serializer.fromJson<int?>(json['sourceEntityId']),
      remark: serializer.fromJson<String?>(json['remark']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'reminderType': serializer.toJson<String>(reminderType),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'leadDays': serializer.toJson<int>(leadDays),
      'repeatRule': serializer.toJson<String?>(repeatRule),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'sourceEntityType': serializer.toJson<String?>(sourceEntityType),
      'sourceEntityId': serializer.toJson<int?>(sourceEntityId),
      'remark': serializer.toJson<String?>(remark),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Reminder copyWith({
    int? id,
    String? title,
    String? reminderType,
    Value<DateTime?> dueDate = const Value.absent(),
    int? leadDays,
    Value<String?> repeatRule = const Value.absent(),
    bool? isEnabled,
    bool? isCompleted,
    Value<String?> sourceEntityType = const Value.absent(),
    Value<int?> sourceEntityId = const Value.absent(),
    Value<String?> remark = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => Reminder(
    id: id ?? this.id,
    title: title ?? this.title,
    reminderType: reminderType ?? this.reminderType,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    leadDays: leadDays ?? this.leadDays,
    repeatRule: repeatRule.present ? repeatRule.value : this.repeatRule,
    isEnabled: isEnabled ?? this.isEnabled,
    isCompleted: isCompleted ?? this.isCompleted,
    sourceEntityType: sourceEntityType.present
        ? sourceEntityType.value
        : this.sourceEntityType,
    sourceEntityId: sourceEntityId.present
        ? sourceEntityId.value
        : this.sourceEntityId,
    remark: remark.present ? remark.value : this.remark,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  Reminder copyWithCompanion(RemindersCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      reminderType: data.reminderType.present
          ? data.reminderType.value
          : this.reminderType,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      leadDays: data.leadDays.present ? data.leadDays.value : this.leadDays,
      repeatRule: data.repeatRule.present
          ? data.repeatRule.value
          : this.repeatRule,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      sourceEntityType: data.sourceEntityType.present
          ? data.sourceEntityType.value
          : this.sourceEntityType,
      sourceEntityId: data.sourceEntityId.present
          ? data.sourceEntityId.value
          : this.sourceEntityId,
      remark: data.remark.present ? data.remark.value : this.remark,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('reminderType: $reminderType, ')
          ..write('dueDate: $dueDate, ')
          ..write('leadDays: $leadDays, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('sourceEntityType: $sourceEntityType, ')
          ..write('sourceEntityId: $sourceEntityId, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    reminderType,
    dueDate,
    leadDays,
    repeatRule,
    isEnabled,
    isCompleted,
    sourceEntityType,
    sourceEntityId,
    remark,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.title == this.title &&
          other.reminderType == this.reminderType &&
          other.dueDate == this.dueDate &&
          other.leadDays == this.leadDays &&
          other.repeatRule == this.repeatRule &&
          other.isEnabled == this.isEnabled &&
          other.isCompleted == this.isCompleted &&
          other.sourceEntityType == this.sourceEntityType &&
          other.sourceEntityId == this.sourceEntityId &&
          other.remark == this.remark &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class RemindersCompanion extends UpdateCompanion<Reminder> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> reminderType;
  final Value<DateTime?> dueDate;
  final Value<int> leadDays;
  final Value<String?> repeatRule;
  final Value<bool> isEnabled;
  final Value<bool> isCompleted;
  final Value<String?> sourceEntityType;
  final Value<int?> sourceEntityId;
  final Value<String?> remark;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.reminderType = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.leadDays = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.sourceEntityType = const Value.absent(),
    this.sourceEntityId = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  RemindersCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String reminderType,
    this.dueDate = const Value.absent(),
    this.leadDays = const Value.absent(),
    this.repeatRule = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.sourceEntityType = const Value.absent(),
    this.sourceEntityId = const Value.absent(),
    this.remark = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  }) : title = Value(title),
       reminderType = Value(reminderType);
  static Insertable<Reminder> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? reminderType,
    Expression<DateTime>? dueDate,
    Expression<int>? leadDays,
    Expression<String>? repeatRule,
    Expression<bool>? isEnabled,
    Expression<bool>? isCompleted,
    Expression<String>? sourceEntityType,
    Expression<int>? sourceEntityId,
    Expression<String>? remark,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (reminderType != null) 'reminder_type': reminderType,
      if (dueDate != null) 'due_date': dueDate,
      if (leadDays != null) 'lead_days': leadDays,
      if (repeatRule != null) 'repeat_rule': repeatRule,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (sourceEntityType != null) 'source_entity_type': sourceEntityType,
      if (sourceEntityId != null) 'source_entity_id': sourceEntityId,
      if (remark != null) 'remark': remark,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  RemindersCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? reminderType,
    Value<DateTime?>? dueDate,
    Value<int>? leadDays,
    Value<String?>? repeatRule,
    Value<bool>? isEnabled,
    Value<bool>? isCompleted,
    Value<String?>? sourceEntityType,
    Value<int?>? sourceEntityId,
    Value<String?>? remark,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      reminderType: reminderType ?? this.reminderType,
      dueDate: dueDate ?? this.dueDate,
      leadDays: leadDays ?? this.leadDays,
      repeatRule: repeatRule ?? this.repeatRule,
      isEnabled: isEnabled ?? this.isEnabled,
      isCompleted: isCompleted ?? this.isCompleted,
      sourceEntityType: sourceEntityType ?? this.sourceEntityType,
      sourceEntityId: sourceEntityId ?? this.sourceEntityId,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (reminderType.present) {
      map['reminder_type'] = Variable<String>(reminderType.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (leadDays.present) {
      map['lead_days'] = Variable<int>(leadDays.value);
    }
    if (repeatRule.present) {
      map['repeat_rule'] = Variable<String>(repeatRule.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (sourceEntityType.present) {
      map['source_entity_type'] = Variable<String>(sourceEntityType.value);
    }
    if (sourceEntityId.present) {
      map['source_entity_id'] = Variable<int>(sourceEntityId.value);
    }
    if (remark.present) {
      map['remark'] = Variable<String>(remark.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('reminderType: $reminderType, ')
          ..write('dueDate: $dueDate, ')
          ..write('leadDays: $leadDays, ')
          ..write('repeatRule: $repeatRule, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('sourceEntityType: $sourceEntityType, ')
          ..write('sourceEntityId: $sourceEntityId, ')
          ..write('remark: $remark, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AttendanceGroupsTable attendanceGroups = $AttendanceGroupsTable(
    this,
  );
  late final $EmployeesTable employees = $EmployeesTable(this);
  late final $AttendanceGroupMembersTable attendanceGroupMembers =
      $AttendanceGroupMembersTable(this);
  late final $MonthlyAttendanceRostersTable monthlyAttendanceRosters =
      $MonthlyAttendanceRostersTable(this);
  late final $AttendanceRecordsTable attendanceRecords =
      $AttendanceRecordsTable(this);
  late final $LeaveRecordsTable leaveRecords = $LeaveRecordsTable(this);
  late final $OvertimeRecordsTable overtimeRecords = $OvertimeRecordsTable(
    this,
  );
  late final $TerminationRecordsTable terminationRecords =
      $TerminationRecordsTable(this);
  late final $MonthlyAttendanceSummariesTable monthlyAttendanceSummaries =
      $MonthlyAttendanceSummariesTable(this);
  late final $InsuranceProfilesTable insuranceProfiles =
      $InsuranceProfilesTable(this);
  late final $InsuranceChangeRecordsTable insuranceChangeRecords =
      $InsuranceChangeRecordsTable(this);
  late final $SocialSecurityBaseHistoryTable socialSecurityBaseHistory =
      $SocialSecurityBaseHistoryTable(this);
  late final $OperationLogsTable operationLogs = $OperationLogsTable(this);
  late final $DictionaryItemsTable dictionaryItems = $DictionaryItemsTable(
    this,
  );
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    attendanceGroups,
    employees,
    attendanceGroupMembers,
    monthlyAttendanceRosters,
    attendanceRecords,
    leaveRecords,
    overtimeRecords,
    terminationRecords,
    monthlyAttendanceSummaries,
    insuranceProfiles,
    insuranceChangeRecords,
    socialSecurityBaseHistory,
    operationLogs,
    dictionaryItems,
    appSettings,
    reminders,
  ];
}

typedef $$AttendanceGroupsTableCreateCompanionBuilder =
    AttendanceGroupsCompanion Function({
      Value<int> id,
      required String name,
      Value<String> groupType,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$AttendanceGroupsTableUpdateCompanionBuilder =
    AttendanceGroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> groupType,
      Value<bool> isEnabled,
      Value<int> sortOrder,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$AttendanceGroupsTableReferences
    extends
        BaseReferences<_$AppDatabase, $AttendanceGroupsTable, AttendanceGroup> {
  $$AttendanceGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$EmployeesTable, List<Employee>>
  _employeesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.employees,
    aliasName: 'attendance_groups__id__employees__default_attendance_group_id',
  );

  $$EmployeesTableProcessedTableManager get employeesRefs {
    final manager = $$EmployeesTableTableManager($_db, $_db.employees).filter(
      (f) => f.defaultAttendanceGroupId.id.sqlEquals($_itemColumn<int>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_employeesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $AttendanceGroupMembersTable,
    List<AttendanceGroupMember>
  >
  _attendanceGroupMembersRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.attendanceGroupMembers,
    aliasName:
        'attendance_groups__id__attendance_group_members__attendance_group_id',
  );

  $$AttendanceGroupMembersTableProcessedTableManager
  get attendanceGroupMembersRefs {
    final manager = $$AttendanceGroupMembersTableTableManager(
      $_db,
      $_db.attendanceGroupMembers,
    ).filter((f) => f.attendanceGroupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attendanceGroupMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MonthlyAttendanceRostersTable,
    List<MonthlyAttendanceRoster>
  >
  _monthlyAttendanceRostersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.monthlyAttendanceRosters,
        aliasName: 'attendance_groups__id__monthly_attendance_rosters__attendance_group_id',
      );

  $$MonthlyAttendanceRostersTableProcessedTableManager
  get monthlyAttendanceRostersRefs {
    final manager = $$MonthlyAttendanceRostersTableTableManager(
      $_db,
      $_db.monthlyAttendanceRosters,
    ).filter((f) => f.attendanceGroupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _monthlyAttendanceRostersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MonthlyAttendanceSummariesTable,
    List<MonthlyAttendanceSummary>
  >
  _monthlyAttendanceSummariesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.monthlyAttendanceSummaries,
        aliasName: 'attendance_groups__id__monthly_attendance_summaries__attendance_group_id',
      );

  $$MonthlyAttendanceSummariesTableProcessedTableManager
  get monthlyAttendanceSummariesRefs {
    final manager = $$MonthlyAttendanceSummariesTableTableManager(
      $_db,
      $_db.monthlyAttendanceSummaries,
    ).filter((f) => f.attendanceGroupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _monthlyAttendanceSummariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AttendanceGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceGroupsTable> {
  $$AttendanceGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupType => $composableBuilder(
    column: $table.groupType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> employeesRefs(
    Expression<bool> Function($$EmployeesTableFilterComposer f) f,
  ) {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.defaultAttendanceGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attendanceGroupMembersRefs(
    Expression<bool> Function($$AttendanceGroupMembersTableFilterComposer f) f,
  ) {
    final $$AttendanceGroupMembersTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceGroupMembers,
          getReferencedColumn: (t) => t.attendanceGroupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceGroupMembersTableFilterComposer(
                $db: $db,
                $table: $db.attendanceGroupMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> monthlyAttendanceRostersRefs(
    Expression<bool> Function($$MonthlyAttendanceRostersTableFilterComposer f)
    f,
  ) {
    final $$MonthlyAttendanceRostersTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.monthlyAttendanceRosters,
          getReferencedColumn: (t) => t.attendanceGroupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MonthlyAttendanceRostersTableFilterComposer(
                $db: $db,
                $table: $db.monthlyAttendanceRosters,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> monthlyAttendanceSummariesRefs(
    Expression<bool> Function($$MonthlyAttendanceSummariesTableFilterComposer f)
    f,
  ) {
    final $$MonthlyAttendanceSummariesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.monthlyAttendanceSummaries,
          getReferencedColumn: (t) => t.attendanceGroupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MonthlyAttendanceSummariesTableFilterComposer(
                $db: $db,
                $table: $db.monthlyAttendanceSummaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AttendanceGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceGroupsTable> {
  $$AttendanceGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupType => $composableBuilder(
    column: $table.groupType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttendanceGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceGroupsTable> {
  $$AttendanceGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get groupType =>
      $composableBuilder(column: $table.groupType, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  Expression<T> employeesRefs<T extends Object>(
    Expression<T> Function($$EmployeesTableAnnotationComposer a) f,
  ) {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.defaultAttendanceGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attendanceGroupMembersRefs<T extends Object>(
    Expression<T> Function($$AttendanceGroupMembersTableAnnotationComposer a) f,
  ) {
    final $$AttendanceGroupMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceGroupMembers,
          getReferencedColumn: (t) => t.attendanceGroupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceGroupMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceGroupMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> monthlyAttendanceRostersRefs<T extends Object>(
    Expression<T> Function($$MonthlyAttendanceRostersTableAnnotationComposer a)
    f,
  ) {
    final $$MonthlyAttendanceRostersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.monthlyAttendanceRosters,
          getReferencedColumn: (t) => t.attendanceGroupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MonthlyAttendanceRostersTableAnnotationComposer(
                $db: $db,
                $table: $db.monthlyAttendanceRosters,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> monthlyAttendanceSummariesRefs<T extends Object>(
    Expression<T> Function(
      $$MonthlyAttendanceSummariesTableAnnotationComposer a,
    )
    f,
  ) {
    final $$MonthlyAttendanceSummariesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.monthlyAttendanceSummaries,
          getReferencedColumn: (t) => t.attendanceGroupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MonthlyAttendanceSummariesTableAnnotationComposer(
                $db: $db,
                $table: $db.monthlyAttendanceSummaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AttendanceGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceGroupsTable,
          AttendanceGroup,
          $$AttendanceGroupsTableFilterComposer,
          $$AttendanceGroupsTableOrderingComposer,
          $$AttendanceGroupsTableAnnotationComposer,
          $$AttendanceGroupsTableCreateCompanionBuilder,
          $$AttendanceGroupsTableUpdateCompanionBuilder,
          (AttendanceGroup, $$AttendanceGroupsTableReferences),
          AttendanceGroup,
          PrefetchHooks Function({
            bool employeesRefs,
            bool attendanceGroupMembersRefs,
            bool monthlyAttendanceRostersRefs,
            bool monthlyAttendanceSummariesRefs,
          })
        > {
  $$AttendanceGroupsTableTableManager(
    _$AppDatabase db,
    $AttendanceGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> groupType = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => AttendanceGroupsCompanion(
                id: id,
                name: name,
                groupType: groupType,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> groupType = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => AttendanceGroupsCompanion.insert(
                id: id,
                name: name,
                groupType: groupType,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttendanceGroupsTable, AttendanceGroup>(table),
                  $$AttendanceGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                employeesRefs = false,
                attendanceGroupMembersRefs = false,
                monthlyAttendanceRostersRefs = false,
                monthlyAttendanceSummariesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (employeesRefs) db.employees,
                    if (attendanceGroupMembersRefs) db.attendanceGroupMembers,
                    if (monthlyAttendanceRostersRefs)
                      db.monthlyAttendanceRosters,
                    if (monthlyAttendanceSummariesRefs)
                      db.monthlyAttendanceSummaries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (employeesRefs)
                        await $_getPrefetchedData<
                          AttendanceGroup,
                          $AttendanceGroupsTable,
                          Employee
                        >(
                          currentTable: table,
                          referencedTable: $$AttendanceGroupsTableReferences
                              ._employeesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AttendanceGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).employeesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.defaultAttendanceGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attendanceGroupMembersRefs)
                        await $_getPrefetchedData<
                          AttendanceGroup,
                          $AttendanceGroupsTable,
                          AttendanceGroupMember
                        >(
                          currentTable: table,
                          referencedTable: $$AttendanceGroupsTableReferences
                              ._attendanceGroupMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AttendanceGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).attendanceGroupMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.attendanceGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (monthlyAttendanceRostersRefs)
                        await $_getPrefetchedData<
                          AttendanceGroup,
                          $AttendanceGroupsTable,
                          MonthlyAttendanceRoster
                        >(
                          currentTable: table,
                          referencedTable: $$AttendanceGroupsTableReferences
                              ._monthlyAttendanceRostersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AttendanceGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).monthlyAttendanceRostersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.attendanceGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (monthlyAttendanceSummariesRefs)
                        await $_getPrefetchedData<
                          AttendanceGroup,
                          $AttendanceGroupsTable,
                          MonthlyAttendanceSummary
                        >(
                          currentTable: table,
                          referencedTable: $$AttendanceGroupsTableReferences
                              ._monthlyAttendanceSummariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AttendanceGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).monthlyAttendanceSummariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.attendanceGroupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AttendanceGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceGroupsTable,
      AttendanceGroup,
      $$AttendanceGroupsTableFilterComposer,
      $$AttendanceGroupsTableOrderingComposer,
      $$AttendanceGroupsTableAnnotationComposer,
      $$AttendanceGroupsTableCreateCompanionBuilder,
      $$AttendanceGroupsTableUpdateCompanionBuilder,
      (AttendanceGroup, $$AttendanceGroupsTableReferences),
      AttendanceGroup,
      PrefetchHooks Function({
        bool employeesRefs,
        bool attendanceGroupMembersRefs,
        bool monthlyAttendanceRostersRefs,
        bool monthlyAttendanceSummariesRefs,
      })
    >;
typedef $$EmployeesTableCreateCompanionBuilder = EmployeesCompanion Function({
  Value<int> id,
  required String employeeNo,
  required String name,
  Value<String?> gender,
  Value<String?> idCardNumber,
  Value<DateTime?> birthDate,
  Value<String?> phone,
  Value<String?> address,
  required DateTime hireDate,
  Value<EmployeeStatus> status,
  Value<String?> position,
  Value<String?> team,
  Value<String?> workArea,
  Value<String?> manager,
  Value<String?> employmentType,
  Value<int?> defaultAttendanceGroupId,
  Value<String?> remark,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> isDeleted,
});
typedef $$EmployeesTableUpdateCompanionBuilder = EmployeesCompanion Function({
  Value<int> id,
  Value<String> employeeNo,
  Value<String> name,
  Value<String?> gender,
  Value<String?> idCardNumber,
  Value<DateTime?> birthDate,
  Value<String?> phone,
  Value<String?> address,
  Value<DateTime> hireDate,
  Value<EmployeeStatus> status,
  Value<String?> position,
  Value<String?> team,
  Value<String?> workArea,
  Value<String?> manager,
  Value<String?> employmentType,
  Value<int?> defaultAttendanceGroupId,
  Value<String?> remark,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> isDeleted,
});

final class $$EmployeesTableReferences
    extends BaseReferences<_$AppDatabase, $EmployeesTable, Employee> {
  $$EmployeesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AttendanceGroupsTable _defaultAttendanceGroupIdTable(
    _$AppDatabase db,
  ) => db.attendanceGroups.createAlias(
    'employees__default_attendance_group_id__attendance_groups__id',
  );

  $$AttendanceGroupsTableProcessedTableManager? get defaultAttendanceGroupId {
    final $_column = $_itemColumn<int>('default_attendance_group_id');
    if ($_column == null) return null;
    final manager = $$AttendanceGroupsTableTableManager(
      $_db,
      $_db.attendanceGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _defaultAttendanceGroupIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $AttendanceGroupMembersTable,
    List<AttendanceGroupMember>
  >
  _attendanceGroupMembersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.attendanceGroupMembers,
        aliasName: 'employees__id__attendance_group_members__employee_id',
      );

  $$AttendanceGroupMembersTableProcessedTableManager
  get attendanceGroupMembersRefs {
    final manager = $$AttendanceGroupMembersTableTableManager(
      $_db,
      $_db.attendanceGroupMembers,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attendanceGroupMembersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MonthlyAttendanceRostersTable,
    List<MonthlyAttendanceRoster>
  >
  _monthlyAttendanceRostersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.monthlyAttendanceRosters,
        aliasName: 'employees__id__monthly_attendance_rosters__employee_id',
      );

  $$MonthlyAttendanceRostersTableProcessedTableManager
  get monthlyAttendanceRostersRefs {
    final manager = $$MonthlyAttendanceRostersTableTableManager(
      $_db,
      $_db.monthlyAttendanceRosters,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _monthlyAttendanceRostersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttendanceRecordsTable, List<AttendanceRecord>>
  _attendanceRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.attendanceRecords,
        aliasName: 'employees__id__attendance_records__employee_id',
      );

  $$AttendanceRecordsTableProcessedTableManager get attendanceRecordsRefs {
    final manager = $$AttendanceRecordsTableTableManager(
      $_db,
      $_db.attendanceRecords,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _attendanceRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LeaveRecordsTable, List<LeaveRecord>>
  _leaveRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.leaveRecords,
    aliasName: 'employees__id__leave_records__employee_id',
  );

  $$LeaveRecordsTableProcessedTableManager get leaveRecordsRefs {
    final manager = $$LeaveRecordsTableTableManager(
      $_db,
      $_db.leaveRecords,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_leaveRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OvertimeRecordsTable, List<OvertimeRecord>>
  _overtimeRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.overtimeRecords,
    aliasName: 'employees__id__overtime_records__employee_id',
  );

  $$OvertimeRecordsTableProcessedTableManager get overtimeRecordsRefs {
    final manager = $$OvertimeRecordsTableTableManager(
      $_db,
      $_db.overtimeRecords,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _overtimeRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TerminationRecordsTable, List<TerminationRecord>>
  _terminationRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.terminationRecords,
        aliasName: 'employees__id__termination_records__employee_id',
      );

  $$TerminationRecordsTableProcessedTableManager get terminationRecordsRefs {
    final manager = $$TerminationRecordsTableTableManager(
      $_db,
      $_db.terminationRecords,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _terminationRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MonthlyAttendanceSummariesTable,
    List<MonthlyAttendanceSummary>
  >
  _monthlyAttendanceSummariesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.monthlyAttendanceSummaries,
        aliasName: 'employees__id__monthly_attendance_summaries__employee_id',
      );

  $$MonthlyAttendanceSummariesTableProcessedTableManager
  get monthlyAttendanceSummariesRefs {
    final manager = $$MonthlyAttendanceSummariesTableTableManager(
      $_db,
      $_db.monthlyAttendanceSummaries,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _monthlyAttendanceSummariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InsuranceProfilesTable, List<InsuranceProfile>>
  _insuranceProfilesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.insuranceProfiles,
        aliasName: 'employees__id__insurance_profiles__employee_id',
      );

  $$InsuranceProfilesTableProcessedTableManager get insuranceProfilesRefs {
    final manager = $$InsuranceProfilesTableTableManager(
      $_db,
      $_db.insuranceProfiles,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _insuranceProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $InsuranceChangeRecordsTable,
    List<InsuranceChangeRecord>
  >
  _insuranceChangeRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.insuranceChangeRecords,
        aliasName: 'employees__id__insurance_change_records__employee_id',
      );

  $$InsuranceChangeRecordsTableProcessedTableManager
  get insuranceChangeRecordsRefs {
    final manager = $$InsuranceChangeRecordsTableTableManager(
      $_db,
      $_db.insuranceChangeRecords,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _insuranceChangeRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $SocialSecurityBaseHistoryTable,
    List<SocialSecurityBaseHistoryData>
  >
  _socialSecurityBaseHistoryRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.socialSecurityBaseHistory,
        aliasName: 'employees__id__social_security_base_history__employee_id',
      );

  $$SocialSecurityBaseHistoryTableProcessedTableManager
  get socialSecurityBaseHistoryRefs {
    final manager = $$SocialSecurityBaseHistoryTableTableManager(
      $_db,
      $_db.socialSecurityBaseHistory,
    ).filter((f) => f.employeeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _socialSecurityBaseHistoryRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EmployeesTableFilterComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employeeNo => $composableBuilder(
    column: $table.employeeNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idCardNumber => $composableBuilder(
    column: $table.idCardNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get hireDate => $composableBuilder(
    column: $table.hireDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<EmployeeStatus, EmployeeStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get team => $composableBuilder(
    column: $table.team,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workArea => $composableBuilder(
    column: $table.workArea,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manager => $composableBuilder(
    column: $table.manager,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get employmentType => $composableBuilder(
    column: $table.employmentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$AttendanceGroupsTableFilterComposer get defaultAttendanceGroupId {
    final $$AttendanceGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAttendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> attendanceGroupMembersRefs(
    Expression<bool> Function($$AttendanceGroupMembersTableFilterComposer f) f,
  ) {
    final $$AttendanceGroupMembersTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceGroupMembers,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceGroupMembersTableFilterComposer(
                $db: $db,
                $table: $db.attendanceGroupMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> monthlyAttendanceRostersRefs(
    Expression<bool> Function($$MonthlyAttendanceRostersTableFilterComposer f)
    f,
  ) {
    final $$MonthlyAttendanceRostersTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.monthlyAttendanceRosters,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MonthlyAttendanceRostersTableFilterComposer(
                $db: $db,
                $table: $db.monthlyAttendanceRosters,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> attendanceRecordsRefs(
    Expression<bool> Function($$AttendanceRecordsTableFilterComposer f) f,
  ) {
    final $$AttendanceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attendanceRecords,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> leaveRecordsRefs(
    Expression<bool> Function($$LeaveRecordsTableFilterComposer f) f,
  ) {
    final $$LeaveRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.leaveRecords,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LeaveRecordsTableFilterComposer(
            $db: $db,
            $table: $db.leaveRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> overtimeRecordsRefs(
    Expression<bool> Function($$OvertimeRecordsTableFilterComposer f) f,
  ) {
    final $$OvertimeRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.overtimeRecords,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeRecordsTableFilterComposer(
            $db: $db,
            $table: $db.overtimeRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> terminationRecordsRefs(
    Expression<bool> Function($$TerminationRecordsTableFilterComposer f) f,
  ) {
    final $$TerminationRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.terminationRecords,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TerminationRecordsTableFilterComposer(
            $db: $db,
            $table: $db.terminationRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> monthlyAttendanceSummariesRefs(
    Expression<bool> Function($$MonthlyAttendanceSummariesTableFilterComposer f)
    f,
  ) {
    final $$MonthlyAttendanceSummariesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.monthlyAttendanceSummaries,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MonthlyAttendanceSummariesTableFilterComposer(
                $db: $db,
                $table: $db.monthlyAttendanceSummaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> insuranceProfilesRefs(
    Expression<bool> Function($$InsuranceProfilesTableFilterComposer f) f,
  ) {
    final $$InsuranceProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.insuranceProfiles,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InsuranceProfilesTableFilterComposer(
            $db: $db,
            $table: $db.insuranceProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> insuranceChangeRecordsRefs(
    Expression<bool> Function($$InsuranceChangeRecordsTableFilterComposer f) f,
  ) {
    final $$InsuranceChangeRecordsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.insuranceChangeRecords,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InsuranceChangeRecordsTableFilterComposer(
                $db: $db,
                $table: $db.insuranceChangeRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> socialSecurityBaseHistoryRefs(
    Expression<bool> Function($$SocialSecurityBaseHistoryTableFilterComposer f)
    f,
  ) {
    final $$SocialSecurityBaseHistoryTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.socialSecurityBaseHistory,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SocialSecurityBaseHistoryTableFilterComposer(
                $db: $db,
                $table: $db.socialSecurityBaseHistory,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EmployeesTableOrderingComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employeeNo => $composableBuilder(
    column: $table.employeeNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idCardNumber => $composableBuilder(
    column: $table.idCardNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get hireDate => $composableBuilder(
    column: $table.hireDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get team => $composableBuilder(
    column: $table.team,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workArea => $composableBuilder(
    column: $table.workArea,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manager => $composableBuilder(
    column: $table.manager,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get employmentType => $composableBuilder(
    column: $table.employmentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$AttendanceGroupsTableOrderingComposer get defaultAttendanceGroupId {
    final $$AttendanceGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAttendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EmployeesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmployeesTable> {
  $$EmployeesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get employeeNo => $composableBuilder(
    column: $table.employeeNo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<String> get idCardNumber => $composableBuilder(
    column: $table.idCardNumber,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<DateTime> get hireDate =>
      $composableBuilder(column: $table.hireDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<EmployeeStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get team =>
      $composableBuilder(column: $table.team, builder: (column) => column);

  GeneratedColumn<String> get workArea =>
      $composableBuilder(column: $table.workArea, builder: (column) => column);

  GeneratedColumn<String> get manager =>
      $composableBuilder(column: $table.manager, builder: (column) => column);

  GeneratedColumn<String> get employmentType => $composableBuilder(
    column: $table.employmentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$AttendanceGroupsTableAnnotationComposer get defaultAttendanceGroupId {
    final $$AttendanceGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.defaultAttendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> attendanceGroupMembersRefs<T extends Object>(
    Expression<T> Function($$AttendanceGroupMembersTableAnnotationComposer a) f,
  ) {
    final $$AttendanceGroupMembersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceGroupMembers,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceGroupMembersTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceGroupMembers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> monthlyAttendanceRostersRefs<T extends Object>(
    Expression<T> Function($$MonthlyAttendanceRostersTableAnnotationComposer a)
    f,
  ) {
    final $$MonthlyAttendanceRostersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.monthlyAttendanceRosters,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MonthlyAttendanceRostersTableAnnotationComposer(
                $db: $db,
                $table: $db.monthlyAttendanceRosters,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> attendanceRecordsRefs<T extends Object>(
    Expression<T> Function($$AttendanceRecordsTableAnnotationComposer a) f,
  ) {
    final $$AttendanceRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.attendanceRecords,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AttendanceRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.attendanceRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> leaveRecordsRefs<T extends Object>(
    Expression<T> Function($$LeaveRecordsTableAnnotationComposer a) f,
  ) {
    final $$LeaveRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.leaveRecords,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LeaveRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.leaveRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> overtimeRecordsRefs<T extends Object>(
    Expression<T> Function($$OvertimeRecordsTableAnnotationComposer a) f,
  ) {
    final $$OvertimeRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.overtimeRecords,
      getReferencedColumn: (t) => t.employeeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OvertimeRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.overtimeRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> terminationRecordsRefs<T extends Object>(
    Expression<T> Function($$TerminationRecordsTableAnnotationComposer a) f,
  ) {
    final $$TerminationRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.terminationRecords,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TerminationRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.terminationRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> monthlyAttendanceSummariesRefs<T extends Object>(
    Expression<T> Function(
      $$MonthlyAttendanceSummariesTableAnnotationComposer a,
    )
    f,
  ) {
    final $$MonthlyAttendanceSummariesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.monthlyAttendanceSummaries,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MonthlyAttendanceSummariesTableAnnotationComposer(
                $db: $db,
                $table: $db.monthlyAttendanceSummaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> insuranceProfilesRefs<T extends Object>(
    Expression<T> Function($$InsuranceProfilesTableAnnotationComposer a) f,
  ) {
    final $$InsuranceProfilesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.insuranceProfiles,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InsuranceProfilesTableAnnotationComposer(
                $db: $db,
                $table: $db.insuranceProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> insuranceChangeRecordsRefs<T extends Object>(
    Expression<T> Function($$InsuranceChangeRecordsTableAnnotationComposer a) f,
  ) {
    final $$InsuranceChangeRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.insuranceChangeRecords,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InsuranceChangeRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.insuranceChangeRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> socialSecurityBaseHistoryRefs<T extends Object>(
    Expression<T> Function($$SocialSecurityBaseHistoryTableAnnotationComposer a)
    f,
  ) {
    final $$SocialSecurityBaseHistoryTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.socialSecurityBaseHistory,
          getReferencedColumn: (t) => t.employeeId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SocialSecurityBaseHistoryTableAnnotationComposer(
                $db: $db,
                $table: $db.socialSecurityBaseHistory,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EmployeesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmployeesTable,
          Employee,
          $$EmployeesTableFilterComposer,
          $$EmployeesTableOrderingComposer,
          $$EmployeesTableAnnotationComposer,
          $$EmployeesTableCreateCompanionBuilder,
          $$EmployeesTableUpdateCompanionBuilder,
          (Employee, $$EmployeesTableReferences),
          Employee,
          PrefetchHooks Function({
            bool defaultAttendanceGroupId,
            bool attendanceGroupMembersRefs,
            bool monthlyAttendanceRostersRefs,
            bool attendanceRecordsRefs,
            bool leaveRecordsRefs,
            bool overtimeRecordsRefs,
            bool terminationRecordsRefs,
            bool monthlyAttendanceSummariesRefs,
            bool insuranceProfilesRefs,
            bool insuranceChangeRecordsRefs,
            bool socialSecurityBaseHistoryRefs,
          })
        > {
  $$EmployeesTableTableManager(_$AppDatabase db, $EmployeesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmployeesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmployeesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmployeesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> employeeNo = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<String?> idCardNumber = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<DateTime> hireDate = const Value.absent(),
                Value<EmployeeStatus> status = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<String?> team = const Value.absent(),
                Value<String?> workArea = const Value.absent(),
                Value<String?> manager = const Value.absent(),
                Value<String?> employmentType = const Value.absent(),
                Value<int?> defaultAttendanceGroupId = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => EmployeesCompanion(
                id: id,
                employeeNo: employeeNo,
                name: name,
                gender: gender,
                idCardNumber: idCardNumber,
                birthDate: birthDate,
                phone: phone,
                address: address,
                hireDate: hireDate,
                status: status,
                position: position,
                team: team,
                workArea: workArea,
                manager: manager,
                employmentType: employmentType,
                defaultAttendanceGroupId: defaultAttendanceGroupId,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String employeeNo,
                required String name,
                Value<String?> gender = const Value.absent(),
                Value<String?> idCardNumber = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                required DateTime hireDate,
                Value<EmployeeStatus> status = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<String?> team = const Value.absent(),
                Value<String?> workArea = const Value.absent(),
                Value<String?> manager = const Value.absent(),
                Value<String?> employmentType = const Value.absent(),
                Value<int?> defaultAttendanceGroupId = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => EmployeesCompanion.insert(
                id: id,
                employeeNo: employeeNo,
                name: name,
                gender: gender,
                idCardNumber: idCardNumber,
                birthDate: birthDate,
                phone: phone,
                address: address,
                hireDate: hireDate,
                status: status,
                position: position,
                team: team,
                workArea: workArea,
                manager: manager,
                employmentType: employmentType,
                defaultAttendanceGroupId: defaultAttendanceGroupId,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EmployeesTable, Employee>(table),
                  $$EmployeesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                defaultAttendanceGroupId = false,
                attendanceGroupMembersRefs = false,
                monthlyAttendanceRostersRefs = false,
                attendanceRecordsRefs = false,
                leaveRecordsRefs = false,
                overtimeRecordsRefs = false,
                terminationRecordsRefs = false,
                monthlyAttendanceSummariesRefs = false,
                insuranceProfilesRefs = false,
                insuranceChangeRecordsRefs = false,
                socialSecurityBaseHistoryRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (attendanceGroupMembersRefs) db.attendanceGroupMembers,
                    if (monthlyAttendanceRostersRefs)
                      db.monthlyAttendanceRosters,
                    if (attendanceRecordsRefs) db.attendanceRecords,
                    if (leaveRecordsRefs) db.leaveRecords,
                    if (overtimeRecordsRefs) db.overtimeRecords,
                    if (terminationRecordsRefs) db.terminationRecords,
                    if (monthlyAttendanceSummariesRefs)
                      db.monthlyAttendanceSummaries,
                    if (insuranceProfilesRefs) db.insuranceProfiles,
                    if (insuranceChangeRecordsRefs) db.insuranceChangeRecords,
                    if (socialSecurityBaseHistoryRefs)
                      db.socialSecurityBaseHistory,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (defaultAttendanceGroupId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.defaultAttendanceGroupId,
                            referencedTable: $$EmployeesTableReferences
                                ._defaultAttendanceGroupIdTable(db),
                            referencedColumn: $$EmployeesTableReferences
                                ._defaultAttendanceGroupIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (attendanceGroupMembersRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          AttendanceGroupMember
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._attendanceGroupMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).attendanceGroupMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (monthlyAttendanceRostersRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          MonthlyAttendanceRoster
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._monthlyAttendanceRostersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).monthlyAttendanceRostersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (attendanceRecordsRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          AttendanceRecord
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._attendanceRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).attendanceRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (leaveRecordsRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          LeaveRecord
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._leaveRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).leaveRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (overtimeRecordsRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          OvertimeRecord
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._overtimeRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).overtimeRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (terminationRecordsRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          TerminationRecord
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._terminationRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).terminationRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (monthlyAttendanceSummariesRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          MonthlyAttendanceSummary
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._monthlyAttendanceSummariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).monthlyAttendanceSummariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (insuranceProfilesRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          InsuranceProfile
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._insuranceProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).insuranceProfilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (insuranceChangeRecordsRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          InsuranceChangeRecord
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._insuranceChangeRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).insuranceChangeRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (socialSecurityBaseHistoryRefs)
                        await $_getPrefetchedData<
                          Employee,
                          $EmployeesTable,
                          SocialSecurityBaseHistoryData
                        >(
                          currentTable: table,
                          referencedTable: $$EmployeesTableReferences
                              ._socialSecurityBaseHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EmployeesTableReferences(
                                db,
                                table,
                                p0,
                              ).socialSecurityBaseHistoryRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.employeeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EmployeesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmployeesTable,
      Employee,
      $$EmployeesTableFilterComposer,
      $$EmployeesTableOrderingComposer,
      $$EmployeesTableAnnotationComposer,
      $$EmployeesTableCreateCompanionBuilder,
      $$EmployeesTableUpdateCompanionBuilder,
      (Employee, $$EmployeesTableReferences),
      Employee,
      PrefetchHooks Function({
        bool defaultAttendanceGroupId,
        bool attendanceGroupMembersRefs,
        bool monthlyAttendanceRostersRefs,
        bool attendanceRecordsRefs,
        bool leaveRecordsRefs,
        bool overtimeRecordsRefs,
        bool terminationRecordsRefs,
        bool monthlyAttendanceSummariesRefs,
        bool insuranceProfilesRefs,
        bool insuranceChangeRecordsRefs,
        bool socialSecurityBaseHistoryRefs,
      })
    >;
typedef $$AttendanceGroupMembersTableCreateCompanionBuilder =
    AttendanceGroupMembersCompanion Function({
      Value<int> id,
      required int attendanceGroupId,
      required int employeeId,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$AttendanceGroupMembersTableUpdateCompanionBuilder =
    AttendanceGroupMembersCompanion Function({
      Value<int> id,
      Value<int> attendanceGroupId,
      Value<int> employeeId,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$AttendanceGroupMembersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AttendanceGroupMembersTable,
          AttendanceGroupMember
        > {
  $$AttendanceGroupMembersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AttendanceGroupsTable _attendanceGroupIdTable(_$AppDatabase db) =>
      db.attendanceGroups.createAlias(
        'attendance_group_members__attendance_group_id__attendance_groups__id',
      );

  $$AttendanceGroupsTableProcessedTableManager get attendanceGroupId {
    final $_column = $_itemColumn<int>('attendance_group_id')!;

    final manager = $$AttendanceGroupsTableTableManager(
      $_db,
      $_db.attendanceGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attendanceGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('attendance_group_members__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttendanceGroupMembersTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceGroupMembersTable> {
  $$AttendanceGroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$AttendanceGroupsTableFilterComposer get attendanceGroupId {
    final $$AttendanceGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceGroupMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceGroupMembersTable> {
  $$AttendanceGroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$AttendanceGroupsTableOrderingComposer get attendanceGroupId {
    final $$AttendanceGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceGroupMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceGroupMembersTable> {
  $$AttendanceGroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$AttendanceGroupsTableAnnotationComposer get attendanceGroupId {
    final $$AttendanceGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceGroupMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceGroupMembersTable,
          AttendanceGroupMember,
          $$AttendanceGroupMembersTableFilterComposer,
          $$AttendanceGroupMembersTableOrderingComposer,
          $$AttendanceGroupMembersTableAnnotationComposer,
          $$AttendanceGroupMembersTableCreateCompanionBuilder,
          $$AttendanceGroupMembersTableUpdateCompanionBuilder,
          (AttendanceGroupMember, $$AttendanceGroupMembersTableReferences),
          AttendanceGroupMember,
          PrefetchHooks Function({bool attendanceGroupId, bool employeeId})
        > {
  $$AttendanceGroupMembersTableTableManager(
    _$AppDatabase db,
    $AttendanceGroupMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceGroupMembersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$AttendanceGroupMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AttendanceGroupMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> attendanceGroupId = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => AttendanceGroupMembersCompanion(
                id: id,
                attendanceGroupId: attendanceGroupId,
                employeeId: employeeId,
                isDefault: isDefault,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int attendanceGroupId,
                required int employeeId,
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => AttendanceGroupMembersCompanion.insert(
                id: id,
                attendanceGroupId: attendanceGroupId,
                employeeId: employeeId,
                isDefault: isDefault,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $AttendanceGroupMembersTable,
                    AttendanceGroupMember
                  >(table),
                  $$AttendanceGroupMembersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({attendanceGroupId = false, employeeId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (attendanceGroupId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.attendanceGroupId,
                            referencedTable:
                                $$AttendanceGroupMembersTableReferences
                                    ._attendanceGroupIdTable(db),
                            referencedColumn:
                                $$AttendanceGroupMembersTableReferences
                                    ._attendanceGroupIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (employeeId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.employeeId,
                            referencedTable:
                                $$AttendanceGroupMembersTableReferences
                                    ._employeeIdTable(db),
                            referencedColumn:
                                $$AttendanceGroupMembersTableReferences
                                    ._employeeIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$AttendanceGroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceGroupMembersTable,
      AttendanceGroupMember,
      $$AttendanceGroupMembersTableFilterComposer,
      $$AttendanceGroupMembersTableOrderingComposer,
      $$AttendanceGroupMembersTableAnnotationComposer,
      $$AttendanceGroupMembersTableCreateCompanionBuilder,
      $$AttendanceGroupMembersTableUpdateCompanionBuilder,
      (AttendanceGroupMember, $$AttendanceGroupMembersTableReferences),
      AttendanceGroupMember,
      PrefetchHooks Function({bool attendanceGroupId, bool employeeId})
    >;
typedef $$MonthlyAttendanceRostersTableCreateCompanionBuilder =
    MonthlyAttendanceRostersCompanion Function({
      Value<int> id,
      required String yearMonth,
      required int attendanceGroupId,
      required int employeeId,
      Value<bool> isActive,
      Value<String> source,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$MonthlyAttendanceRostersTableUpdateCompanionBuilder =
    MonthlyAttendanceRostersCompanion Function({
      Value<int> id,
      Value<String> yearMonth,
      Value<int> attendanceGroupId,
      Value<int> employeeId,
      Value<bool> isActive,
      Value<String> source,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$MonthlyAttendanceRostersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MonthlyAttendanceRostersTable,
          MonthlyAttendanceRoster
        > {
  $$MonthlyAttendanceRostersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AttendanceGroupsTable _attendanceGroupIdTable(
    _$AppDatabase db,
  ) => db.attendanceGroups.createAlias(
    'monthly_attendance_rosters__attendance_group_id__attendance_groups__id',
  );

  $$AttendanceGroupsTableProcessedTableManager get attendanceGroupId {
    final $_column = $_itemColumn<int>('attendance_group_id')!;

    final manager = $$AttendanceGroupsTableTableManager(
      $_db,
      $_db.attendanceGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attendanceGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('monthly_attendance_rosters__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MonthlyAttendanceRostersTableFilterComposer
    extends Composer<_$AppDatabase, $MonthlyAttendanceRostersTable> {
  $$MonthlyAttendanceRostersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get yearMonth => $composableBuilder(
    column: $table.yearMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$AttendanceGroupsTableFilterComposer get attendanceGroupId {
    final $$AttendanceGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyAttendanceRostersTableOrderingComposer
    extends Composer<_$AppDatabase, $MonthlyAttendanceRostersTable> {
  $$MonthlyAttendanceRostersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get yearMonth => $composableBuilder(
    column: $table.yearMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$AttendanceGroupsTableOrderingComposer get attendanceGroupId {
    final $$AttendanceGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyAttendanceRostersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonthlyAttendanceRostersTable> {
  $$MonthlyAttendanceRostersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get yearMonth =>
      $composableBuilder(column: $table.yearMonth, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$AttendanceGroupsTableAnnotationComposer get attendanceGroupId {
    final $$AttendanceGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyAttendanceRostersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonthlyAttendanceRostersTable,
          MonthlyAttendanceRoster,
          $$MonthlyAttendanceRostersTableFilterComposer,
          $$MonthlyAttendanceRostersTableOrderingComposer,
          $$MonthlyAttendanceRostersTableAnnotationComposer,
          $$MonthlyAttendanceRostersTableCreateCompanionBuilder,
          $$MonthlyAttendanceRostersTableUpdateCompanionBuilder,
          (MonthlyAttendanceRoster, $$MonthlyAttendanceRostersTableReferences),
          MonthlyAttendanceRoster,
          PrefetchHooks Function({bool attendanceGroupId, bool employeeId})
        > {
  $$MonthlyAttendanceRostersTableTableManager(
    _$AppDatabase db,
    $MonthlyAttendanceRostersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthlyAttendanceRostersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MonthlyAttendanceRostersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MonthlyAttendanceRostersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> yearMonth = const Value.absent(),
                Value<int> attendanceGroupId = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => MonthlyAttendanceRostersCompanion(
                id: id,
                yearMonth: yearMonth,
                attendanceGroupId: attendanceGroupId,
                employeeId: employeeId,
                isActive: isActive,
                source: source,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String yearMonth,
                required int attendanceGroupId,
                required int employeeId,
                Value<bool> isActive = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => MonthlyAttendanceRostersCompanion.insert(
                id: id,
                yearMonth: yearMonth,
                attendanceGroupId: attendanceGroupId,
                employeeId: employeeId,
                isActive: isActive,
                source: source,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MonthlyAttendanceRostersTable,
                    MonthlyAttendanceRoster
                  >(table),
                  $$MonthlyAttendanceRostersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({attendanceGroupId = false, employeeId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (attendanceGroupId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.attendanceGroupId,
                            referencedTable:
                                $$MonthlyAttendanceRostersTableReferences
                                    ._attendanceGroupIdTable(db),
                            referencedColumn:
                                $$MonthlyAttendanceRostersTableReferences
                                    ._attendanceGroupIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (employeeId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.employeeId,
                            referencedTable:
                                $$MonthlyAttendanceRostersTableReferences
                                    ._employeeIdTable(db),
                            referencedColumn:
                                $$MonthlyAttendanceRostersTableReferences
                                    ._employeeIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$MonthlyAttendanceRostersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonthlyAttendanceRostersTable,
      MonthlyAttendanceRoster,
      $$MonthlyAttendanceRostersTableFilterComposer,
      $$MonthlyAttendanceRostersTableOrderingComposer,
      $$MonthlyAttendanceRostersTableAnnotationComposer,
      $$MonthlyAttendanceRostersTableCreateCompanionBuilder,
      $$MonthlyAttendanceRostersTableUpdateCompanionBuilder,
      (MonthlyAttendanceRoster, $$MonthlyAttendanceRostersTableReferences),
      MonthlyAttendanceRoster,
      PrefetchHooks Function({bool attendanceGroupId, bool employeeId})
    >;
typedef $$AttendanceRecordsTableCreateCompanionBuilder =
    AttendanceRecordsCompanion Function({
      Value<int> id,
      required int employeeId,
      required DateTime attendanceDate,
      Value<AttendanceHalfStatus> morningStatus,
      Value<AttendanceHalfStatus> afternoonStatus,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$AttendanceRecordsTableUpdateCompanionBuilder =
    AttendanceRecordsCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<DateTime> attendanceDate,
      Value<AttendanceHalfStatus> morningStatus,
      Value<AttendanceHalfStatus> afternoonStatus,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$AttendanceRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AttendanceRecordsTable,
          AttendanceRecord
        > {
  $$AttendanceRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('attendance_records__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttendanceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    AttendanceHalfStatus,
    AttendanceHalfStatus,
    String
  >
  get morningStatus => $composableBuilder(
    column: $table.morningStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    AttendanceHalfStatus,
    AttendanceHalfStatus,
    String
  >
  get afternoonStatus => $composableBuilder(
    column: $table.afternoonStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get morningStatus => $composableBuilder(
    column: $table.morningStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afternoonStatus => $composableBuilder(
    column: $table.afternoonStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttendanceRecordsTable> {
  $$AttendanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get attendanceDate => $composableBuilder(
    column: $table.attendanceDate,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AttendanceHalfStatus, String>
  get morningStatus => $composableBuilder(
    column: $table.morningStatus,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AttendanceHalfStatus, String>
  get afternoonStatus => $composableBuilder(
    column: $table.afternoonStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttendanceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttendanceRecordsTable,
          AttendanceRecord,
          $$AttendanceRecordsTableFilterComposer,
          $$AttendanceRecordsTableOrderingComposer,
          $$AttendanceRecordsTableAnnotationComposer,
          $$AttendanceRecordsTableCreateCompanionBuilder,
          $$AttendanceRecordsTableUpdateCompanionBuilder,
          (AttendanceRecord, $$AttendanceRecordsTableReferences),
          AttendanceRecord,
          PrefetchHooks Function({bool employeeId})
        > {
  $$AttendanceRecordsTableTableManager(
    _$AppDatabase db,
    $AttendanceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttendanceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttendanceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttendanceRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<DateTime> attendanceDate = const Value.absent(),
                Value<AttendanceHalfStatus> morningStatus =
                    const Value.absent(),
                Value<AttendanceHalfStatus> afternoonStatus =
                    const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => AttendanceRecordsCompanion(
                id: id,
                employeeId: employeeId,
                attendanceDate: attendanceDate,
                morningStatus: morningStatus,
                afternoonStatus: afternoonStatus,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required DateTime attendanceDate,
                Value<AttendanceHalfStatus> morningStatus =
                    const Value.absent(),
                Value<AttendanceHalfStatus> afternoonStatus =
                    const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => AttendanceRecordsCompanion.insert(
                id: id,
                employeeId: employeeId,
                attendanceDate: attendanceDate,
                morningStatus: morningStatus,
                afternoonStatus: afternoonStatus,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttendanceRecordsTable, AttendanceRecord>(table),
                  $$AttendanceRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable: $$AttendanceRecordsTableReferences
                            ._employeeIdTable(db),
                        referencedColumn: $$AttendanceRecordsTableReferences
                            ._employeeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttendanceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttendanceRecordsTable,
      AttendanceRecord,
      $$AttendanceRecordsTableFilterComposer,
      $$AttendanceRecordsTableOrderingComposer,
      $$AttendanceRecordsTableAnnotationComposer,
      $$AttendanceRecordsTableCreateCompanionBuilder,
      $$AttendanceRecordsTableUpdateCompanionBuilder,
      (AttendanceRecord, $$AttendanceRecordsTableReferences),
      AttendanceRecord,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$LeaveRecordsTableCreateCompanionBuilder =
    LeaveRecordsCompanion Function({
      Value<int> id,
      required int employeeId,
      Value<LeaveType> leaveType,
      required DateTime startDate,
      required DateTime endDate,
      Value<LeaveHalfPeriod> startPeriod,
      Value<LeaveHalfPeriod> endPeriod,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$LeaveRecordsTableUpdateCompanionBuilder =
    LeaveRecordsCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<LeaveType> leaveType,
      Value<DateTime> startDate,
      Value<DateTime> endDate,
      Value<LeaveHalfPeriod> startPeriod,
      Value<LeaveHalfPeriod> endPeriod,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$LeaveRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $LeaveRecordsTable, LeaveRecord> {
  $$LeaveRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) =>
      db.employees.createAlias('leave_records__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LeaveRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $LeaveRecordsTable> {
  $$LeaveRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LeaveType, LeaveType, String> get leaveType =>
      $composableBuilder(
        column: $table.leaveType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LeaveHalfPeriod, LeaveHalfPeriod, String>
  get startPeriod => $composableBuilder(
    column: $table.startPeriod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<LeaveHalfPeriod, LeaveHalfPeriod, String>
  get endPeriod => $composableBuilder(
    column: $table.endPeriod,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LeaveRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $LeaveRecordsTable> {
  $$LeaveRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaveType => $composableBuilder(
    column: $table.leaveType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startPeriod => $composableBuilder(
    column: $table.startPeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endPeriod => $composableBuilder(
    column: $table.endPeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LeaveRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LeaveRecordsTable> {
  $$LeaveRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LeaveType, String> get leaveType =>
      $composableBuilder(column: $table.leaveType, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LeaveHalfPeriod, String> get startPeriod =>
      $composableBuilder(
        column: $table.startPeriod,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<LeaveHalfPeriod, String> get endPeriod =>
      $composableBuilder(column: $table.endPeriod, builder: (column) => column);

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LeaveRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LeaveRecordsTable,
          LeaveRecord,
          $$LeaveRecordsTableFilterComposer,
          $$LeaveRecordsTableOrderingComposer,
          $$LeaveRecordsTableAnnotationComposer,
          $$LeaveRecordsTableCreateCompanionBuilder,
          $$LeaveRecordsTableUpdateCompanionBuilder,
          (LeaveRecord, $$LeaveRecordsTableReferences),
          LeaveRecord,
          PrefetchHooks Function({bool employeeId})
        > {
  $$LeaveRecordsTableTableManager(_$AppDatabase db, $LeaveRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LeaveRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LeaveRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LeaveRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<LeaveType> leaveType = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> endDate = const Value.absent(),
                Value<LeaveHalfPeriod> startPeriod = const Value.absent(),
                Value<LeaveHalfPeriod> endPeriod = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => LeaveRecordsCompanion(
                id: id,
                employeeId: employeeId,
                leaveType: leaveType,
                startDate: startDate,
                endDate: endDate,
                startPeriod: startPeriod,
                endPeriod: endPeriod,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                Value<LeaveType> leaveType = const Value.absent(),
                required DateTime startDate,
                required DateTime endDate,
                Value<LeaveHalfPeriod> startPeriod = const Value.absent(),
                Value<LeaveHalfPeriod> endPeriod = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => LeaveRecordsCompanion.insert(
                id: id,
                employeeId: employeeId,
                leaveType: leaveType,
                startDate: startDate,
                endDate: endDate,
                startPeriod: startPeriod,
                endPeriod: endPeriod,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LeaveRecordsTable, LeaveRecord>(table),
                  $$LeaveRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable: $$LeaveRecordsTableReferences
                            ._employeeIdTable(db),
                        referencedColumn: $$LeaveRecordsTableReferences
                            ._employeeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LeaveRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LeaveRecordsTable,
      LeaveRecord,
      $$LeaveRecordsTableFilterComposer,
      $$LeaveRecordsTableOrderingComposer,
      $$LeaveRecordsTableAnnotationComposer,
      $$LeaveRecordsTableCreateCompanionBuilder,
      $$LeaveRecordsTableUpdateCompanionBuilder,
      (LeaveRecord, $$LeaveRecordsTableReferences),
      LeaveRecord,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$OvertimeRecordsTableCreateCompanionBuilder =
    OvertimeRecordsCompanion Function({
      Value<int> id,
      required int employeeId,
      required DateTime overtimeDate,
      required DateTime startTime,
      required DateTime endTime,
      required int durationMinutes,
      Value<String> overtimeType,
      Value<String?> workContent,
      Value<String?> workLocation,
      Value<String?> registrant,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$OvertimeRecordsTableUpdateCompanionBuilder =
    OvertimeRecordsCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<DateTime> overtimeDate,
      Value<DateTime> startTime,
      Value<DateTime> endTime,
      Value<int> durationMinutes,
      Value<String> overtimeType,
      Value<String?> workContent,
      Value<String?> workLocation,
      Value<String?> registrant,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$OvertimeRecordsTableReferences
    extends
        BaseReferences<_$AppDatabase, $OvertimeRecordsTable, OvertimeRecord> {
  $$OvertimeRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) =>
      db.employees.createAlias('overtime_records__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OvertimeRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $OvertimeRecordsTable> {
  $$OvertimeRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get overtimeDate => $composableBuilder(
    column: $table.overtimeDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overtimeType => $composableBuilder(
    column: $table.overtimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workContent => $composableBuilder(
    column: $table.workContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workLocation => $composableBuilder(
    column: $table.workLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registrant => $composableBuilder(
    column: $table.registrant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OvertimeRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $OvertimeRecordsTable> {
  $$OvertimeRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get overtimeDate => $composableBuilder(
    column: $table.overtimeDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
    column: $table.startTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
    column: $table.endTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overtimeType => $composableBuilder(
    column: $table.overtimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workContent => $composableBuilder(
    column: $table.workContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workLocation => $composableBuilder(
    column: $table.workLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registrant => $composableBuilder(
    column: $table.registrant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OvertimeRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OvertimeRecordsTable> {
  $$OvertimeRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get overtimeDate => $composableBuilder(
    column: $table.overtimeDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get overtimeType => $composableBuilder(
    column: $table.overtimeType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workContent => $composableBuilder(
    column: $table.workContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get workLocation => $composableBuilder(
    column: $table.workLocation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registrant => $composableBuilder(
    column: $table.registrant,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OvertimeRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OvertimeRecordsTable,
          OvertimeRecord,
          $$OvertimeRecordsTableFilterComposer,
          $$OvertimeRecordsTableOrderingComposer,
          $$OvertimeRecordsTableAnnotationComposer,
          $$OvertimeRecordsTableCreateCompanionBuilder,
          $$OvertimeRecordsTableUpdateCompanionBuilder,
          (OvertimeRecord, $$OvertimeRecordsTableReferences),
          OvertimeRecord,
          PrefetchHooks Function({bool employeeId})
        > {
  $$OvertimeRecordsTableTableManager(
    _$AppDatabase db,
    $OvertimeRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OvertimeRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OvertimeRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OvertimeRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<DateTime> overtimeDate = const Value.absent(),
                Value<DateTime> startTime = const Value.absent(),
                Value<DateTime> endTime = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String> overtimeType = const Value.absent(),
                Value<String?> workContent = const Value.absent(),
                Value<String?> workLocation = const Value.absent(),
                Value<String?> registrant = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => OvertimeRecordsCompanion(
                id: id,
                employeeId: employeeId,
                overtimeDate: overtimeDate,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                overtimeType: overtimeType,
                workContent: workContent,
                workLocation: workLocation,
                registrant: registrant,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required DateTime overtimeDate,
                required DateTime startTime,
                required DateTime endTime,
                required int durationMinutes,
                Value<String> overtimeType = const Value.absent(),
                Value<String?> workContent = const Value.absent(),
                Value<String?> workLocation = const Value.absent(),
                Value<String?> registrant = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => OvertimeRecordsCompanion.insert(
                id: id,
                employeeId: employeeId,
                overtimeDate: overtimeDate,
                startTime: startTime,
                endTime: endTime,
                durationMinutes: durationMinutes,
                overtimeType: overtimeType,
                workContent: workContent,
                workLocation: workLocation,
                registrant: registrant,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OvertimeRecordsTable, OvertimeRecord>(table),
                  $$OvertimeRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable: $$OvertimeRecordsTableReferences
                            ._employeeIdTable(db),
                        referencedColumn: $$OvertimeRecordsTableReferences
                            ._employeeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OvertimeRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OvertimeRecordsTable,
      OvertimeRecord,
      $$OvertimeRecordsTableFilterComposer,
      $$OvertimeRecordsTableOrderingComposer,
      $$OvertimeRecordsTableAnnotationComposer,
      $$OvertimeRecordsTableCreateCompanionBuilder,
      $$OvertimeRecordsTableUpdateCompanionBuilder,
      (OvertimeRecord, $$OvertimeRecordsTableReferences),
      OvertimeRecord,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$TerminationRecordsTableCreateCompanionBuilder =
    TerminationRecordsCompanion Function({
      Value<int> id,
      required int employeeId,
      required DateTime terminationDate,
      Value<String> terminationType,
      Value<bool> isInsuranceStopped,
      Value<String?> stopInsuranceMonth,
      Value<bool> toolsReturned,
      Value<bool> materialsTransferred,
      Value<bool> hasUnsettledItems,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$TerminationRecordsTableUpdateCompanionBuilder =
    TerminationRecordsCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<DateTime> terminationDate,
      Value<String> terminationType,
      Value<bool> isInsuranceStopped,
      Value<String?> stopInsuranceMonth,
      Value<bool> toolsReturned,
      Value<bool> materialsTransferred,
      Value<bool> hasUnsettledItems,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$TerminationRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TerminationRecordsTable,
          TerminationRecord
        > {
  $$TerminationRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('termination_records__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TerminationRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $TerminationRecordsTable> {
  $$TerminationRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get terminationDate => $composableBuilder(
    column: $table.terminationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get terminationType => $composableBuilder(
    column: $table.terminationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInsuranceStopped => $composableBuilder(
    column: $table.isInsuranceStopped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stopInsuranceMonth => $composableBuilder(
    column: $table.stopInsuranceMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get toolsReturned => $composableBuilder(
    column: $table.toolsReturned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get materialsTransferred => $composableBuilder(
    column: $table.materialsTransferred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasUnsettledItems => $composableBuilder(
    column: $table.hasUnsettledItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TerminationRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $TerminationRecordsTable> {
  $$TerminationRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get terminationDate => $composableBuilder(
    column: $table.terminationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get terminationType => $composableBuilder(
    column: $table.terminationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInsuranceStopped => $composableBuilder(
    column: $table.isInsuranceStopped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stopInsuranceMonth => $composableBuilder(
    column: $table.stopInsuranceMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get toolsReturned => $composableBuilder(
    column: $table.toolsReturned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get materialsTransferred => $composableBuilder(
    column: $table.materialsTransferred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasUnsettledItems => $composableBuilder(
    column: $table.hasUnsettledItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TerminationRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TerminationRecordsTable> {
  $$TerminationRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get terminationDate => $composableBuilder(
    column: $table.terminationDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get terminationType => $composableBuilder(
    column: $table.terminationType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isInsuranceStopped => $composableBuilder(
    column: $table.isInsuranceStopped,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stopInsuranceMonth => $composableBuilder(
    column: $table.stopInsuranceMonth,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get toolsReturned => $composableBuilder(
    column: $table.toolsReturned,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get materialsTransferred => $composableBuilder(
    column: $table.materialsTransferred,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasUnsettledItems => $composableBuilder(
    column: $table.hasUnsettledItems,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TerminationRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TerminationRecordsTable,
          TerminationRecord,
          $$TerminationRecordsTableFilterComposer,
          $$TerminationRecordsTableOrderingComposer,
          $$TerminationRecordsTableAnnotationComposer,
          $$TerminationRecordsTableCreateCompanionBuilder,
          $$TerminationRecordsTableUpdateCompanionBuilder,
          (TerminationRecord, $$TerminationRecordsTableReferences),
          TerminationRecord,
          PrefetchHooks Function({bool employeeId})
        > {
  $$TerminationRecordsTableTableManager(
    _$AppDatabase db,
    $TerminationRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TerminationRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TerminationRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TerminationRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<DateTime> terminationDate = const Value.absent(),
                Value<String> terminationType = const Value.absent(),
                Value<bool> isInsuranceStopped = const Value.absent(),
                Value<String?> stopInsuranceMonth = const Value.absent(),
                Value<bool> toolsReturned = const Value.absent(),
                Value<bool> materialsTransferred = const Value.absent(),
                Value<bool> hasUnsettledItems = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => TerminationRecordsCompanion(
                id: id,
                employeeId: employeeId,
                terminationDate: terminationDate,
                terminationType: terminationType,
                isInsuranceStopped: isInsuranceStopped,
                stopInsuranceMonth: stopInsuranceMonth,
                toolsReturned: toolsReturned,
                materialsTransferred: materialsTransferred,
                hasUnsettledItems: hasUnsettledItems,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required DateTime terminationDate,
                Value<String> terminationType = const Value.absent(),
                Value<bool> isInsuranceStopped = const Value.absent(),
                Value<String?> stopInsuranceMonth = const Value.absent(),
                Value<bool> toolsReturned = const Value.absent(),
                Value<bool> materialsTransferred = const Value.absent(),
                Value<bool> hasUnsettledItems = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => TerminationRecordsCompanion.insert(
                id: id,
                employeeId: employeeId,
                terminationDate: terminationDate,
                terminationType: terminationType,
                isInsuranceStopped: isInsuranceStopped,
                stopInsuranceMonth: stopInsuranceMonth,
                toolsReturned: toolsReturned,
                materialsTransferred: materialsTransferred,
                hasUnsettledItems: hasUnsettledItems,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TerminationRecordsTable, TerminationRecord>(
                    table,
                  ),
                  $$TerminationRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable: $$TerminationRecordsTableReferences
                            ._employeeIdTable(db),
                        referencedColumn: $$TerminationRecordsTableReferences
                            ._employeeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TerminationRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TerminationRecordsTable,
      TerminationRecord,
      $$TerminationRecordsTableFilterComposer,
      $$TerminationRecordsTableOrderingComposer,
      $$TerminationRecordsTableAnnotationComposer,
      $$TerminationRecordsTableCreateCompanionBuilder,
      $$TerminationRecordsTableUpdateCompanionBuilder,
      (TerminationRecord, $$TerminationRecordsTableReferences),
      TerminationRecord,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$MonthlyAttendanceSummariesTableCreateCompanionBuilder =
    MonthlyAttendanceSummariesCompanion Function({
      Value<int> id,
      required String yearMonth,
      required int employeeId,
      Value<int?> attendanceGroupId,
      Value<bool> participates,
      Value<double> attendanceDays,
      Value<double> leaveDays,
      Value<double> absentDays,
      Value<double> restDays,
      Value<double> stoppedDays,
      Value<int> overtimeCount,
      Value<int> overtimeMinutes,
      Value<String?> monthStartStatus,
      Value<String?> monthEndStatus,
      Value<bool> joinedDuringMonth,
      Value<bool> terminatedDuringMonth,
      Value<bool> isComplete,
      Value<int> anomalyCount,
      Value<MonthlySummaryStatus> status,
      Value<DateTime?> generatedAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$MonthlyAttendanceSummariesTableUpdateCompanionBuilder =
    MonthlyAttendanceSummariesCompanion Function({
      Value<int> id,
      Value<String> yearMonth,
      Value<int> employeeId,
      Value<int?> attendanceGroupId,
      Value<bool> participates,
      Value<double> attendanceDays,
      Value<double> leaveDays,
      Value<double> absentDays,
      Value<double> restDays,
      Value<double> stoppedDays,
      Value<int> overtimeCount,
      Value<int> overtimeMinutes,
      Value<String?> monthStartStatus,
      Value<String?> monthEndStatus,
      Value<bool> joinedDuringMonth,
      Value<bool> terminatedDuringMonth,
      Value<bool> isComplete,
      Value<int> anomalyCount,
      Value<MonthlySummaryStatus> status,
      Value<DateTime?> generatedAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$MonthlyAttendanceSummariesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MonthlyAttendanceSummariesTable,
          MonthlyAttendanceSummary
        > {
  $$MonthlyAttendanceSummariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('monthly_attendance_summaries__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AttendanceGroupsTable _attendanceGroupIdTable(
    _$AppDatabase db,
  ) => db.attendanceGroups.createAlias(
    'monthly_attendance_summaries__attendance_group_id__attendance_groups__id',
  );

  $$AttendanceGroupsTableProcessedTableManager? get attendanceGroupId {
    final $_column = $_itemColumn<int>('attendance_group_id');
    if ($_column == null) return null;
    final manager = $$AttendanceGroupsTableTableManager(
      $_db,
      $_db.attendanceGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attendanceGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MonthlyAttendanceSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $MonthlyAttendanceSummariesTable> {
  $$MonthlyAttendanceSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get yearMonth => $composableBuilder(
    column: $table.yearMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get participates => $composableBuilder(
    column: $table.participates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get attendanceDays => $composableBuilder(
    column: $table.attendanceDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get leaveDays => $composableBuilder(
    column: $table.leaveDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get absentDays => $composableBuilder(
    column: $table.absentDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get restDays => $composableBuilder(
    column: $table.restDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stoppedDays => $composableBuilder(
    column: $table.stoppedDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeCount => $composableBuilder(
    column: $table.overtimeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthStartStatus => $composableBuilder(
    column: $table.monthStartStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthEndStatus => $composableBuilder(
    column: $table.monthEndStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get joinedDuringMonth => $composableBuilder(
    column: $table.joinedDuringMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get terminatedDuringMonth => $composableBuilder(
    column: $table.terminatedDuringMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isComplete => $composableBuilder(
    column: $table.isComplete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anomalyCount => $composableBuilder(
    column: $table.anomalyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<
    MonthlySummaryStatus,
    MonthlySummaryStatus,
    String
  >
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AttendanceGroupsTableFilterComposer get attendanceGroupId {
    final $$AttendanceGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableFilterComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyAttendanceSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $MonthlyAttendanceSummariesTable> {
  $$MonthlyAttendanceSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get yearMonth => $composableBuilder(
    column: $table.yearMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get participates => $composableBuilder(
    column: $table.participates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get attendanceDays => $composableBuilder(
    column: $table.attendanceDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get leaveDays => $composableBuilder(
    column: $table.leaveDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get absentDays => $composableBuilder(
    column: $table.absentDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get restDays => $composableBuilder(
    column: $table.restDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stoppedDays => $composableBuilder(
    column: $table.stoppedDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeCount => $composableBuilder(
    column: $table.overtimeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthStartStatus => $composableBuilder(
    column: $table.monthStartStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthEndStatus => $composableBuilder(
    column: $table.monthEndStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get joinedDuringMonth => $composableBuilder(
    column: $table.joinedDuringMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get terminatedDuringMonth => $composableBuilder(
    column: $table.terminatedDuringMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isComplete => $composableBuilder(
    column: $table.isComplete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anomalyCount => $composableBuilder(
    column: $table.anomalyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AttendanceGroupsTableOrderingComposer get attendanceGroupId {
    final $$AttendanceGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyAttendanceSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MonthlyAttendanceSummariesTable> {
  $$MonthlyAttendanceSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get yearMonth =>
      $composableBuilder(column: $table.yearMonth, builder: (column) => column);

  GeneratedColumn<bool> get participates => $composableBuilder(
    column: $table.participates,
    builder: (column) => column,
  );

  GeneratedColumn<double> get attendanceDays => $composableBuilder(
    column: $table.attendanceDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get leaveDays =>
      $composableBuilder(column: $table.leaveDays, builder: (column) => column);

  GeneratedColumn<double> get absentDays => $composableBuilder(
    column: $table.absentDays,
    builder: (column) => column,
  );

  GeneratedColumn<double> get restDays =>
      $composableBuilder(column: $table.restDays, builder: (column) => column);

  GeneratedColumn<double> get stoppedDays => $composableBuilder(
    column: $table.stoppedDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overtimeCount => $composableBuilder(
    column: $table.overtimeCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overtimeMinutes => $composableBuilder(
    column: $table.overtimeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get monthStartStatus => $composableBuilder(
    column: $table.monthStartStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get monthEndStatus => $composableBuilder(
    column: $table.monthEndStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get joinedDuringMonth => $composableBuilder(
    column: $table.joinedDuringMonth,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get terminatedDuringMonth => $composableBuilder(
    column: $table.terminatedDuringMonth,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isComplete => $composableBuilder(
    column: $table.isComplete,
    builder: (column) => column,
  );

  GeneratedColumn<int> get anomalyCount => $composableBuilder(
    column: $table.anomalyCount,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MonthlySummaryStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AttendanceGroupsTableAnnotationComposer get attendanceGroupId {
    final $$AttendanceGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attendanceGroupId,
      referencedTable: $db.attendanceGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttendanceGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.attendanceGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MonthlyAttendanceSummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MonthlyAttendanceSummariesTable,
          MonthlyAttendanceSummary,
          $$MonthlyAttendanceSummariesTableFilterComposer,
          $$MonthlyAttendanceSummariesTableOrderingComposer,
          $$MonthlyAttendanceSummariesTableAnnotationComposer,
          $$MonthlyAttendanceSummariesTableCreateCompanionBuilder,
          $$MonthlyAttendanceSummariesTableUpdateCompanionBuilder,
          (
            MonthlyAttendanceSummary,
            $$MonthlyAttendanceSummariesTableReferences,
          ),
          MonthlyAttendanceSummary,
          PrefetchHooks Function({bool employeeId, bool attendanceGroupId})
        > {
  $$MonthlyAttendanceSummariesTableTableManager(
    _$AppDatabase db,
    $MonthlyAttendanceSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MonthlyAttendanceSummariesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$MonthlyAttendanceSummariesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MonthlyAttendanceSummariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> yearMonth = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<int?> attendanceGroupId = const Value.absent(),
                Value<bool> participates = const Value.absent(),
                Value<double> attendanceDays = const Value.absent(),
                Value<double> leaveDays = const Value.absent(),
                Value<double> absentDays = const Value.absent(),
                Value<double> restDays = const Value.absent(),
                Value<double> stoppedDays = const Value.absent(),
                Value<int> overtimeCount = const Value.absent(),
                Value<int> overtimeMinutes = const Value.absent(),
                Value<String?> monthStartStatus = const Value.absent(),
                Value<String?> monthEndStatus = const Value.absent(),
                Value<bool> joinedDuringMonth = const Value.absent(),
                Value<bool> terminatedDuringMonth = const Value.absent(),
                Value<bool> isComplete = const Value.absent(),
                Value<int> anomalyCount = const Value.absent(),
                Value<MonthlySummaryStatus> status = const Value.absent(),
                Value<DateTime?> generatedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => MonthlyAttendanceSummariesCompanion(
                id: id,
                yearMonth: yearMonth,
                employeeId: employeeId,
                attendanceGroupId: attendanceGroupId,
                participates: participates,
                attendanceDays: attendanceDays,
                leaveDays: leaveDays,
                absentDays: absentDays,
                restDays: restDays,
                stoppedDays: stoppedDays,
                overtimeCount: overtimeCount,
                overtimeMinutes: overtimeMinutes,
                monthStartStatus: monthStartStatus,
                monthEndStatus: monthEndStatus,
                joinedDuringMonth: joinedDuringMonth,
                terminatedDuringMonth: terminatedDuringMonth,
                isComplete: isComplete,
                anomalyCount: anomalyCount,
                status: status,
                generatedAt: generatedAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String yearMonth,
                required int employeeId,
                Value<int?> attendanceGroupId = const Value.absent(),
                Value<bool> participates = const Value.absent(),
                Value<double> attendanceDays = const Value.absent(),
                Value<double> leaveDays = const Value.absent(),
                Value<double> absentDays = const Value.absent(),
                Value<double> restDays = const Value.absent(),
                Value<double> stoppedDays = const Value.absent(),
                Value<int> overtimeCount = const Value.absent(),
                Value<int> overtimeMinutes = const Value.absent(),
                Value<String?> monthStartStatus = const Value.absent(),
                Value<String?> monthEndStatus = const Value.absent(),
                Value<bool> joinedDuringMonth = const Value.absent(),
                Value<bool> terminatedDuringMonth = const Value.absent(),
                Value<bool> isComplete = const Value.absent(),
                Value<int> anomalyCount = const Value.absent(),
                Value<MonthlySummaryStatus> status = const Value.absent(),
                Value<DateTime?> generatedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => MonthlyAttendanceSummariesCompanion.insert(
                id: id,
                yearMonth: yearMonth,
                employeeId: employeeId,
                attendanceGroupId: attendanceGroupId,
                participates: participates,
                attendanceDays: attendanceDays,
                leaveDays: leaveDays,
                absentDays: absentDays,
                restDays: restDays,
                stoppedDays: stoppedDays,
                overtimeCount: overtimeCount,
                overtimeMinutes: overtimeMinutes,
                monthStartStatus: monthStartStatus,
                monthEndStatus: monthEndStatus,
                joinedDuringMonth: joinedDuringMonth,
                terminatedDuringMonth: terminatedDuringMonth,
                isComplete: isComplete,
                anomalyCount: anomalyCount,
                status: status,
                generatedAt: generatedAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MonthlyAttendanceSummariesTable,
                    MonthlyAttendanceSummary
                  >(table),
                  $$MonthlyAttendanceSummariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({employeeId = false, attendanceGroupId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (employeeId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.employeeId,
                            referencedTable:
                                $$MonthlyAttendanceSummariesTableReferences
                                    ._employeeIdTable(db),
                            referencedColumn:
                                $$MonthlyAttendanceSummariesTableReferences
                                    ._employeeIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (attendanceGroupId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.attendanceGroupId,
                            referencedTable:
                                $$MonthlyAttendanceSummariesTableReferences
                                    ._attendanceGroupIdTable(db),
                            referencedColumn:
                                $$MonthlyAttendanceSummariesTableReferences
                                    ._attendanceGroupIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$MonthlyAttendanceSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MonthlyAttendanceSummariesTable,
      MonthlyAttendanceSummary,
      $$MonthlyAttendanceSummariesTableFilterComposer,
      $$MonthlyAttendanceSummariesTableOrderingComposer,
      $$MonthlyAttendanceSummariesTableAnnotationComposer,
      $$MonthlyAttendanceSummariesTableCreateCompanionBuilder,
      $$MonthlyAttendanceSummariesTableUpdateCompanionBuilder,
      (MonthlyAttendanceSummary, $$MonthlyAttendanceSummariesTableReferences),
      MonthlyAttendanceSummary,
      PrefetchHooks Function({bool employeeId, bool attendanceGroupId})
    >;
typedef $$InsuranceProfilesTableCreateCompanionBuilder =
    InsuranceProfilesCompanion Function({
      Value<int> id,
      required int employeeId,
      Value<bool> isInsured,
      Value<String?> insuranceType,
      Value<double?> contributionBase,
      Value<String?> effectiveMonth,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$InsuranceProfilesTableUpdateCompanionBuilder =
    InsuranceProfilesCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<bool> isInsured,
      Value<String?> insuranceType,
      Value<double?> contributionBase,
      Value<String?> effectiveMonth,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$InsuranceProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $InsuranceProfilesTable,
          InsuranceProfile
        > {
  $$InsuranceProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('insurance_profiles__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InsuranceProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $InsuranceProfilesTable> {
  $$InsuranceProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isInsured => $composableBuilder(
    column: $table.isInsured,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsuranceProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $InsuranceProfilesTable> {
  $$InsuranceProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isInsured => $composableBuilder(
    column: $table.isInsured,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsuranceProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InsuranceProfilesTable> {
  $$InsuranceProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isInsured =>
      $composableBuilder(column: $table.isInsured, builder: (column) => column);

  GeneratedColumn<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => column,
  );

  GeneratedColumn<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsuranceProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InsuranceProfilesTable,
          InsuranceProfile,
          $$InsuranceProfilesTableFilterComposer,
          $$InsuranceProfilesTableOrderingComposer,
          $$InsuranceProfilesTableAnnotationComposer,
          $$InsuranceProfilesTableCreateCompanionBuilder,
          $$InsuranceProfilesTableUpdateCompanionBuilder,
          (InsuranceProfile, $$InsuranceProfilesTableReferences),
          InsuranceProfile,
          PrefetchHooks Function({bool employeeId})
        > {
  $$InsuranceProfilesTableTableManager(
    _$AppDatabase db,
    $InsuranceProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InsuranceProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InsuranceProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InsuranceProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<bool> isInsured = const Value.absent(),
                Value<String?> insuranceType = const Value.absent(),
                Value<double?> contributionBase = const Value.absent(),
                Value<String?> effectiveMonth = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => InsuranceProfilesCompanion(
                id: id,
                employeeId: employeeId,
                isInsured: isInsured,
                insuranceType: insuranceType,
                contributionBase: contributionBase,
                effectiveMonth: effectiveMonth,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                Value<bool> isInsured = const Value.absent(),
                Value<String?> insuranceType = const Value.absent(),
                Value<double?> contributionBase = const Value.absent(),
                Value<String?> effectiveMonth = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => InsuranceProfilesCompanion.insert(
                id: id,
                employeeId: employeeId,
                isInsured: isInsured,
                insuranceType: insuranceType,
                contributionBase: contributionBase,
                effectiveMonth: effectiveMonth,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InsuranceProfilesTable, InsuranceProfile>(table),
                  $$InsuranceProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable: $$InsuranceProfilesTableReferences
                            ._employeeIdTable(db),
                        referencedColumn: $$InsuranceProfilesTableReferences
                            ._employeeIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InsuranceProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InsuranceProfilesTable,
      InsuranceProfile,
      $$InsuranceProfilesTableFilterComposer,
      $$InsuranceProfilesTableOrderingComposer,
      $$InsuranceProfilesTableAnnotationComposer,
      $$InsuranceProfilesTableCreateCompanionBuilder,
      $$InsuranceProfilesTableUpdateCompanionBuilder,
      (InsuranceProfile, $$InsuranceProfilesTableReferences),
      InsuranceProfile,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$InsuranceChangeRecordsTableCreateCompanionBuilder =
    InsuranceChangeRecordsCompanion Function({
      Value<int> id,
      required int employeeId,
      required String changeType,
      Value<String> processingStatus,
      Value<String?> insuranceType,
      Value<double?> contributionBase,
      required String effectiveMonth,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$InsuranceChangeRecordsTableUpdateCompanionBuilder =
    InsuranceChangeRecordsCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<String> changeType,
      Value<String> processingStatus,
      Value<String?> insuranceType,
      Value<double?> contributionBase,
      Value<String> effectiveMonth,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

final class $$InsuranceChangeRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $InsuranceChangeRecordsTable,
          InsuranceChangeRecord
        > {
  $$InsuranceChangeRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('insurance_change_records__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InsuranceChangeRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $InsuranceChangeRecordsTable> {
  $$InsuranceChangeRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changeType => $composableBuilder(
    column: $table.changeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsuranceChangeRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $InsuranceChangeRecordsTable> {
  $$InsuranceChangeRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changeType => $composableBuilder(
    column: $table.changeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsuranceChangeRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InsuranceChangeRecordsTable> {
  $$InsuranceChangeRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get changeType => $composableBuilder(
    column: $table.changeType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get processingStatus => $composableBuilder(
    column: $table.processingStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => column,
  );

  GeneratedColumn<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InsuranceChangeRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InsuranceChangeRecordsTable,
          InsuranceChangeRecord,
          $$InsuranceChangeRecordsTableFilterComposer,
          $$InsuranceChangeRecordsTableOrderingComposer,
          $$InsuranceChangeRecordsTableAnnotationComposer,
          $$InsuranceChangeRecordsTableCreateCompanionBuilder,
          $$InsuranceChangeRecordsTableUpdateCompanionBuilder,
          (InsuranceChangeRecord, $$InsuranceChangeRecordsTableReferences),
          InsuranceChangeRecord,
          PrefetchHooks Function({bool employeeId})
        > {
  $$InsuranceChangeRecordsTableTableManager(
    _$AppDatabase db,
    $InsuranceChangeRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InsuranceChangeRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InsuranceChangeRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InsuranceChangeRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<String> changeType = const Value.absent(),
                Value<String> processingStatus = const Value.absent(),
                Value<String?> insuranceType = const Value.absent(),
                Value<double?> contributionBase = const Value.absent(),
                Value<String> effectiveMonth = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => InsuranceChangeRecordsCompanion(
                id: id,
                employeeId: employeeId,
                changeType: changeType,
                processingStatus: processingStatus,
                insuranceType: insuranceType,
                contributionBase: contributionBase,
                effectiveMonth: effectiveMonth,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                required String changeType,
                Value<String> processingStatus = const Value.absent(),
                Value<String?> insuranceType = const Value.absent(),
                Value<double?> contributionBase = const Value.absent(),
                required String effectiveMonth,
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => InsuranceChangeRecordsCompanion.insert(
                id: id,
                employeeId: employeeId,
                changeType: changeType,
                processingStatus: processingStatus,
                insuranceType: insuranceType,
                contributionBase: contributionBase,
                effectiveMonth: effectiveMonth,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $InsuranceChangeRecordsTable,
                    InsuranceChangeRecord
                  >(table),
                  $$InsuranceChangeRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable: $$InsuranceChangeRecordsTableReferences
                            ._employeeIdTable(db),
                        referencedColumn:
                            $$InsuranceChangeRecordsTableReferences
                                ._employeeIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InsuranceChangeRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InsuranceChangeRecordsTable,
      InsuranceChangeRecord,
      $$InsuranceChangeRecordsTableFilterComposer,
      $$InsuranceChangeRecordsTableOrderingComposer,
      $$InsuranceChangeRecordsTableAnnotationComposer,
      $$InsuranceChangeRecordsTableCreateCompanionBuilder,
      $$InsuranceChangeRecordsTableUpdateCompanionBuilder,
      (InsuranceChangeRecord, $$InsuranceChangeRecordsTableReferences),
      InsuranceChangeRecord,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$SocialSecurityBaseHistoryTableCreateCompanionBuilder =
    SocialSecurityBaseHistoryCompanion Function({
      Value<int> id,
      required int employeeId,
      Value<String?> insuranceType,
      Value<double?> contributionBase,
      required String effectiveMonth,
      Value<String?> source,
      Value<DateTime> createdAt,
      Value<bool> isDeleted,
    });
typedef $$SocialSecurityBaseHistoryTableUpdateCompanionBuilder =
    SocialSecurityBaseHistoryCompanion Function({
      Value<int> id,
      Value<int> employeeId,
      Value<String?> insuranceType,
      Value<double?> contributionBase,
      Value<String> effectiveMonth,
      Value<String?> source,
      Value<DateTime> createdAt,
      Value<bool> isDeleted,
    });

final class $$SocialSecurityBaseHistoryTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SocialSecurityBaseHistoryTable,
          SocialSecurityBaseHistoryData
        > {
  $$SocialSecurityBaseHistoryTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EmployeesTable _employeeIdTable(_$AppDatabase db) => db.employees
      .createAlias('social_security_base_history__employee_id__employees__id');

  $$EmployeesTableProcessedTableManager get employeeId {
    final $_column = $_itemColumn<int>('employee_id')!;

    final manager = $$EmployeesTableTableManager(
      $_db,
      $_db.employees,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_employeeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SocialSecurityBaseHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $SocialSecurityBaseHistoryTable> {
  $$SocialSecurityBaseHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$EmployeesTableFilterComposer get employeeId {
    final $$EmployeesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableFilterComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SocialSecurityBaseHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $SocialSecurityBaseHistoryTable> {
  $$SocialSecurityBaseHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$EmployeesTableOrderingComposer get employeeId {
    final $$EmployeesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableOrderingComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SocialSecurityBaseHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $SocialSecurityBaseHistoryTable> {
  $$SocialSecurityBaseHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get insuranceType => $composableBuilder(
    column: $table.insuranceType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get contributionBase => $composableBuilder(
    column: $table.contributionBase,
    builder: (column) => column,
  );

  GeneratedColumn<String> get effectiveMonth => $composableBuilder(
    column: $table.effectiveMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$EmployeesTableAnnotationComposer get employeeId {
    final $$EmployeesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.employeeId,
      referencedTable: $db.employees,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EmployeesTableAnnotationComposer(
            $db: $db,
            $table: $db.employees,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SocialSecurityBaseHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SocialSecurityBaseHistoryTable,
          SocialSecurityBaseHistoryData,
          $$SocialSecurityBaseHistoryTableFilterComposer,
          $$SocialSecurityBaseHistoryTableOrderingComposer,
          $$SocialSecurityBaseHistoryTableAnnotationComposer,
          $$SocialSecurityBaseHistoryTableCreateCompanionBuilder,
          $$SocialSecurityBaseHistoryTableUpdateCompanionBuilder,
          (
            SocialSecurityBaseHistoryData,
            $$SocialSecurityBaseHistoryTableReferences,
          ),
          SocialSecurityBaseHistoryData,
          PrefetchHooks Function({bool employeeId})
        > {
  $$SocialSecurityBaseHistoryTableTableManager(
    _$AppDatabase db,
    $SocialSecurityBaseHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SocialSecurityBaseHistoryTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SocialSecurityBaseHistoryTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SocialSecurityBaseHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> employeeId = const Value.absent(),
                Value<String?> insuranceType = const Value.absent(),
                Value<double?> contributionBase = const Value.absent(),
                Value<String> effectiveMonth = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => SocialSecurityBaseHistoryCompanion(
                id: id,
                employeeId: employeeId,
                insuranceType: insuranceType,
                contributionBase: contributionBase,
                effectiveMonth: effectiveMonth,
                source: source,
                createdAt: createdAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int employeeId,
                Value<String?> insuranceType = const Value.absent(),
                Value<double?> contributionBase = const Value.absent(),
                required String effectiveMonth,
                Value<String?> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => SocialSecurityBaseHistoryCompanion.insert(
                id: id,
                employeeId: employeeId,
                insuranceType: insuranceType,
                contributionBase: contributionBase,
                effectiveMonth: effectiveMonth,
                source: source,
                createdAt: createdAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $SocialSecurityBaseHistoryTable,
                    SocialSecurityBaseHistoryData
                  >(table),
                  $$SocialSecurityBaseHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({employeeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (employeeId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.employeeId,
                        referencedTable:
                            $$SocialSecurityBaseHistoryTableReferences
                                ._employeeIdTable(db),
                        referencedColumn:
                            $$SocialSecurityBaseHistoryTableReferences
                                ._employeeIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SocialSecurityBaseHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SocialSecurityBaseHistoryTable,
      SocialSecurityBaseHistoryData,
      $$SocialSecurityBaseHistoryTableFilterComposer,
      $$SocialSecurityBaseHistoryTableOrderingComposer,
      $$SocialSecurityBaseHistoryTableAnnotationComposer,
      $$SocialSecurityBaseHistoryTableCreateCompanionBuilder,
      $$SocialSecurityBaseHistoryTableUpdateCompanionBuilder,
      (
        SocialSecurityBaseHistoryData,
        $$SocialSecurityBaseHistoryTableReferences,
      ),
      SocialSecurityBaseHistoryData,
      PrefetchHooks Function({bool employeeId})
    >;
typedef $$OperationLogsTableCreateCompanionBuilder =
    OperationLogsCompanion Function({
      Value<int> id,
      required String operationType,
      required String entityType,
      Value<int?> entityId,
      Value<String?> detail,
      Value<DateTime> createdAt,
    });
typedef $$OperationLogsTableUpdateCompanionBuilder =
    OperationLogsCompanion Function({
      Value<int> id,
      Value<String> operationType,
      Value<String> entityType,
      Value<int?> entityId,
      Value<String?> detail,
      Value<DateTime> createdAt,
    });

class $$OperationLogsTableFilterComposer
    extends Composer<_$AppDatabase, $OperationLogsTable> {
  $$OperationLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OperationLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $OperationLogsTable> {
  $$OperationLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperationLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OperationLogsTable> {
  $$OperationLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OperationLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OperationLogsTable,
          OperationLog,
          $$OperationLogsTableFilterComposer,
          $$OperationLogsTableOrderingComposer,
          $$OperationLogsTableAnnotationComposer,
          $$OperationLogsTableCreateCompanionBuilder,
          $$OperationLogsTableUpdateCompanionBuilder,
          (
            OperationLog,
            BaseReferences<_$AppDatabase, $OperationLogsTable, OperationLog>,
          ),
          OperationLog,
          PrefetchHooks Function()
        > {
  $$OperationLogsTableTableManager(_$AppDatabase db, $OperationLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<int?> entityId = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OperationLogsCompanion(
                id: id,
                operationType: operationType,
                entityType: entityType,
                entityId: entityId,
                detail: detail,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operationType,
                required String entityType,
                Value<int?> entityId = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OperationLogsCompanion.insert(
                id: id,
                operationType: operationType,
                entityType: entityType,
                entityId: entityId,
                detail: detail,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OperationLogsTable, OperationLog>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OperationLogsTable,
                    OperationLog
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OperationLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OperationLogsTable,
      OperationLog,
      $$OperationLogsTableFilterComposer,
      $$OperationLogsTableOrderingComposer,
      $$OperationLogsTableAnnotationComposer,
      $$OperationLogsTableCreateCompanionBuilder,
      $$OperationLogsTableUpdateCompanionBuilder,
      (
        OperationLog,
        BaseReferences<_$AppDatabase, $OperationLogsTable, OperationLog>,
      ),
      OperationLog,
      PrefetchHooks Function()
    >;
typedef $$DictionaryItemsTableCreateCompanionBuilder =
    DictionaryItemsCompanion Function({
      Value<int> id,
      required String dictionaryType,
      required String itemKey,
      required String itemLabel,
      Value<int> sortOrder,
      Value<bool> isEnabled,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });
typedef $$DictionaryItemsTableUpdateCompanionBuilder =
    DictionaryItemsCompanion Function({
      Value<int> id,
      Value<String> dictionaryType,
      Value<String> itemKey,
      Value<String> itemLabel,
      Value<int> sortOrder,
      Value<bool> isEnabled,
      Value<String?> remark,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
    });

class $$DictionaryItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DictionaryItemsTable> {
  $$DictionaryItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dictionaryType => $composableBuilder(
    column: $table.dictionaryType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemLabel => $composableBuilder(
    column: $table.itemLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DictionaryItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DictionaryItemsTable> {
  $$DictionaryItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dictionaryType => $composableBuilder(
    column: $table.dictionaryType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemKey => $composableBuilder(
    column: $table.itemKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemLabel => $composableBuilder(
    column: $table.itemLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DictionaryItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DictionaryItemsTable> {
  $$DictionaryItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dictionaryType => $composableBuilder(
    column: $table.dictionaryType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemKey =>
      $composableBuilder(column: $table.itemKey, builder: (column) => column);

  GeneratedColumn<String> get itemLabel =>
      $composableBuilder(column: $table.itemLabel, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$DictionaryItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DictionaryItemsTable,
          DictionaryItem,
          $$DictionaryItemsTableFilterComposer,
          $$DictionaryItemsTableOrderingComposer,
          $$DictionaryItemsTableAnnotationComposer,
          $$DictionaryItemsTableCreateCompanionBuilder,
          $$DictionaryItemsTableUpdateCompanionBuilder,
          (
            DictionaryItem,
            BaseReferences<
              _$AppDatabase,
              $DictionaryItemsTable,
              DictionaryItem
            >,
          ),
          DictionaryItem,
          PrefetchHooks Function()
        > {
  $$DictionaryItemsTableTableManager(
    _$AppDatabase db,
    $DictionaryItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionaryItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictionaryItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictionaryItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dictionaryType = const Value.absent(),
                Value<String> itemKey = const Value.absent(),
                Value<String> itemLabel = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => DictionaryItemsCompanion(
                id: id,
                dictionaryType: dictionaryType,
                itemKey: itemKey,
                itemLabel: itemLabel,
                sortOrder: sortOrder,
                isEnabled: isEnabled,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dictionaryType,
                required String itemKey,
                required String itemLabel,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => DictionaryItemsCompanion.insert(
                id: id,
                dictionaryType: dictionaryType,
                itemKey: itemKey,
                itemLabel: itemLabel,
                sortOrder: sortOrder,
                isEnabled: isEnabled,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DictionaryItemsTable, DictionaryItem>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DictionaryItemsTable,
                    DictionaryItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DictionaryItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DictionaryItemsTable,
      DictionaryItem,
      $$DictionaryItemsTableFilterComposer,
      $$DictionaryItemsTableOrderingComposer,
      $$DictionaryItemsTableAnnotationComposer,
      $$DictionaryItemsTableCreateCompanionBuilder,
      $$DictionaryItemsTableUpdateCompanionBuilder,
      (
        DictionaryItem,
        BaseReferences<_$AppDatabase, $DictionaryItemsTable, DictionaryItem>,
      ),
      DictionaryItem,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      required String settingKey,
      Value<String?> settingValue,
      Value<DateTime> updatedAt,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> settingKey,
      Value<String?> settingValue,
      Value<DateTime> updatedAt,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> settingKey = const Value.absent(),
                Value<String?> settingValue = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                settingKey: settingKey,
                settingValue: settingValue,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String settingKey,
                Value<String?> settingValue = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                settingKey: settingKey,
                settingValue: settingValue,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  Value<int> id,
  required String title,
  required String reminderType,
  Value<DateTime?> dueDate,
  Value<int> leadDays,
  Value<String?> repeatRule,
  Value<bool> isEnabled,
  Value<bool> isCompleted,
  Value<String?> sourceEntityType,
  Value<int?> sourceEntityId,
  Value<String?> remark,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> isDeleted,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> reminderType,
  Value<DateTime?> dueDate,
  Value<int> leadDays,
  Value<String?> repeatRule,
  Value<bool> isEnabled,
  Value<bool> isCompleted,
  Value<String?> sourceEntityType,
  Value<int?> sourceEntityId,
  Value<String?> remark,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> isDeleted,
});

class $$RemindersTableFilterComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderType => $composableBuilder(
    column: $table.reminderType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leadDays => $composableBuilder(
    column: $table.leadDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceEntityType => $composableBuilder(
    column: $table.sourceEntityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderType => $composableBuilder(
    column: $table.reminderType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leadDays => $composableBuilder(
    column: $table.leadDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceEntityType => $composableBuilder(
    column: $table.sourceEntityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remark => $composableBuilder(
    column: $table.remark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get reminderType => $composableBuilder(
    column: $table.reminderType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get leadDays =>
      $composableBuilder(column: $table.leadDays, builder: (column) => column);

  GeneratedColumn<String> get repeatRule => $composableBuilder(
    column: $table.repeatRule,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceEntityType => $composableBuilder(
    column: $table.sourceEntityType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceEntityId => $composableBuilder(
    column: $table.sourceEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remark =>
      $composableBuilder(column: $table.remark, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemindersTable,
          Reminder,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
          Reminder,
          PrefetchHooks Function()
        > {
  $$RemindersTableTableManager(_$AppDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> reminderType = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<int> leadDays = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> sourceEntityType = const Value.absent(),
                Value<int?> sourceEntityId = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                title: title,
                reminderType: reminderType,
                dueDate: dueDate,
                leadDays: leadDays,
                repeatRule: repeatRule,
                isEnabled: isEnabled,
                isCompleted: isCompleted,
                sourceEntityType: sourceEntityType,
                sourceEntityId: sourceEntityId,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String reminderType,
                Value<DateTime?> dueDate = const Value.absent(),
                Value<int> leadDays = const Value.absent(),
                Value<String?> repeatRule = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> sourceEntityType = const Value.absent(),
                Value<int?> sourceEntityId = const Value.absent(),
                Value<String?> remark = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                title: title,
                reminderType: reminderType,
                dueDate: dueDate,
                leadDays: leadDays,
                repeatRule: repeatRule,
                isEnabled: isEnabled,
                isCompleted: isCompleted,
                sourceEntityType: sourceEntityType,
                sourceEntityId: sourceEntityId,
                remark: remark,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RemindersTable, Reminder>(table),
                  BaseReferences<_$AppDatabase, $RemindersTable, Reminder>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemindersTable,
      Reminder,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (Reminder, BaseReferences<_$AppDatabase, $RemindersTable, Reminder>),
      Reminder,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AttendanceGroupsTableTableManager get attendanceGroups =>
      $$AttendanceGroupsTableTableManager(_db, _db.attendanceGroups);
  $$EmployeesTableTableManager get employees =>
      $$EmployeesTableTableManager(_db, _db.employees);
  $$AttendanceGroupMembersTableTableManager get attendanceGroupMembers =>
      $$AttendanceGroupMembersTableTableManager(
        _db,
        _db.attendanceGroupMembers,
      );
  $$MonthlyAttendanceRostersTableTableManager get monthlyAttendanceRosters =>
      $$MonthlyAttendanceRostersTableTableManager(
        _db,
        _db.monthlyAttendanceRosters,
      );
  $$AttendanceRecordsTableTableManager get attendanceRecords =>
      $$AttendanceRecordsTableTableManager(_db, _db.attendanceRecords);
  $$LeaveRecordsTableTableManager get leaveRecords =>
      $$LeaveRecordsTableTableManager(_db, _db.leaveRecords);
  $$OvertimeRecordsTableTableManager get overtimeRecords =>
      $$OvertimeRecordsTableTableManager(_db, _db.overtimeRecords);
  $$TerminationRecordsTableTableManager get terminationRecords =>
      $$TerminationRecordsTableTableManager(_db, _db.terminationRecords);
  $$MonthlyAttendanceSummariesTableTableManager
  get monthlyAttendanceSummaries =>
      $$MonthlyAttendanceSummariesTableTableManager(
        _db,
        _db.monthlyAttendanceSummaries,
      );
  $$InsuranceProfilesTableTableManager get insuranceProfiles =>
      $$InsuranceProfilesTableTableManager(_db, _db.insuranceProfiles);
  $$InsuranceChangeRecordsTableTableManager get insuranceChangeRecords =>
      $$InsuranceChangeRecordsTableTableManager(
        _db,
        _db.insuranceChangeRecords,
      );
  $$SocialSecurityBaseHistoryTableTableManager get socialSecurityBaseHistory =>
      $$SocialSecurityBaseHistoryTableTableManager(
        _db,
        _db.socialSecurityBaseHistory,
      );
  $$OperationLogsTableTableManager get operationLogs =>
      $$OperationLogsTableTableManager(_db, _db.operationLogs);
  $$DictionaryItemsTableTableManager get dictionaryItems =>
      $$DictionaryItemsTableTableManager(_db, _db.dictionaryItems);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
}
