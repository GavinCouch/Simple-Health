import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

enum Meal { breakfast, lunch, dinner, snacks }

extension MealLabel on Meal {
  String get label => name[0].toUpperCase() + name.substring(1);
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class FoodEntry {
  const FoodEntry({
    this.id,
    required this.date,
    required this.name,
    required this.meal,
    required this.calories,
    required this.servings,
  });

  final int? id;
  final String date;
  final String name;
  final Meal meal;
  final int calories;
  final double servings;
  int get total => (calories * servings).round();

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'day': date,
    'name': name,
    'meal': meal.index,
    'calories': calories,
    'servings': servings,
  };

  factory FoodEntry.fromMap(Map<String, Object?> map) => FoodEntry(
    id: map['id'] as int,
    date: map['day'] as String,
    name: map['name'] as String,
    meal: Meal.values[map['meal'] as int],
    calories: map['calories'] as int,
    servings: (map['servings'] as num).toDouble(),
  );
}

class JournalSnapshot {
  const JournalSnapshot(this.entries, this.goal);
  final List<FoodEntry> entries;
  final int? goal;
  int get total => entries.fold(0, (total, entry) => total + entry.total);
}

class QuickAddFood {
  const QuickAddFood({
    required this.name,
    required this.calories,
    required this.servings,
  });
  final String name;
  final int calories;
  final double servings;
}

abstract class JournalRepository {
  Future<JournalSnapshot> load(String day);
  Future<void> saveEntry(FoodEntry entry);
  Future<void> deleteEntry(int id);
  Future<void> setGoal(int goal);
  Future<List<QuickAddFood>> recentFoods({int limit = 8});
}

class SqliteJournal implements JournalRepository {
  SqliteJournal({
    required this.userId,
    DatabaseFactory? factory,
    this.databasePath,
  }) : _factory = factory ?? databaseFactory;
  final int userId;
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
        path.join(await _factory.getDatabasesPath(), 'daily_fuel.db'),
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        // Earlier versions kept a single shared journal with no owner, so
        // there is no sound way to attribute that data to a specific user.
        await db.execute('DROP TABLE IF EXISTS entries');
        await db.execute('DROP TABLE IF EXISTS settings');
        await _createSchema(db);
      },
    ),
  );

  static Future<void> _createSchema(Database db) async {
    await db.execute(
      'CREATE TABLE entries ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, '
      'day TEXT NOT NULL, '
      'name TEXT NOT NULL, meal INTEGER NOT NULL CHECK(meal BETWEEN 0 AND 3), '
      'calories INTEGER NOT NULL CHECK(calories >= 0), '
      'servings REAL NOT NULL CHECK(servings > 0))',
    );
    await db.execute('CREATE INDEX entries_user_day ON entries(user_id, day)');
    await db.execute(
      'CREATE TABLE settings (user_id INTEGER PRIMARY KEY, '
      'goal INTEGER NOT NULL CHECK(goal > 0))',
    );
  }

  @override
  Future<JournalSnapshot> load(String day) async {
    final db = await _database();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'entries',
        where: 'user_id = ? AND day = ?',
        whereArgs: [userId, day],
        orderBy: 'id ASC',
      );
      final goals = await txn.query(
        'settings',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      return JournalSnapshot(
        rows.map(FoodEntry.fromMap).toList(),
        goals.isEmpty ? null : goals.single['goal'] as int,
      );
    });
  }

  @override
  Future<void> saveEntry(FoodEntry entry) async {
    if (entry.name.trim().isEmpty ||
        entry.calories < 0 ||
        !entry.servings.isFinite ||
        entry.servings <= 0) {
      throw ArgumentError('Invalid food entry');
    }
    final db = await _database();
    final map = entry.toMap()..['user_id'] = userId;
    if (entry.id == null) {
      await db.insert('entries', map);
    } else {
      await db.update(
        'entries',
        map,
        where: 'id = ? AND user_id = ?',
        whereArgs: [entry.id, userId],
      );
    }
  }

  @override
  Future<void> deleteEntry(int id) async {
    await (await _database()).delete(
      'entries',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  @override
  Future<void> setGoal(int goal) async {
    if (goal <= 0) throw ArgumentError('Goal must be positive');
    await (await _database()).insert('settings', {
      'user_id': userId,
      'goal': goal,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<QuickAddFood>> recentFoods({int limit = 8}) async {
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT name, calories, servings, COUNT(*) AS frequency, MAX(id) AS last_id '
      'FROM entries '
      'WHERE user_id = ? '
      'GROUP BY LOWER(TRIM(name)), calories '
      'ORDER BY frequency DESC, last_id DESC '
      'LIMIT ?',
      [userId, limit],
    );
    return [
      for (final row in rows)
        QuickAddFood(
          name: row['name'] as String,
          calories: row['calories'] as int,
          servings: (row['servings'] as num).toDouble(),
        ),
    ];
  }

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
    _opening = null;
  }
}
