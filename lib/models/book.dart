class Book {
  const Book({
    this.id,
    required this.title,
    required this.author,
    required this.genre,
    required this.rate,
    this.isbn,
    this.googleBooksId,
    this.picture,
    this.createdAt,
  });

  final int? id;
  final String? isbn;
  final String? googleBooksId;
  final String title;
  final String author;
  final String genre;
  final double rate;
  final String? picture;
  final DateTime? createdAt;

  bool get isExternal => id == null;

  factory Book.fromMap(Map<String, dynamic> map) => Book(
    id: (map['id'] as num?)?.toInt(),
    isbn: (map['isbn'] ?? map['ISBN'])?.toString(),
    googleBooksId: map['google_books_id']?.toString(),
    title: map['title'] as String? ?? 'Untitled',
    author: map['author'] as String? ?? 'Unknown author',
    genre: map['genre'] as String? ?? 'Other',
    rate: (map['rate'] as num?)?.toDouble() ?? 0,
    picture: map['picture'] as String?,
    createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
  );
}
