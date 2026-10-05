import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../models/book.dart';
import '../models/library_entry.dart';
import '../models/profile.dart';
import '../models/user_note.dart';

class BookService {
  BookService._();
  static final instance = BookService._();
  static const bookPicturesBucket = 'Book pictures';
  static final Map<String, List<UserNote>> _demoNotes = {};
  static final Set<String> _demoRemovedLibraryEntries = {};
  static int _nextDemoNoteId = 1;
  SupabaseClient get _client => Supabase.instance.client;

  static const demoBooks = [
    Book(
      id: 1,
      title: 'The Night Circus',
      author: 'Erin Morgenstern',
      genre: 'Fantasy',
      rate: 8.6,
    ),
    Book(
      id: 2,
      title: 'Tomorrow, and Tomorrow, and Tomorrow',
      author: 'Gabrielle Zevin',
      genre: 'Contemporary Fiction',
      rate: 8.4,
    ),
    Book(
      id: 3,
      title: 'Atomic Habits',
      author: 'James Clear',
      genre: 'Self-Help & Psychology',
      rate: 8.2,
    ),
    Book(
      id: 4,
      title: 'Project Hail Mary',
      author: 'Andy Weir',
      genre: 'Science Fiction',
      rate: 9.1,
    ),
    Book(
      id: 5,
      title: 'The Book Thief',
      author: 'Markus Zusak',
      genre: 'Historical Fiction',
      rate: 8.8,
    ),
  ];

  Future<List<Book>> searchBooks({String query = '', String? genre}) async {
    if (!AppConfig.isSupabaseConfigured) {
      return demoBooks.where((book) {
        final matchesQuery =
            query.isEmpty ||
            '${book.title} ${book.author}'.toLowerCase().contains(
              query.toLowerCase(),
            );
        return matchesQuery && (genre == null || book.genre == genre);
      }).toList()..sort((a, b) => b.rate.compareTo(a.rate));
    }
    var request = _client.from('books').select();
    if (query.isNotEmpty) {
      request = request.or('title.ilike.%$query%,author.ilike.%$query%');
    }
    if (genre != null) {
      request = request.eq('genre', genre);
    }
    final rows = await request.order('rate', ascending: false);
    return (rows as List).map((row) => Book.fromMap(row)).toList();
  }

  Future<Map<String, int>> getAdminStats() async {
    final users = await _client.from('profiles').select('id');
    final books = await _client.from('books').select('id');
    return {'users': users.length, 'books': books.length};
  }

