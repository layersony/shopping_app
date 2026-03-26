import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static const _dbName = 'shopping.db';

  static Future<String> _getPath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, _dbName);
  }

  // 🔥 DELETE DB
  static Future<void> resetDatabase() async {
    final path = await _getPath();
    await deleteDatabase(path);
    print('Database deleted');
  }

  // 🚀 INIT DB
  static Future<Database> initDb() async {
    final path = await _getPath();

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shopping_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            estimated_price REAL NOT NULL,
            actual_price REAL,
            is_bought INTEGER NOT NULL DEFAULT 0,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }
}