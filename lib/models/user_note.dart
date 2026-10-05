class UserNote {
  const UserNote({
    required this.id,
    required this.title,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String note;
  final DateTime createdAt;

  factory UserNote.fromMap(Map<String, dynamic> map) => UserNote(
    id: (map['id'] as num).toInt(),
    title: map['title'] as String,
    note: map['note'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}