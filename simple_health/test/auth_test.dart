import 'dart:io';

import 'package:simple_health/auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<SqliteAuthRepository> openRepository(Directory directory) async {
    final repository = SqliteAuthRepository(
      factory: databaseFactoryFfi,
      databasePath: '${directory.path}/users.db',
    );
    addTearDown(repository.close);
    return repository;
  }

  test(
    'registers a user and signs them in with matching credentials',
    () async {
      final directory = await Directory.systemTemp.createTemp('auth_test');
      addTearDown(() => directory.delete(recursive: true));
      final repository = await openRepository(directory);

      final registered = await repository.register('alice', 'hunter22');
      expect(registered.username, 'alice');

      final loggedIn = await repository.login('alice', 'hunter22');
      expect(loggedIn?.id, registered.id);
    },
  );

  test('rejects a login with the wrong password', () async {
    final directory = await Directory.systemTemp.createTemp('auth_test');
    addTearDown(() => directory.delete(recursive: true));
    final repository = await openRepository(directory);

    await repository.register('bob', 'correcthorse');
    expect(await repository.login('bob', 'wrongpassword'), isNull);
  });

  test('rejects a login for an unknown username', () async {
    final directory = await Directory.systemTemp.createTemp('auth_test');
    addTearDown(() => directory.delete(recursive: true));
    final repository = await openRepository(directory);

    expect(await repository.login('nobody', 'whatever1'), isNull);
  });

  test('throws when registering a username that is already taken', () async {
    final directory = await Directory.systemTemp.createTemp('auth_test');
    addTearDown(() => directory.delete(recursive: true));
    final repository = await openRepository(directory);

    await repository.register('carol', 'password1');
    expect(
      () => repository.register('carol', 'password2'),
      throwsA(isA<UsernameTakenException>()),
    );
  });

  test('treats usernames as case-insensitive', () async {
    final directory = await Directory.systemTemp.createTemp('auth_test');
    addTearDown(() => directory.delete(recursive: true));
    final repository = await openRepository(directory);

    await repository.register('Dave', 'password1');
    expect(
      () => repository.register('dave', 'password2'),
      throwsA(isA<UsernameTakenException>()),
    );
    expect((await repository.login('DAVE', 'password1'))?.username, 'Dave');
  });

  test('survives reopening the database', () async {
    final directory = await Directory.systemTemp.createTemp('auth_test');
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/users.db';

    final first = SqliteAuthRepository(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    await first.register('erin', 'password1');
    await first.close();

    final second = SqliteAuthRepository(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
    addTearDown(second.close);
    expect((await second.login('erin', 'password1'))?.username, 'erin');
  });
}
