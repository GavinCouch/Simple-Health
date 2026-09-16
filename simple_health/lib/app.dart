import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'journal.dart';

const pine = Color(0xFF153E34);
const lime = Color(0xFFD6E8AC);
const muted = Color(0xFF6B8075);

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF5F7F6),
  colorScheme: ColorScheme.fromSeed(
    seedColor: pine,
    primary: pine,
    secondary: const Color(0xFF536E31),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF5F7F6),
    foregroundColor: pine,
    surfaceTintColor: Colors.transparent,
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
    fillColor: Colors.white,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
);

class DailyFuelApp extends StatelessWidget {
  const DailyFuelApp({super.key, required this.repository});
  final JournalRepository repository;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Simple Health',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: JournalPage(repository: repository),
  );
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key, required this.repository, this.onLogout});
  final JournalRepository repository;
  final VoidCallback? onLogout;
  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> with WidgetsBindingObserver {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  JournalSnapshot? _snapshot;
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  int _request = 0;
  DateTime _lastToday = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final today = DateUtils.dateOnly(DateTime.now());
      if (_day == _lastToday && today != _lastToday) _day = today;
      _lastToday = today;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final result = await widget.repository.load(dateKey(_day));
      if (!mounted || request != _request) return;
      setState(() {
        _snapshot = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit({FoodEntry? entry, Meal meal = Meal.breakfast}) async {
    final day = dateKey(_day);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFF5F7F6),
      builder: (context) => FoodEditor(
        repository: widget.repository,
        day: day,
        entry: entry,
        initialMeal: meal,
      ),
    );
    if (saved == true && mounted) {
      await _load();
      _message(entry == null ? 'Food added to journal' : 'Entry updated');
    }
  }

  Future<void> _goal() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => GoalDialog(
        repository: widget.repository,
        initialGoal: _snapshot?.goal,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(FoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this food?'),
        content: Text(entry.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteEntry(entry.id!);
      if (mounted) await _load();
    } catch (_) {
      _message('Could not remove the entry. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeDay(DateTime date) {
    setState(() {
      _day = DateUtils.dateOnly(date);
      _snapshot = null;
    });
    _load();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
    );
    if (picked != null && mounted) _changeDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final disabled = _busy || _loading || _failed;
    final today = DateUtils.isSameDay(_day, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Edit daily goal',
            onPressed: disabled ? null : _goal,
            icon: const Icon(Icons.tune_rounded),
          ),
          if (widget.onLogout != null)
            IconButton(
              tooltip: 'Log out',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: disabled ? null : () => _edit(),
        backgroundColor: disabled ? Colors.grey.shade300 : lime,
        foregroundColor: pine,
        icon: const Icon(Icons.add),
        label: const Text('Log food'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous day',
                          onPressed: _busy || !_day.isAfter(DateTime(1900))
                              ? null
                              : () => _changeDay(
                                  DateTime(_day.year, _day.month, _day.day - 1),
                                ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: _busy ? null : _pickDate,
                            child: Text(
                              '${today ? 'Today · ' : ''}${MaterialLocalizations.of(context).formatMediumDate(_day)}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next day',
                          onPressed:
                              _busy || !_day.isBefore(DateTime(2200, 12, 31))
                              ? null
                              : () => _changeDay(
                                  DateTime(_day.year, _day.month, _day.day + 1),
                                ),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                  if (!today)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _changeDay(DateTime.now()),
                        child: const Text('Back to today'),
                      ),
                    ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_failed)
                    _LoadError(onRetry: _load)
                  else if (snapshot != null) ...[
                    _Summary(snapshot: snapshot, onGoal: _goal),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Food journal',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: pine,
                            ),
                          ),
                        ),
                        Text(
                          '${snapshot.entries.length} ${snapshot.entries.length == 1 ? 'entry' : 'entries'}',
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final meal in Meal.values)
                      _MealCard(
                        meal: meal,
                        entries: snapshot.entries
                            .where((e) => e.meal == meal)
                            .toList(),
                        onAdd: disabled ? null : () => _edit(meal: meal),
                        onEdit: (entry) {
                          if (!disabled) _edit(entry: entry);
                        },
                        onDelete: (entry) {
                          if (!disabled) _delete(entry);
                        },
                      ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 36),
        const SizedBox(height: 16),
        const Text('Your journal could not be loaded.'),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot, required this.onGoal});
  final JournalSnapshot snapshot;
  final VoidCallback onGoal;
  @override
  Widget build(BuildContext context) {
    final goal = snapshot.goal, total = snapshot.total;
    final remaining = (goal ?? 0) - total;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: pine,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CALORIES CONSUMED',
            style: TextStyle(
              color: Color(0xFFBED4C6),
              fontSize: 12,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$total',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -2,
                  ),
                ),
                const TextSpan(
                  text: ' kcal',
                  style: TextStyle(fontSize: 16, color: Color(0xFFBED4C6)),
                ),
              ],
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            goal == null
                ? 'Choose a daily goal to track your progress.'
                : remaining >= 0
                ? '$remaining kcal remaining'
                : '${-remaining} kcal above your goal',
            style: const TextStyle(color: Color(0xFFD0E0D7)),
          ),
          const SizedBox(height: 23),
          if (goal != null) ...[
            Semantics(
              label: 'Daily calorie goal',
              value: '${(total / goal * 100).round()} percent',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (total / goal).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: lime,
                  backgroundColor: const Color(0xFF3D6054),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 24,
              runSpacing: 8,
              children: [
                Text(
                  '${(total / goal * 100).round()}% of daily goal',
                  style: const TextStyle(
                    color: Color(0xFFD0E0D7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  '$goal kcal goal',
                  style: const TextStyle(
                    color: Color(0xFFD0E0D7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ] else
            TextButton(
              onPressed: onGoal,
              style: TextButton.styleFrom(
                foregroundColor: lime,
                padding: EdgeInsets.zero,
              ),
              child: const Text('Set daily goal'),
            ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.entries,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final Meal meal;
  final List<FoodEntry> entries;
  final VoidCallback? onAdd;
  final ValueChanged<FoodEntry> onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE0E6E2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                Icon(
                  [
                    Icons.wb_twilight,
                    Icons.light_mode_outlined,
                    Icons.dark_mode_outlined,
                    Icons.cookie_outlined,
                  ][meal.index],
                  size: 22,
                  color: muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meal.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${entries.fold<int>(0, (sum, e) => sum + e.total)} kcal',
                  style: const TextStyle(fontSize: 13, color: muted),
                ),
                IconButton(
                  tooltip: 'Add to ${meal.label}',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 22),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(50, 0, 16, 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No foods logged yet',
                  style: TextStyle(fontSize: 14, color: muted),
                ),
              ),
            ),
          for (final entry in entries)
            Column(
              children: [
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFEEF1EF),
                ),
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 18, right: 4),
                  title: Text(entry.name, style: const TextStyle(fontSize: 15)),
                  subtitle: Text(
                    '${entry.servings % 1 == 0 ? entry.servings.toInt() : entry.servings} servings · ${entry.total} kcal',
                    style: const TextStyle(fontSize: 13, color: muted),
                  ),
                  onTap: () => onEdit(entry),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Options for ${entry.name}',
                    onSelected: (value) =>
                        value == 'edit' ? onEdit(entry) : onDelete(entry),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class FoodEditor extends StatefulWidget {
  const FoodEditor({
    super.key,
    required this.repository,
    required this.day,
    this.entry,
    this.initialMeal = Meal.breakfast,
  });
  final JournalRepository repository;
  final String day;
  final FoodEntry? entry;
  final Meal initialMeal;
  @override
  State<FoodEditor> createState() => _FoodEditorState();
}

class _FoodEditorState extends State<FoodEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _calories, _servings;
  late Meal _meal;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.entry?.name ?? '');
    _calories = TextEditingController(
      text: widget.entry?.calories.toString() ?? '',
    );
    _servings = TextEditingController(
      text: widget.entry?.servings.toString() ?? '1',
    );
    _meal = widget.entry?.meal ?? widget.initialMeal;
    _calories.addListener(_update);
    _servings.addListener(_update);
  }

  void _update() => setState(() {});
  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _servings.dispose();
    super.dispose();
  }

  double? _parseServings() =>
      double.tryParse(_servings.text.replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.saveEntry(
        FoodEntry(
          id: widget.entry?.id,
          date: widget.day,
          name: _name.text.trim(),
          meal: _meal,
          calories: int.parse(_calories.text),
          servings: _parseServings()!,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save. Your entry is still here. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final servings = _parseServings() ?? 0;
    final rawTotal = (int.tryParse(_calories.text) ?? 0) * servings;
    final total = rawTotal.isFinite ? rawTotal.round() : 0;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: SafeArea(
            top: false,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.entry == null ? 'Log your food' : 'Edit food',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: pine,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('foodName'),
                    controller: _name,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'Food name',
                      hintText: 'Oatmeal with berries',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a food name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('foodCalories'),
                    controller: _calories,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Calories per serving',
                      suffixText: 'kcal',
                    ),
                    validator: (value) {
                      final n = int.tryParse(value ?? '');
                      return n == null || n < 0 || n > 10000
                          ? 'Enter 0–10,000 calories'
                          : null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    key: const Key('foodServings'),
                    controller: _servings,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Servings',
                      counterText: '',
                    ),
                    validator: (_) {
                      final n = _parseServings();
                      return n == null || !n.isFinite || n < 0.1 || n > 100
                          ? 'Enter 0.1–100 servings'
                          : null;
                    },
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<Meal>(
                    isExpanded: true,
                    initialValue: _meal,
                    decoration: const InputDecoration(labelText: 'Meal'),
                    items: [
                      for (final meal in Meal.values)
                        DropdownMenuItem(value: meal, child: Text(meal.label)),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _meal = value!),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Entry total: $total kcal',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving
                          ? 'Saving…'
                          : widget.entry == null
                          ? 'Add to journal'
                          : 'Save changes',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GoalDialog extends StatefulWidget {
  const GoalDialog({super.key, required this.repository, this.initialGoal});
  final JournalRepository repository;
  final int? initialGoal;
  @override
  State<GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<GoalDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _goal = TextEditingController(
    text: widget.initialGoal?.toString() ?? '',
  );
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.setGoal(int.parse(_goal.text));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your goal. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Your daily goal'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose the daily calorie target that works for you.'),
              const SizedBox(height: 20),
              TextFormField(
                key: const Key('goalInput'),
                controller: _goal,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: const InputDecoration(
                  labelText: 'Daily calories',
                  suffixText: 'kcal',
                ),
                validator: (value) {
                  final n = int.tryParse(value ?? '');
                  return n == null || n < 1 || n > 20000
                      ? 'Enter 1–20,000 calories'
                      : null;
                },
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save goal'),
        ),
      ],
    ),
  );
}
