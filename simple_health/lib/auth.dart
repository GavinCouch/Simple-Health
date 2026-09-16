import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppUser {
  const AppUser({required this.id, required this.username});
  final int id;
  final String username;
}

class UsernameTakenException implements Exception {
  const UsernameTakenException(this.username);
  final String username;
}

abstract class AuthRepository {
  /// Returns the matching user, or null if the credentials are invalid.
  Future<AppUser?> login(String username, String password);

  /// Creates and signs in a new user. Throws [UsernameTakenException] if the
  /// username is already registered.
  Future<AppUser> register(String username, String password);
}

class SqliteAuthRepository implements AuthRepository {
  SqliteAuthRepository({DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? databaseFactory;
  final DatabaseFactory _factory;
  final String? databasePath;
  Future<Database>? _opening;

  Future<Database> _database() async {
    if (_opening != null) return _opening!;
    final opening = _open();
    _opening = opening;
    try {
      return await opening;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async => _factory.openDatabase(
    databasePath ??
        path.join(await _factory.getDatabasesPath(), 'daily_fuel_users.db'),
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE users ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'username TEXT NOT NULL UNIQUE COLLATE NOCASE, '
          'password_hash TEXT NOT NULL)',
        );
      },
    ),
  );

  String _generateSalt([int length = 16]) {
    final random = Random.secure();
    return base64Url.encode(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  String _hashPassword(String password, String salt) =>
      '$salt:${sha256.convert(utf8.encode('$salt:$password'))}';

  bool _passwordMatches(String password, String storedHash) {
    final salt = storedHash.split(':').first;
    return _hashPassword(password, salt) == storedHash;
  }

  @override
  Future<AppUser> register(String username, String password) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) throw ArgumentError('Username is required');
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters');
    }
    final db = await _database();
    final hash = _hashPassword(password, _generateSalt());
    try {
      final id = await db.insert('users', {
        'username': trimmed,
        'password_hash': hash,
      });
      return AppUser(id: id, username: trimmed);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw UsernameTakenException(trimmed);
      rethrow;
    }
  }

  @override
  Future<AppUser?> login(String username, String password) async {
    final db = await _database();
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    if (!_passwordMatches(password, row['password_hash'] as String)) {
      return null;
    }
    return AppUser(id: row['id'] as int, username: row['username'] as String);
  }

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
    _opening = null;
  }
}
