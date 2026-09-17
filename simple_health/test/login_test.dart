import 'package:simple_health/auth.dart';
import 'package:simple_health/journal.dart';
import 'package:simple_health/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryAuth implements AuthRepository {
  final Map<String, ({int id, String password})> _usersByUsername = {};
  int _nextId = 1;

  @override
  Future<AppUser> register(String username, String password) async {
    final key = username.trim().toLowerCase();
    if (_usersByUsername.containsKey(key)) {
      throw UsernameTakenException(username);
    }
    final id = _nextId++;
    _usersByUsername[key] = (id: id, password: password);
    return AppUser(id: id, username: username.trim());
  }

  @override
  Future<AppUser?> login(String username, String password) async {
    final key = username.trim().toLowerCase();
    final user = _usersByUsername[key];
    if (user == null || user.password != password) return null;
    return AppUser(id: user.id, username: username.trim());
  }
}

class MemoryJournal implements JournalRepository {
  final entries = <FoodEntry>[];
  int? goal;
  @override
  Future<JournalSnapshot> load(String day) async =>
      JournalSnapshot(entries.where((e) => e.date == day).toList(), goal);
  @override
  Future<void> saveEntry(FoodEntry entry) async => entries.add(entry);
  @override
  Future<void> deleteEntry(int id) async =>
      entries.removeWhere((e) => e.id == id);
  @override
  Future<void> setGoal(int value) async => goal = value;
  @override
  Future<List<QuickAddFood>> recentFoods({int limit = 8}) async => [];
}

/// Mimics the production `journalRepositoryFor` factory: a fresh, isolated
/// journal per user id, reused if the same user logs in again.
class MemoryJournalFactory {
  final Map<int, MemoryJournal> _journalsByUserId = {};
  JournalRepository call(AppUser user) =>
      _journalsByUserId.putIfAbsent(user.id, MemoryJournal.new);
}

void main() {
  testWidgets('shows an error for invalid credentials and does not proceed', (
    tester,
  ) async {
    await tester.pumpWidget(
      SimpleHealthApp(
        authRepository: MemoryAuth(),
        journalRepositoryFor: MemoryJournalFactory().call,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('loginUsername')), 'nobody');
    await tester.enterText(find.byKey(const Key('loginPassword')), 'whatever');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect username or password.'), findsOneWidget);
    expect(find.text('Log food'), findsNothing);
  });

  testWidgets('registers a new account and lands in the food journal', (
    tester,
  ) async {
    await tester.pumpWidget(
      SimpleHealthApp(
        authRepository: MemoryAuth(),
        journalRepositoryFor: MemoryJournalFactory().call,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Don't have an account? Sign up"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('registerUsername')), 'taylor');
    await tester.enterText(
      find.byKey(const Key('registerPassword')),
      'password1',
    );
    await tester.enterText(
      find.byKey(const Key('registerConfirmPassword')),
      'password1',
    );
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Log food'), findsOneWidget);
  });

  testWidgets('logs in with valid credentials and can log out again', (
    tester,
  ) async {
    final auth = MemoryAuth();
    await auth.register('morgan', 'letmein1');

    await tester.pumpWidget(
      SimpleHealthApp(
        authRepository: auth,
        journalRepositoryFor: MemoryJournalFactory().call,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('loginUsername')), 'morgan');
    await tester.enterText(find.byKey(const Key('loginPassword')), 'letmein1');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Log food'), findsOneWidget);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('each account only ever sees its own food journal', (
    tester,
  ) async {
    final auth = MemoryAuth();
    final journalFor = MemoryJournalFactory();
    await tester.pumpWidget(
      SimpleHealthApp(
        authRepository: auth,
        journalRepositoryFor: journalFor.call,
      ),
    );
    await tester.pumpAndSettle();

    Future<void> signUp(String username, String password) async {
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('registerUsername')),
        username,
      );
      await tester.enterText(
        find.byKey(const Key('registerPassword')),
        password,
      );
      await tester.enterText(
        find.byKey(const Key('registerConfirmPassword')),
        password,
      );
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
    }

    Future<void> logIn(String username, String password) async {
      await tester.enterText(find.byKey(const Key('loginUsername')), username);
      await tester.enterText(find.byKey(const Key('loginPassword')), password);
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
    }

    Future<void> logFood(String name) async {
      await tester.tap(find.text('Log food'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('foodName')), name);
      await tester.enterText(find.byKey(const Key('foodCalories')), '100');
      await tester.ensureVisible(find.text('Add to journal'));
      await tester.tap(find.text('Add to journal'));
      await tester.pumpAndSettle();
    }

    // Alice registers and logs a food entry only she should see.
    await signUp('alice', 'password1');
    await logFood('Alice smoothie');
    expect(find.text('Alice smoothie'), findsOneWidget);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    // Bob registers a separate account and should start with an empty journal.
    await signUp('bob', 'password2');
    expect(find.text('Alice smoothie'), findsNothing);
    await logFood('Bob burrito');
    expect(find.text('Bob burrito'), findsOneWidget);
    expect(find.text('Alice smoothie'), findsNothing);

    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    // Back to Alice: she should see only her own entry, not Bob's.
    await logIn('alice', 'password1');
    expect(find.text('Alice smoothie'), findsOneWidget);
    expect(find.text('Bob burrito'), findsNothing);
  });
}
