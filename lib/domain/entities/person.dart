class Person {
  final String id;
  final String name;
  final String? phone;
  final DateTime createdAt;

  const Person({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  static const String meId = 'ME';

  bool get isMe => id == meId;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Person copyWith({
    String? id,
    String? name,
    String? phone,
    DateTime? createdAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
