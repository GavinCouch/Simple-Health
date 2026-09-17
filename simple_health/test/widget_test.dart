import 'package:simple_health/app.dart';
import 'package:simple_health/journal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryJournal implements JournalRepository {
  final entries = <FoodEntry>[];
  int? goal;
  bool failSave = false;
  @override
  Future<JournalSnapshot> load(String day) async => JournalSnapshot(
    entries.where((entry) => entry.date == day).toList(),
    goal,
  );
  @override
  Future<void> saveEntry(FoodEntry entry) async {
    if (failSave) throw StateError('disk unavailable');
    entries.removeWhere((old) => old.id == entry.id && entry.id != null);
    entries.add(
      FoodEntry(
        id: entry.id ?? entries.length + 1,
        date: entry.date,
        name: entry.name,
        meal: entry.meal,
        calories: entry.calories,
        servings: entry.servings,
      ),
    );
  }

  @override
  Future<void> deleteEntry(int id) async {
    entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> setGoal(int value) async {
    goal = value;
  }

  @override
  Future<List<QuickAddFood>> recentFoods({int limit = 8}) async {
    final groups = <String, List<FoodEntry>>{};
    for (final entry in entries) {
      groups
          .putIfAbsent(
            '${entry.name.trim().toLowerCase()}|${entry.calories}',
            () => [],
          )
          .add(entry);
    }
    final ranked = groups.values.toList()
      ..sort((a, b) {
        final byFrequency = b.length.compareTo(a.length);
        if (byFrequency != 0) return byFrequency;
        return entries.indexOf(b.last).compareTo(entries.indexOf(a.last));
      });
    return [
      for (final group in ranked.take(limit))
        QuickAddFood(
          name: group.last.name,
          calories: group.last.calories,
          servings: group.last.servings,
        ),
    ];
  }
}

void main() {
  testWidgets('log fractional servings and navigate history', (tester) async {
    final repository = MemoryJournal();
    await tester.pumpWidget(DailyFuelApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log food'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('foodName')), 'Oatmeal');
    await tester.enterText(find.byKey(const Key('foodCalories')), '250');
    await tester.enterText(find.byKey(const Key('foodServings')), '1.5');
    await tester.ensureVisible(find.text('Add to journal'));
    await tester.tap(find.text('Add to journal'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.total, 375);
    expect(find.text('Oatmeal'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous day'));
    await tester.pumpAndSettle();
    expect(find.text('Oatmeal'), findsNothing);
    await tester.tap(find.byTooltip('Next day'));
    await tester.pumpAndSettle();
    expect(find.text('Oatmeal'), findsOneWidget);
  });
  testWidgets('failed save keeps input and supports retry', (tester) async {
    final repository = MemoryJournal()..failSave = true;
    await tester.pumpWidget(DailyFuelApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log food'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('foodName')), 'Toast');
    await tester.enterText(find.byKey(const Key('foodCalories')), '120');
    await tester.ensureVisible(find.text('Add to journal'));
    await tester.tap(find.text('Add to journal'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save.'), findsOneWidget);
    expect(find.text('Toast'), findsOneWidget);
    expect(repository.entries, isEmpty);
    repository.failSave = false;
    await tester.ensureVisible(find.text('Add to journal'));
    await tester.tap(find.text('Add to journal'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.name, 'Toast');
  });
  testWidgets(
    'shows a quick-add suggestion after logging a food once and prefills on tap',
    (tester) async {
      final repository = MemoryJournal();
      await tester.pumpWidget(DailyFuelApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log food'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('foodName')),
        'Chicken Salad',
      );
      await tester.enterText(find.byKey(const Key('foodCalories')), '450');
      await tester.ensureVisible(find.text('Add to journal'));
      await tester.tap(find.text('Add to journal'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log food'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quickAddRow')), findsOneWidget);
      expect(find.byKey(const Key('quickAddChip_0')), findsOneWidget);
      expect(find.text('Chicken Salad · 450 kcal'), findsOneWidget);

      await tester.tap(find.byKey(const Key('quickAddChip_0')));
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextFormField>(
        find.byKey(const Key('foodName')),
      );
      expect(nameField.controller!.text, 'Chicken Salad');
      final caloriesField = tester.widget<TextFormField>(
        find.byKey(const Key('foodCalories')),
      );
      expect(caloriesField.controller!.text, '450');
      // Tapping only prefills the form; it must not auto-save.
      expect(repository.entries.length, 1);
    },
  );
  testWidgets('small screen supports large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(DailyFuelApp(repository: MemoryJournal()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Log food'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
