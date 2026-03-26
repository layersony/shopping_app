import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import '../models/shopping_item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<void> initFactory() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android/iOS use default sqflite factory — no setup needed
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'shopping.db');
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
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
  }

  Future<ShoppingItem> create(ShoppingItem item) async {
    final db = await instance.database;
    await db.insert('shopping_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return item;
  }

  Future<List<ShoppingItem>> readAll({bool includeDeleted = false}) async {
    final db = await instance.database;
    final maps = await db.query(
      'shopping_items',
      where: includeDeleted ? null : 'is_deleted = ?',
      whereArgs: includeDeleted ? null : [0],
      orderBy: 'category, name',
    );
    return maps.map((m) => ShoppingItem.fromMap(m)).toList();
  }

  Future<ShoppingItem?> readById(String id) async {
    final db = await instance.database;
    final maps = await db.query('shopping_items', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ShoppingItem.fromMap(maps.first);
  }

  Future<void> update(ShoppingItem item) async {
    final db = await instance.database;
    await db.update(
      'shopping_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // Soft delete — keeps record for sync
  Future<void> softDelete(String id) async {
    final db = await instance.database;
    await db.update(
      'shopping_items',
      {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> upsert(ShoppingItem item) async {
    final db = await instance.database;
    await db.insert('shopping_items', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ShoppingItem>> getUpdatedSince(DateTime since) async {
    final db = await instance.database;
    final maps = await db.query(
      'shopping_items',
      where: 'updated_at > ?',
      whereArgs: [since.toIso8601String()],
    );
    return maps.map((m) => ShoppingItem.fromMap(m)).toList();
  }
}