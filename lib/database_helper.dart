import 'dart:convert';


import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';


import 'models/watch.dart';
import 'models/watch_log.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('watches.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const integerNullableType = 'INTEGER';
    const boolType = 'BOOLEAN NOT NULL';

    await db.execute('''
CREATE TABLE watches (
  id $idType,
  name $textType,
  url $textType,
  intervalMinutes $integerType,
  expectedStatus $integerType,
  keyword $textNullableType,
  lastStatus $integerType,
  lastCheckTime $textType,
  isActive $boolType
)
''');

    await db.execute('''
CREATE TABLE watch_logs (
  id $idType,
  watchId $integerType,
  timestamp $textType,
  status $boolType,
  statusCode $integerNullableType,
  errorMessage $textNullableType,
  FOREIGN KEY (watchId) REFERENCES watches (id) ON DELETE CASCADE
)
''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      const textNullableType = 'TEXT';
      const integerType = 'INTEGER NOT NULL';
      const integerNullableType = 'INTEGER';
      const boolType = 'BOOLEAN NOT NULL';

      await db.execute('''
CREATE TABLE watch_logs (
  id $idType,
  watchId $integerType,
  timestamp $textType,
  status $boolType,
  statusCode $integerNullableType,
  errorMessage $textNullableType,
  FOREIGN KEY (watchId) REFERENCES watches (id) ON DELETE CASCADE
)
''');
    }
    if (oldVersion < 3) {
      // Handle the rename of expectedString to keyword.
      // SQLite doesn't directly support RENAME COLUMN in all versions commonly used,
      // but newer versions do. Let's just add the column if it doesn't exist.
      // Since we just changed expectedString to keyword in the create statement,
      // let's alter table.
      try {
        await db.execute('ALTER TABLE watches RENAME COLUMN expectedString TO keyword');
      } catch (e) {
        // If rename fails (older sqlite), add column
        await db.execute('ALTER TABLE watches ADD COLUMN keyword TEXT');
        // Migrate data
        await db.execute('UPDATE watches SET keyword = expectedString');
      }
    }
  }

  Future<Watch> create(Watch watch) async {
    final db = await instance.database;
    final id = await db.insert('watches', watch.toMap());
    return watch.copyWith(id: id);
  }

  Future<Watch?> readWatch(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'watches',
      columns: WatchFields.values,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Watch.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Watch>> readAllWatches() async {
    final db = await instance.database;
    const orderBy = 'id ASC';
    final result = await db.query('watches', orderBy: orderBy);
    return result.map((json) => Watch.fromMap(json)).toList();
  }

  Future<int> update(Watch watch) async {
    final db = await instance.database;
    return db.update(
      'watches',
      watch.toMap(),
      where: 'id = ?',
      whereArgs: [watch.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    await db.delete(
      'watch_logs',
      where: 'watchId = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'watches',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAll() async {
    final db = await instance.database;
    await db.delete('watch_logs');
    return await db.delete('watches');
  }

  Future<String> exportData() async {
    final watches = await readAllWatches();
    final List<Map<String, dynamic>> maps = watches.map((w) => w.toMap()).toList();
    final String jsonString = jsonEncode(maps);
    return jsonString;
  }

  Future<void> importData(String jsonString) async {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final List<Watch> watches = jsonList.map((j) => Watch.fromMap(j as Map<String, dynamic>)).toList();

    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('watches');
      for (final watch in watches) {
        await txn.insert('watches', watch.toMap());
      }
    });
  }


  Future<WatchLog> createWatchLog(WatchLog log) async {
    final db = await instance.database;
    final id = await db.insert('watch_logs', log.toMap());
    return log.copyWith(id: id);
  }

  Future<List<WatchLog>> readWatchLogs(int watchId) async {
    final db = await instance.database;
    const orderBy = 'timestamp ASC';
    final result = await db.query(
      'watch_logs',
      where: 'watchId = ?',
      whereArgs: [watchId],
      orderBy: orderBy,
    );
    return result.map((json) => WatchLog.fromMap(json)).toList();
  }

  Future<int> deleteOldWatchLogs(DateTime before) async {
    final db = await instance.database;
    return await db.delete(
      'watch_logs',
      where: 'timestamp < ?',
      whereArgs: [before.toIso8601String()],
    );
  }
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
