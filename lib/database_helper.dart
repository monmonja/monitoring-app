import 'dart:convert';


import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/domain.dart';
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

    // Bumping version to 8 for uptime cache
    return await openDatabase(path, version: 8, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const integerNullableType = 'INTEGER';
    const boolType = 'BOOLEAN NOT NULL';

    await db.execute('''
CREATE TABLE domains (
  id $idType,
  name $textType,
  url $textType
)
''');

    await db.execute('''
CREATE TABLE watches (
  id $idType,
  domainId $integerType,
  name $textType,
  url $textType,
  intervalMinutes $integerType,
  expectedStatus $integerType,
  keyword $textNullableType,
  lastStatus $integerNullableType,
  lastCheckTime $textNullableType,
  isActive $boolType,
  consecutiveFails INTEGER NOT NULL DEFAULT 0,
  latencyThreshold INTEGER,
  alertOnSslExpiry BOOLEAN NOT NULL DEFAULT 0,
  checkKeywordAbsence BOOLEAN NOT NULL DEFAULT 0,
  httpMethod TEXT NOT NULL DEFAULT 'HEAD',
  httpHeaders TEXT,
  httpBody TEXT,
  wifiOnly BOOLEAN NOT NULL DEFAULT 1,
  uptime7Days REAL,
  uptime30Days REAL,
  FOREIGN KEY (domainId) REFERENCES domains (id) ON DELETE CASCADE
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
  responseTimeMs $integerNullableType,
  FOREIGN KEY (watchId) REFERENCES watches (id) ON DELETE CASCADE
)
''');

    // Add index for fast query execution
    await db.execute('CREATE INDEX IF NOT EXISTS idx_watch_logs_timestamp ON watch_logs (timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_watch_logs_watchId ON watch_logs (watchId)');
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
      try {
        await db.execute('ALTER TABLE watches RENAME COLUMN expectedString TO keyword');
      } catch (e) {
        await db.execute('ALTER TABLE watches ADD COLUMN keyword TEXT');
        await db.execute('UPDATE watches SET keyword = expectedString');
      }
    }
    if (oldVersion < 4) {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';

      await db.execute('''
CREATE TABLE domains (
  id $idType,
  name $textType,
  url $textType
)
''');

      int defaultDomainId = await db.insert('domains', {
        'name': 'Default Domain',
        'url': 'http://localhost'
      });

      await db.execute('ALTER TABLE watches ADD COLUMN domainId INTEGER DEFAULT $defaultDomainId');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE watches ADD COLUMN consecutiveFails INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE watches ADD COLUMN latencyThreshold INTEGER');
      await db.execute('ALTER TABLE watches ADD COLUMN alertOnSslExpiry BOOLEAN NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE watches ADD COLUMN checkKeywordAbsence BOOLEAN NOT NULL DEFAULT 0');

      await db.execute('ALTER TABLE watch_logs ADD COLUMN responseTimeMs INTEGER');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE watches ADD COLUMN httpMethod TEXT NOT NULL DEFAULT "HEAD"');
      await db.execute('ALTER TABLE watches ADD COLUMN httpHeaders TEXT');
      await db.execute('ALTER TABLE watches ADD COLUMN httpBody TEXT');
    }
    if (oldVersion < 7) {
      await db.execute('ALTER TABLE watches ADD COLUMN wifiOnly BOOLEAN NOT NULL DEFAULT 1');

      // Add index for fast query execution
      await db.execute('CREATE INDEX IF NOT EXISTS idx_watch_logs_timestamp ON watch_logs (timestamp)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_watch_logs_watchId ON watch_logs (watchId)');
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE watches ADD COLUMN uptime7Days REAL');
      await db.execute('ALTER TABLE watches ADD COLUMN uptime30Days REAL');
    }
  }

  // --- Domain Methods ---

  Future<Domain> createDomain(Domain domain) async {
    final db = await instance.database;
    final id = await db.insert('domains', domain.toMap());
    return domain.copyWith(id: id);
  }

  Future<Domain?> readDomain(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'domains',
      columns: DomainFields.values,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Domain.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Domain>> readAllDomains() async {
    final db = await instance.database;
    const orderBy = 'name ASC';
    final result = await db.query('domains', orderBy: orderBy);
    return result.map((json) => Domain.fromMap(json)).toList();
  }

  Future<int> updateDomain(Domain domain) async {
    final db = await instance.database;
    return db.update(
      'domains',
      domain.toMap(),
      where: 'id = ?',
      whereArgs: [domain.id],
    );
  }

  Future<int> deleteDomain(int id) async {
    final db = await instance.database;
    final watches = await readWatchesForDomain(id);
    for (var w in watches) {
      await delete(w.id!);
    }
    return await db.delete(
      'domains',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Watch Methods ---

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

  Future<List<Watch>> readWatchesForDomain(int domainId) async {
    final db = await instance.database;
    const orderBy = 'id ASC';
    final result = await db.query('watches', where: 'domainId = ?', whereArgs: [domainId], orderBy: orderBy);
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
    await db.delete('watches');
    return await db.delete('domains');
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
    final count = await db.delete(
      'watch_logs',
      where: 'timestamp < ?',
      whereArgs: [before.toIso8601String()],
    );
    if (count > 0) {
      await db.execute('VACUUM');
    }
    return count;
  }
  Future<void> calculateAndSaveUptime(int watchId) async {
    final watch = await readWatch(watchId);
    if (watch == null) return;

    final logs = await readWatchLogs(watchId);
    if (logs.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final includeSkipped = prefs.getBool('include_skipped_in_uptime') ?? false;

    final now = DateTime.now();

    double? calcUptime(int days) {
      final periodStart = now.subtract(Duration(days: days));

      // Filter logs to those relevant to the period.
      // We also need the state right before the period starts.
      WatchLog? lastLogBeforePeriod;
      List<WatchLog> periodLogs = [];

      for (var log in logs) {
        if (log.timestamp.isBefore(periodStart)) {
          lastLogBeforePeriod = log;
        } else {
          periodLogs.add(log);
        }
      }

      // If there are no logs at all before or during the period, return null
      if (lastLogBeforePeriod == null && periodLogs.isEmpty) {
        return null;
      }

      // Start calculating from either periodStart or the first log's time
      DateTime calculationStartTime = periodStart;
      if (lastLogBeforePeriod == null && periodLogs.isNotEmpty) {
        calculationStartTime = periodLogs.first.timestamp;
      }

      int totalDurationMs = now.difference(calculationStartTime).inMilliseconds;
      if (totalDurationMs <= 0) return null;

      int uptimeDurationMs = 0;

      // Determine initial state
      bool isCurrentlyUp = true;
      if (lastLogBeforePeriod != null) {
        bool isSkipped = !lastLogBeforePeriod.status && lastLogBeforePeriod.errorMessage != null && lastLogBeforePeriod.errorMessage!.startsWith('Skipped:');
        if (isSkipped) {
           isCurrentlyUp = !includeSkipped;
        } else {
           isCurrentlyUp = lastLogBeforePeriod.status;
        }
      } else if (periodLogs.isNotEmpty) {
        bool isSkipped = !periodLogs.first.status && periodLogs.first.errorMessage != null && periodLogs.first.errorMessage!.startsWith('Skipped:');
        if (isSkipped) {
           isCurrentlyUp = !includeSkipped;
        } else {
           isCurrentlyUp = periodLogs.first.status;
        }
      }

      DateTime lastStateChangeTime = calculationStartTime;

      for (var log in periodLogs) {
        bool isSkipped = !log.status && log.errorMessage != null && log.errorMessage!.startsWith('Skipped:');
        bool newUpState;

        if (isSkipped) {
            if (includeSkipped) {
                newUpState = false; // It's downtime
            } else {
                continue; // Ignore skipped check, state continues as it was
            }
        } else {
            newUpState = log.status;
        }

        if (newUpState != isCurrentlyUp) {
            if (isCurrentlyUp) {
                uptimeDurationMs += log.timestamp.difference(lastStateChangeTime).inMilliseconds;
            }
            isCurrentlyUp = newUpState;
            lastStateChangeTime = log.timestamp;
        }
      }

      // Add final segment to now
      if (isCurrentlyUp) {
          uptimeDurationMs += now.difference(lastStateChangeTime).inMilliseconds;
      }

      return (uptimeDurationMs / totalDurationMs) * 100.0;
    }

    final uptime7 = calcUptime(7);
    final uptime30 = calcUptime(30);

    final updatedWatch = watch.copyWith(
      uptime7Days: uptime7,
      uptime30Days: uptime30,
    );
    await update(updatedWatch);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
