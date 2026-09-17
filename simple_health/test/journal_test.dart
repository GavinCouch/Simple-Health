import 'dart:io';

import 'package:simple_health/journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  test(
    'database survives reopening and supports edit, delete, and date isolation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'daily_fuel_test',
      );
      final repository = SqliteJournal(
        userId: 1,
        factory: databaseFactoryFfi,
        databasePath: '${directory.path}/journal.db',
      );
      addTearDown(() async {
        await repository.close();
        await directory.delete(recursive: true);
      });
      await repository.setGoal(2100);
      await repository.saveEntry(
        const FoodEntry(
          date: '2026-09-15',
          name: 'Oats',
          meal: Meal.breakfast,
          calories: 250,
          servings: 1.5,
        ),
      );
      await repository.saveEntry(
        const FoodEntry(
          date: '2026-09-14',
          name: 'Rice',
          meal: Meal.dinner,
          calories: 200,
          servings: 1,
        ),
      );
      await repository.close();
      final snapshot = await repository.load('2026-09-15');
      expect(snapshot.goal, 2100);
      expect(snapshot.total, 375);
      expect(snapshot.entries.length, 1);
      final entry = snapshot.entries.single;
      await repository.saveEntry(
        FoodEntry(
          id: entry.id,
          date: entry.date,
          name: 'Oats updated',
          meal: Meal.lunch,
          calories: 300,
          servings: 2,
        ),
      );
      expect((await repository.load(entry.date)).total, 600);
      await repository.deleteEntry(entry.id!);
      expect((await repository.load(entry.date)).entries, isEmpty);
      expect((await repository.load('2026-09-14')).total, 200);
    },
  );

  test(
    'entries and goals are isolated between different users sharing a database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'daily_fuel_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final dbPath = '${directory.path}/journal.db';

      final alice = SqliteJournal(
        userId: 1,
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      final bob = SqliteJournal(
        userId: 2,
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      addTearDown(alice.close);
      addTearDown(bob.close);

      await alice.setGoal(2000);
      await alice.saveEntry(
        const FoodEntry(
          date: '2026-09-15',
          name: "Alice's oats",
          meal: Meal.breakfast,
          calories: 250,
          servings: 1,
        ),
      );

      await bob.setGoal(2500);
      await bob.saveEntry(
        const FoodEntry(
          date: '2026-09-15',
          name: "Bob's toast",
          meal: Meal.breakfast,
          calories: 120,
          servings: 1,
        ),
      );

      final aliceSnapshot = await alice.load('2026-09-15');
      expect(aliceSnapshot.goal, 2000);
      expect(aliceSnapshot.entries.single.name, "Alice's oats");

      final bobSnapshot = await bob.load('2026-09-15');
      expect(bobSnapshot.goal, 2500);
      expect(bobSnapshot.entries.single.name, "Bob's toast");

      // Bob cannot delete Alice's entry even if he knows its id.
      await bob.deleteEntry(aliceSnapshot.entries.single.id!);
      expect((await alice.load('2026-09-15')).entries, hasLength(1));
    },
  );

  test('recentFoods ranks by frequency, breaks ties by recency, folds '
      'case/whitespace, and stays isolated per user', () async {
    final directory = await Directory.systemTemp.createTemp('daily_fuel_test');
    final dbPath = '${directory.path}/journal.db';
    final alice = SqliteJournal(
      userId: 1,
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    final bob = SqliteJournal(
      userId: 2,
      factory: databaseFactoryFfi,
      databasePath: dbPath,
    );
    addTearDown(() async {
      await alice.close();
      await bob.close();
      await directory.delete(recursive: true);
    });

    Future<void> log(
      SqliteJournal repo,
      String date,
      String name,
      int calories,
      double servings,
    ) => repo.saveEntry(
      FoodEntry(
        date: date,
        name: name,
        meal: Meal.breakfast,
        calories: calories,
        servings: servings,
      ),
    );

    // Alice logs "coffee" three times with varying case/whitespace/servings,
    // then "Toast" once. Coffee should win on frequency; its displayed name
    // and servings should reflect the most recent (third) log.
    await log(alice, '2026-09-10', 'Coffee', 5, 1);
    await log(alice, '2026-09-11', 'coffee', 5, 1);
    await log(alice, '2026-09-12', 'Coffee ', 5, 2);
    await log(alice, '2026-09-12', 'Toast', 120, 1);

    // Bob's data must never leak into Alice's suggestions.
    await log(bob, '2026-09-12', 'Bob smoothie', 300, 1);

    final aliceRecents = await alice.recentFoods();
    expect(aliceRecents.first.name, 'Coffee ');
    expect(aliceRecents.first.calories, 5);
    expect(aliceRecents.first.servings, 2);
    expect(aliceRecents[1].name, 'Toast');

    final bobRecents = await bob.recentFoods();
    expect(bobRecents.single.name, 'Bob smoothie');
  });
}
