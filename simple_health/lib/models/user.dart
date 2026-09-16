class User {
  final int? id;
  final String username;
  final String passwordHash;
  final int dailyGoal;

  const User({
    this.id,
    required this.username,
    required this.passwordHash,
    this.dailyGoal = 2000,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'daily_goal': dailyGoal,
    };
  }

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      dailyGoal: map['daily_goal'] as int? ?? 2000,
    );
  }
}
