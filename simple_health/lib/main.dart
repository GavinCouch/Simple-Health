import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'screens/login_screen.dart';

import 'app.dart';
import 'journal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
<<<<<<< HEAD

  // sqflite only ships native implementations for Android/iOS/macOS.
  // On Windows/Linux we back it with the FFI (sqlite3) implementation.
  if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const SimpleHealthApp());
}

class SimpleHealthApp extends StatelessWidget {
  const SimpleHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Health',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
=======
  runApp(DailyFuelApp(repository: SqliteJournal()));
>>>>>>> 7873196f56c04920c754e270ef236801e659cb8e
}
