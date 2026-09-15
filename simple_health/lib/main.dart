import 'package:flutter/material.dart';

import 'app.dart';
import 'journal.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(DailyFuelApp(repository: SqliteJournal()));
}
