<<<<<<< HEAD
// Basic smoke test for the Simple Health app.

=======
import 'package:simple_health/app.dart';
import 'package:simple_health/journal.dart';
>>>>>>> 7873196f56c04920c754e270ef236801e659cb8e
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
}

void main() {
<<<<<<< HEAD
  testWidgets('Login screen is shown on launch', (WidgetTester tester) async {
    await tester.pumpWidget(const SimpleHealthApp());

    expect(find.text('Simple Health'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log In'), findsOneWidget);
=======
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
>>>>>>> 7873196f56c04920c754e270ef236801e659cb8e
  });
}
