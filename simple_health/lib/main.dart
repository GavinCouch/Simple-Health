import 'package:flutter/material.dart';

import 'auth.dart';
import 'journal.dart';
import 'login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    SimpleHealthApp(
      authRepository: SqliteAuthRepository(),
      journalRepositoryFor: (user) => SqliteJournal(userId: user.id),
    ),
  );
}
