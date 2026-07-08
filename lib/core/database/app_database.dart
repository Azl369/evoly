import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite_mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:evoly/core/domain/priority.dart';
import 'package:evoly/features/goals/domain/goal.dart';
import 'package:evoly/features/tasks/domain/task_item.dart';

class AppDatabase {
  AppDatabase._({String? databasePathOverride})
      : _databasePathOverride = databasePathOverride;

  factory AppDatabase.testing(String databasePath) {
    return AppDatabase._(databasePathOverride: databasePath);
  }

  static final AppDatabase instance = AppDatabase._();

  final String? _databasePathOverride;
  Database? _database;

  bool get isOpened => _database != null;

  Future<Database> get database async {
    final openedDatabase = _database;
    if (openedDatabase != null) {
      return openedDatabase;
    }

    return open();
  }

  Future<Database> open() async {
    if (Platform.isAndroid || Platform.isIOS) {
      databaseFactory = sqflite_mobile.databaseFactory;
    } else {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _databasePath();
    final parent = Directory(p.dirname(dbPath));
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    _database = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
        onOpen: _enableForeignKeys,
      ),
    );

    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<String> _databasePath() async {
    final databasePathOverride = _databasePathOverride;
    if (databasePathOverride != null) {
      return databasePathOverride;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final dbDir = await sqflite_mobile.getDatabasesPath();
      return p.join(dbDir, 'evoly.db');
    }

    final appData = Platform.environment['APPDATA'];
    final baseDir = appData == null || appData.isEmpty
        ? p.join(Directory.current.path, '.evoly')
        : p.join(appData, 'Evoly');

    return p.join(baseDir, 'evoly.db');
  }

  Future<void> _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL,
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        due_date INTEGER,
        progress REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        goal_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        priority TEXT NOT NULL,
        status TEXT NOT NULL,
        estimated_minutes INTEGER NOT NULL DEFAULT 0,
        due_date_time INTEGER,
        completed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(goal_id) REFERENCES goals(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_tasks_goal_id ON tasks(goal_id)');
    await db.execute(
        'CREATE INDEX idx_tasks_due_date_time ON tasks(due_date_time)');
    await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
    await db.execute('CREATE INDEX idx_tasks_priority ON tasks(priority)');
    await db.execute('CREATE INDEX idx_tasks_sort_order ON tasks(sort_order)');

    await _createRemindersSchema(db);
    await _createDocumentsSchema(db);
    await _createSettingsSchema(db);
    await _createSyncSchema(db);

    await _seedInitialData(db);
  }

  Future<void> _upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createRemindersSchema(db);
    }
    if (oldVersion < 3) {
      await _createDocumentsSchema(db);
    }
    if (oldVersion < 4) {
      await _createSettingsSchema(db);
    }
    if (oldVersion < 5) {
      await _createSyncSchema(db);
    }
    if (oldVersion < 6) {
      await _ensureTaskSortOrderSchema(db);
    }
  }

  Future<void> _ensureTaskSortOrderSchema(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(tasks)');
    final hasSortOrder =
        columns.any((column) => column['name'] == 'sort_order');
    if (!hasSortOrder) {
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
    }

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tasks_sort_order ON tasks(sort_order)',
    );
    await db.execute('''
      UPDATE tasks
      SET sort_order = created_at
      WHERE sort_order = 0
    ''');
  }

  Future<void> _createRemindersSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id TEXT PRIMARY KEY,
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        remind_at INTEGER NOT NULL,
        repeat_rule TEXT NOT NULL,
        advance_minutes INTEGER NOT NULL DEFAULT 0,
        enabled INTEGER NOT NULL DEFAULT 1,
        fired_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_remind_at ON reminders(remind_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_target ON reminders(target_type, target_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reminders_enabled ON reminders(enabled)',
    );
  }

  Future<void> _createDocumentsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content_markdown TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_links (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_documents_updated_at ON documents(updated_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_documents_deleted_at ON documents(deleted_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_document_links_document_id ON document_links(document_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_document_links_target ON document_links(target_type, target_id)',
    );
  }

  Future<void> _createSettingsSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSyncSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_identity (
        id TEXT PRIMARY KEY,
        device_name TEXT NOT NULL,
        platform TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        base_remote_revision INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_created_at ON sync_outbox(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_entity ON sync_outbox(entity_type, entity_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_attempts ON sync_outbox(attempts)',
    );

    final now = _encodeDate(DateTime.now());
    await db.insert(
      'sync_state',
      {
        'key': 'sync_enabled',
        'value': 'false',
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.insert(
      'sync_state',
      {
        'key': 'last_pulled_revision',
        'value': '0',
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now();
    final goalId = 'goal-${now.microsecondsSinceEpoch}';

    await db.insert('goals', {
      'id': goalId,
      'title': '30 天完成 Flutter 基础',
      'description': '把学习项目拆成每日任务。',
      'type': GoalType.longTerm.name,
      'priority': Priority.high.name,
      'status': GoalStatus.inProgress.name,
      'start_date': _encodeDate(now),
      'due_date': _encodeDate(now.add(const Duration(days: 30))),
      'progress': 0,
      'created_at': _encodeDate(now),
      'updated_at': _encodeDate(now),
    });

    await db.insert('tasks', {
      'id': 'task-${now.microsecondsSinceEpoch}-1',
      'goal_id': goalId,
      'title': '阅读 Flutter 布局文档 30 分钟',
      'description': '',
      'priority': Priority.high.name,
      'status': TaskStatus.pending.name,
      'estimated_minutes': 30,
      'due_date_time': _encodeDate(now.add(const Duration(hours: 2))),
      'completed_at': null,
      'created_at': _encodeDate(now),
      'updated_at': _encodeDate(now),
      'sort_order': _encodeDate(now),
    });

    await db.insert('tasks', {
      'id': 'task-${now.microsecondsSinceEpoch}-2',
      'goal_id': goalId,
      'title': '整理今天的学习笔记',
      'description': '',
      'priority': Priority.medium.name,
      'status': TaskStatus.pending.name,
      'estimated_minutes': 20,
      'due_date_time': _encodeDate(now.add(const Duration(hours: 4))),
      'completed_at': null,
      'created_at': _encodeDate(now),
      'updated_at': _encodeDate(now),
      'sort_order': _encodeDate(now) + 1,
    });
  }

  int _encodeDate(DateTime value) => value.millisecondsSinceEpoch;
}

extension AppDatabaseDateCodec on Object {
  static int encodeDate(DateTime value) => value.millisecondsSinceEpoch;

  static DateTime decodeDate(Object value) {
    return DateTime.fromMillisecondsSinceEpoch(value as int);
  }

  static DateTime? decodeNullableDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(value as int);
  }
}
