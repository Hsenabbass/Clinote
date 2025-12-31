import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  static const _dbName = 'mama.db';
  static const _dbVersion = 1;

  Database? _db;
  Future<Database>? _opening;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    final opening = _opening;
    if (opening != null) return opening;
    final started = _open();
    _opening = started;
    try {
      final opened = await started;
      _db = opened;
      return opened;
    } finally {
      _opening = null;
    }
  }

  Future<String> dbPath() async {
    final dir = await getApplicationSupportDirectory();
    await Directory(dir.path).create(recursive: true);
    return p.join(dir.path, _dbName);
  }

  Future<Database> _open() async {
    final path = await dbPath();
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onCreate: (db, version) async {
          await _createSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Future migrations here
        },
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NULL,
        father_name TEXT NULL,
        last_name TEXT NULL,
        phone TEXT NULL,
        birth_year INTEGER NULL,
        last_visited TEXT NULL,
        notes TEXT NULL
      );
    ''');

    await db.execute('CREATE INDEX IF NOT EXISTS idx_patients_last_visited ON patients(last_visited);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_patients_birth_year ON patients(birth_year);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(first_name, father_name, last_name);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_patients_phone ON patients(phone);');
  }

  Future<void> close() async {
    final d = _db;
    _db = null;
    _opening = null;
    if (d != null) await d.close();
  }

  /// Replace current DB file with [sourcePath]. Caller should confirm with user.
  Future<void> replaceDbFile(String sourcePath) async {
    await close();
    final target = await dbPath();
    await File(sourcePath).copy(target);
    // reopen lazily next time
  }
}
