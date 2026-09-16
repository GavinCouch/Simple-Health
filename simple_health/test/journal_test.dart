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
}
