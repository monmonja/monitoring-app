import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import 'models/watch.dart';

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

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const boolType = 'BOOLEAN NOT NULL';

    await db.execute('''
CREATE TABLE watches (
  id $idType,
  name $textType,
  url $textType,
  intervalMinutes $integerType,
  expectedStatus $integerType,
  expectedString $textNullableType,
  lastStatus $integerType,
  lastCheckTime $textType,
  isActive $boolType
)
''');
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
    return await db.delete(
      'watches',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAll() async {
    final db = await instance.database;
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
