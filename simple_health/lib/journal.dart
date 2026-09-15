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

abstract class JournalRepository {
  Future<JournalSnapshot> load(String day);
  Future<void> saveEntry(FoodEntry entry);
  Future<void> deleteEntry(int id);
  Future<void> setGoal(int goal);
}

class SqliteJournal implements JournalRepository {
  SqliteJournal({DatabaseFactory? factory, this.databasePath})
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
        path.join(await _factory.getDatabasesPath(), 'daily_fuel.db'),
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE entries ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, day TEXT NOT NULL, '
          'name TEXT NOT NULL, meal INTEGER NOT NULL CHECK(meal BETWEEN 0 AND 3), '
          'calories INTEGER NOT NULL CHECK(calories >= 0), '
          'servings REAL NOT NULL CHECK(servings > 0))',
        );
        await db.execute('CREATE INDEX entries_day ON entries(day)');
        await db.execute(
          'CREATE TABLE settings (id INTEGER PRIMARY KEY, '
          'goal INTEGER NOT NULL CHECK(goal > 0))',
        );
      },
    ),
  );

  @override
  Future<JournalSnapshot> load(String day) async {
    final db = await _database();
    return db.transaction((txn) async {
      final rows = await txn.query(
        'entries',
        where: 'day = ?',
        whereArgs: [day],
        orderBy: 'id ASC',
      );
      final goals = await txn.query('settings', where: 'id = 1');
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
    if (entry.id == null) {
      await db.insert('entries', entry.toMap());
    } else {
      await db.update(
        'entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    }
  }

  @override
  Future<void> deleteEntry(int id) async {
    await (await _database()).delete(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> setGoal(int goal) async {
    if (goal <= 0) throw ArgumentError('Goal must be positive');
    await (await _database()).insert('settings', {
      'id': 1,
      'goal': goal,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    if (_opening != null) await (await _opening!).close();
    _opening = null;
  }
}
