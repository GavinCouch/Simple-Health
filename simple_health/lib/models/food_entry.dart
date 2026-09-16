class FoodEntry {
  final int? id;
  final int userId;
  final String name;
  final int calories;
  final String date; // yyyy-MM-dd
  final String createdAt; // ISO8601 timestamp

  const FoodEntry({
    this.id,
    required this.userId,
    required this.name,
    required this.calories,
    required this.date,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'calories': calories,
      'date': date,
      'created_at': createdAt,
    };
  }

  factory FoodEntry.fromMap(Map<String, Object?> map) {
    return FoodEntry(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      name: map['name'] as String,
      calories: map['calories'] as int,
      date: map['date'] as String,
      createdAt: map['created_at'] as String,
    );
  }
}
