import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/food_entry.dart';
import '../models/user.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late User _user;
  DateTime _selectedDate = DateTime.now();

  List<FoodEntry> _entries = [];
  int _totalCalories = 0;
  bool _isLoading = true;

  final _dateFormat = DateFormat('EEEE, MMM d');
  final _dbDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadEntries();
  }

  String get _dateKey => _dbDateFormat.format(_selectedDate);

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    final entries = await DatabaseHelper.instance.getEntriesForDate(
      _user.id!,
      _dateKey,
    );
    final total = await DatabaseHelper.instance.getTotalCaloriesForDate(
      _user.id!,
      _dateKey,
    );
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _totalCalories = total;
      _isLoading = false;
    });
  }

  void _changeDate(int dayOffset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: dayOffset));
    });
    _loadEntries();
  }

  Future<void> _addEntry() async {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Food Entry'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Food name'),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a food name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: 'Calories'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final calories = int.tryParse(value ?? '');
                  if (calories == null || calories <= 0) {
                    return 'Enter a valid calorie amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final entry = FoodEntry(
      userId: _user.id!,
      name: nameController.text.trim(),
      calories: int.parse(caloriesController.text),
      date: _dateKey,
      createdAt: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper.instance.addFoodEntry(entry);
    _loadEntries();
  }

  Future<void> _deleteEntry(FoodEntry entry) async {
    await DatabaseHelper.instance.deleteFoodEntry(entry.id!);
    _loadEntries();
  }

  Future<void> _editGoal() async {
    final controller = TextEditingController(text: _user.dailyGoal.toString());
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Calorie Goal'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Calories per day'),
            validator: (value) {
              final goal = int.tryParse(value ?? '');
              if (goal == null || goal <= 0) {
                return 'Enter a valid goal';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final newGoal = int.parse(controller.text);
    await DatabaseHelper.instance.updateDailyGoal(_user.id!, newGoal);
    setState(() {
      _user = User(
        id: _user.id,
        username: _user.username,
        passwordHash: _user.passwordHash,
        dailyGoal: newGoal,
      );
    });
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _user.dailyGoal - _totalCalories;
    final progress = _user.dailyGoal == 0
        ? 0.0
        : (_totalCalories / _user.dailyGoal).clamp(0.0, 1.0);
    final isToday = _dbDateFormat.format(DateTime.now()) == _dateKey;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${_user.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Set daily goal',
            onPressed: _editGoal,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEntries,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _changeDate(-1),
                      ),
                      Text(
                        isToday ? 'Today' : _dateFormat.format(_selectedDate),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: isToday ? null : () => _changeDate(1),
                      ),
                    ],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StatColumn(
                                label: 'Consumed',
                                value: '$_totalCalories',
                              ),
                              _StatColumn(
                                label: 'Goal',
                                value: '${_user.dailyGoal}',
                              ),
                              _StatColumn(
                                label: remaining >= 0 ? 'Remaining' : 'Over',
                                value: '${remaining.abs()}',
                                color: remaining >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              color: progress >= 1
                                  ? Colors.red
                                  : Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Entries',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No food logged for this day yet.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ..._entries.map(
                      (entry) => Dismissible(
                        key: ValueKey(entry.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        onDismissed: (_) => _deleteEntry(entry),
                        child: Card(
                          child: ListTile(
                            title: Text(entry.name),
                            trailing: Text(
                              '${entry.calories} cal',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add Food'),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