  Future<List<Profile>> searchProfiles({String query = ''}) async {
    var request = _client
        .from('profiles')
        .select('id, username, role, picture, privacy');
    if (query.trim().isNotEmpty) {
      request = request.ilike('username', '%${query.trim()}%');
    }
    final rows = await request.order('username');
    return (rows as List)
        .map((row) => Profile.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<LibraryEntry>> getUserLibraryForAdmin(String userId) async {
    final rows = await _client
        .from('user_library')
        .select('status, rate, books(*)')
        .eq('user_id', userId);
    return (rows as List).map((row) {
      final storedRate = row['rate'] as int?;
      return LibraryEntry(
        book: Book.fromMap(row['books'] as Map<String, dynamic>),
        status: readingStatusFromString(row['status'] as String),
        rate: storedRate == 0 ? null : storedRate,
      );
    }).toList();
  }

  Future<void> createBook({
    required String title,
    required String author,
    required String genre,
    PlatformFile? pictureFile,
  }) async {
    final row = await _client
        .from('books')
        .insert({
          'title': title.trim(),
          'author': author.trim(),
          'genre': genre.trim(),
          'picture': null,
          'rate': 0,
        })
        .select('id')
        .single();
    if (pictureFile == null) return;

    final bookId = (row['id'] as num).toInt();
    String? uploadedUrl;
    try {
      uploadedUrl = await _uploadBookPicture(bookId, pictureFile);
      await _client
          .from('books')
          .update({'picture': uploadedUrl})
          .eq('id', bookId);
    } catch (_) {
      await _removeManagedPicture(uploadedUrl);
      await _client.from('books').delete().eq('id', bookId);
      rethrow;
    }
  }

  Future<void> updateBook(
    int bookId, {
    required String title,
    required String author,
    required String genre,
    required String? picture,
    PlatformFile? pictureFile,
  }) async {
    final updatedPicture = pictureFile == null
        ? picture
        : await _uploadBookPicture(bookId, pictureFile);
    try {
      await _client
          .from('books')
          .update({
            'title': title.trim(),
            'author': author.trim(),
            'genre': genre.trim(),
            'picture': updatedPicture,
          })
          .eq('id', bookId);
    } catch (_) {
      if (pictureFile != null) await _removeManagedPicture(updatedPicture);
      rethrow;
    }
    if (pictureFile != null &&
        _managedPicturePath(picture) != _managedPicturePath(updatedPicture)) {
      await _removeManagedPicture(picture);
    }
  }

  Future<void> deleteBook(int bookId) async {
    final row = await _client
        .from('books')
        .select('picture')
        .eq('id', bookId)
        .maybeSingle();
    await _client.from('books').delete().eq('id', bookId);
    await _removeManagedPicture(row?['picture'] as String?);
  }

  Future<String> _uploadBookPicture(int bookId, PlatformFile image) async {
    final bytes = image.bytes;
    if (bytes == null) throw Exception('Could not read the selected image.');
    if (image.size > 5 * 1024 * 1024) {
      throw Exception('Choose an image smaller than 5 MB.');
    }

    final extension = image.extension?.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw Exception('Choose a JPG, PNG, or WebP image.'),
    };
    final path = 'books/$bookId/cover.$extension';
    final storage = _client.storage.from(bookPicturesBucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    return storage.getPublicUrl(path);
  }

  Future<void> _removeManagedPicture(String? url) async {
    final path = _managedPicturePath(url);
    if (path == null) return;
    try {
      await _client.storage.from(bookPicturesBucket).remove([path]);
    } catch (_) {
      // A stale cover should not block book updates or deletion.
    }
  }

  String? _managedPicturePath(String? url) {
    if (url == null) return null;
    final segments = Uri.tryParse(url)?.pathSegments;
    if (segments == null) return null;
    final publicIndex = segments.indexOf('public');
    if (publicIndex < 0 || publicIndex + 2 >= segments.length) return null;
    if (segments[publicIndex + 1] != bookPicturesBucket) return null;
    return segments.skip(publicIndex + 2).join('/');
  }

  Future<List<LibraryEntry>> getLibrary(String userId) async {
    if (!AppConfig.isSupabaseConfigured) {
      final demoEntries = [
        LibraryEntry(
          book: demoBooks[0],
          status: ReadingStatus.currentlyReading,
        ),
        LibraryEntry(book: demoBooks[3], status: ReadingStatus.read, rate: 9),
        LibraryEntry(book: demoBooks[2], status: ReadingStatus.wantToRead),
      ];
      return demoEntries
          .where(
            (entry) => !_demoRemovedLibraryEntries.contains(
              '$userId:${entry.book.id}',
            ),
          )
          .toList();
    }
    final rows = await _client
        .from('user_library')
        .select('status, rate, books(*)')
        .eq('user_id', userId);
    return (rows as List).map((row) {
      final storedRate = row['rate'] as int?;
      return LibraryEntry(
        book: Book.fromMap(row['books'] as Map<String, dynamic>),
        status: readingStatusFromString(row['status'] as String),
        rate: storedRate == 0 ? null : storedRate,
      );
    }).toList();
  }

  Future<void> updateStatus(
    String userId,
    int bookId,
    ReadingStatus status,
  ) async {
    if (!AppConfig.isSupabaseConfigured) return;
    final existing = await _client
        .from('user_library')
        .select('id')
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('user_library').insert({
        'user_id': userId,
        'book_id': bookId,
        'status': status.databaseValue,
        'rate': 0,
      });
    } else {
      await _client
          .from('user_library')
          .update({'status': status.databaseValue})
          .eq('user_id', userId)
          .eq('book_id', bookId);
    }
  }

  Future<void> rateBook(String userId, int bookId, int rate) async {
    if (!AppConfig.isSupabaseConfigured) return;
    await _client
        .from('user_library')
        .update({'rate': rate})
        .eq('user_id', userId)
        .eq('book_id', bookId);
  }

  Future<void> removeFromLibrary(String userId, int bookId) async {
    final key = '$userId:$bookId';
    if (!AppConfig.isSupabaseConfigured) {
      _demoRemovedLibraryEntries.add(key);
      _demoNotes.remove(key);
      return;
    }
    await _client
        .from('user_library')
        .delete()
        .eq('user_id', userId)
        .eq('book_id', bookId);
  }

  Future<List<UserNote>> getBookNotes(String userId, int bookId) async {
    if (!AppConfig.isSupabaseConfigured) {
      return List.unmodifiable(_demoNotes['$userId:$bookId'] ?? const []);
    }
    final rows = await _client
        .from('user_notes')
        .select('id, title, note, created_at')
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => UserNote.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addBookNote({
    required String userId,
    required int bookId,
    required String title,
    required String note,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      final key = '$userId:$bookId';
      _demoNotes
          .putIfAbsent(key, () => [])
          .insert(
            0,
            UserNote(
              id: _nextDemoNoteId++,
              title: title,
              note: note,
              createdAt: DateTime.now(),
            ),
          );
      return;
    }
    await _client.from('user_notes').insert({
      'user_id': userId,
      'book_id': bookId,
      'title': title,
      'note': note,
    });
  }

  Future<void> updateBookNote({
    required String userId,
    required int bookId,
    required int noteId,
    required String title,
    required String note,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      final notes = _demoNotes['$userId:$bookId'];
      final index = notes?.indexWhere((item) => item.id == noteId) ?? -1;
      if (notes == null || index < 0) return;
      final existing = notes[index];
      notes[index] = UserNote(
        id: existing.id,
        title: title,
        note: note,
        createdAt: existing.createdAt,
      );
      return;
    }
    await _client
        .from('user_notes')
        .update({'title': title, 'note': note})
        .eq('id', noteId)
        .eq('user_id', userId)
        .eq('book_id', bookId);
  }

  Future<void> deleteBookNote({
    required String userId,
    required int bookId,
    required int noteId,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      _demoNotes['$userId:$bookId']?.removeWhere((item) => item.id == noteId);
      return;
    }
    await _client
        .from('user_notes')
        .delete()
        .eq('id', noteId)
        .eq('user_id', userId)
        .eq('book_id', bookId);
  }
}
