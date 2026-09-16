import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/food_entry.dart';
import '../models/user.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'simple_health.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            daily_goal INTEGER NOT NULL DEFAULT 2000
          )
        ''');

        await db.execute('''
          CREATE TABLE food_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            calories INTEGER NOT NULL,
            date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_food_entries_user_date ON food_entries (user_id, date)',
        );
      },
    );
  }

  // ---------- Password hashing ----------

  String _generateSalt([int length = 16]) {
    final random = Random.secure();
    final saltBytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(saltBytes);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return '$salt:${sha256.convert(bytes)}';
  }

  bool _verifyPassword(String password, String storedHash) {
    final salt = storedHash.split(':').first;
    return _hashPassword(password, salt) == storedHash;
  }

  // ---------- User auth ----------

  Future<bool> usernameExists(String username) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Returns the new user's id, or null if the username is already taken.
  Future<int?> registerUser(String username, String password) async {
    final db = await database;
    if (await usernameExists(username)) {
      return null;
    }
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    return db.insert('users', {
      'username': username,
      'password_hash': hash,
      'daily_goal': 2000,
    });
  }

  /// Returns the matching [User] if the credentials are valid, else null.
  Future<User?> login(String username, String password) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (result.isEmpty) return null;

    final user = User.fromMap(result.first);
    if (_verifyPassword(password, user.passwordHash)) {
      return user;
    }
    return null;
  }

  Future<void> updateDailyGoal(int userId, int dailyGoal) async {
    final db = await database;
    await db.update(
      'users',
      {'daily_goal': dailyGoal},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // ---------- Food entries ----------

  Future<int> addFoodEntry(FoodEntry entry) async {
    final db = await database;
    return db.insert('food_entries', entry.toMap()..remove('id'));
  }

  Future<int> deleteFoodEntry(int id) async {
    final db = await database;
    return db.delete('food_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FoodEntry>> getEntriesForDate(int userId, String date) async {
    final db = await database;
    final result = await db.query(
      'food_entries',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      orderBy: 'created_at DESC',
    );
    return result.map(FoodEntry.fromMap).toList();
  }

  Future<int> getTotalCaloriesForDate(int userId, String date) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(calories), 0) as total FROM food_entries '
      'WHERE user_id = ? AND date = ?',
      [userId, date],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
