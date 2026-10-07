import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
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
  static final Map<String, ReadingStatus> _demoLibraryStatuses = {};
  static final Map<int, int> _demoLibraryIds = {
    demoBooks[0].id!: 1,
    demoBooks[2].id!: 3,
    demoBooks[3].id!: 2,
  };
  static int _nextDemoNoteId = 1;
  DateTime? _googleBooksRetryAfter;
  SupabaseClient get _client => Supabase.instance.client;

  static const demoBooks = [
    Book(
      id: 1,
      isbn: '9780000000001',
      title: 'The Night Circus',
      author: 'Erin Morgenstern',
      genre: 'Fantasy',
      rate: 8.6,
    ),
    Book(
      id: 2,
      isbn: '9780000000002',
      title: 'Tomorrow, and Tomorrow, and Tomorrow',
      author: 'Gabrielle Zevin',
      genre: 'Contemporary Fiction',
      rate: 8.4,
    ),
    Book(
      id: 3,
      isbn: '9780000000003',
      title: 'Atomic Habits',
      author: 'James Clear',
      genre: 'Self-Help & Psychology',
      rate: 8.2,
    ),
    Book(
      id: 4,
      isbn: '9780000000004',
      title: 'Project Hail Mary',
      author: 'Andy Weir',
      genre: 'Science Fiction',
      rate: 9.1,
    ),
    Book(
      id: 5,
      isbn: '9780000000005',
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

  Future<List<Book>> searchExternalBooks(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];
    final retryAfter = _googleBooksRetryAfter;
    if (retryAfter != null && retryAfter.isAfter(DateTime.now())) {
      final remaining = retryAfter.difference(DateTime.now()).inSeconds + 1;
      throw Exception('Google Books asked us to wait $remaining seconds.');
    }

    final queryParameters = <String, String>{
      'q': normalizedQuery,
      'maxResults': '20',
    };
    if (AppConfig.googleBooksApiKey.isNotEmpty) {
      queryParameters['key'] = AppConfig.googleBooksApiKey;
    }
    final uri = Uri.https(
      'www.googleapis.com',
      '/books/v1/volumes',
      queryParameters,
    );

    late final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw Exception('Google Books search timed out. Try again.');
    } on http.ClientException {
      throw Exception('Could not connect to Google Books. Check your network.');
    }

    if (response.statusCode == 429) {
      final retrySeconds = int.tryParse(response.headers['retry-after'] ?? '');
      _googleBooksRetryAfter = DateTime.now().add(
        Duration(seconds: retrySeconds ?? 60),
      );
      throw Exception(
        'Google Books rate limit reached. Try again after the wait, or configure a Google Books API key.',
      );
    }
    if (response.statusCode == 403) {
      throw Exception(
        'Google Books denied the request. Check API quota and API key restrictions.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Google Books search failed (${response.statusCode}).');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['items'] is! List) {
      return const [];
    }

    return (decoded['items'] as List)
        .whereType<Map<String, dynamic>>()
        .map(_bookFromGoogleBooks)
        .toList();
  }

  Book _bookFromGoogleBooks(Map<String, dynamic> item) {
    final volumeInfo = item['volumeInfo'];
    final info = volumeInfo is Map<String, dynamic>
        ? volumeInfo
        : const <String, dynamic>{};
    final authors = info['authors'];
    final categories = info['categories'];
    final imageLinks = info['imageLinks'];
    final identifiers = info['industryIdentifiers'];

    String? isbn;
    if (identifiers is List) {
      final isbnEntries = identifiers.whereType<Map<String, dynamic>>();
      for (final identifier in isbnEntries) {
        if (identifier['type'] == 'ISBN_13' &&
            identifier['identifier'] is String) {
          isbn = (identifier['identifier'] as String).trim().toUpperCase();
          break;
        }
      }
      if (isbn == null) {
        for (final identifier in isbnEntries) {
          if (identifier['type'] == 'ISBN_10' &&
              identifier['identifier'] is String) {
            isbn = (identifier['identifier'] as String).trim().toUpperCase();
            break;
          }
        }
      }
    }

    final links = imageLinks is Map<String, dynamic>
        ? imageLinks
        : const <String, dynamic>{};
    final rawPicture = links['thumbnail'] ?? links['smallThumbnail'];
    final picture = rawPicture is String ? _httpsUrl(rawPicture) : null;

    return Book(
      googleBooksId: item['id']?.toString(),
      isbn: isbn,
      title:
          info['title'] is String && (info['title'] as String).trim().isNotEmpty
          ? (info['title'] as String).trim()
          : 'Untitled',
      author: authors is List && authors.whereType<String>().isNotEmpty
          ? authors.whereType<String>().join(', ')
          : 'Unknown Author',
      genre: categories is List && categories.whereType<String>().isNotEmpty
          ? categories.whereType<String>().first
          : 'General',
      rate: 0,
      picture: picture,
    );
  }

  String _httpsUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    return uri.scheme == 'http'
        ? uri.replace(scheme: 'https').toString()
        : value;
  }

  Future<Book> getOrCreateBookFromExternal(Book externalBook) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw StateError(
        'Connect to Supabase before saving Google Books results.',
      );
    }

    if (!externalBook.isExternal) {
      return externalBook;
    }

    final existing = await _findExistingExternalBook(externalBook);
    if (existing != null) return existing;

    try {
      final row = await _client
          .from('books')
          .insert({
            'google_books_id': externalBook.googleBooksId,
            'isbn': externalBook.isbn,
            'title': externalBook.title,
            'author': externalBook.author,
            'genre': externalBook.genre,
            'picture': externalBook.picture,
            'rate': 0.0,
          })
          .select()
          .single();
      return Book.fromMap(row);
    } on PostgrestException catch (exception) {
      if (exception.code == '23505') {
        final insertedElsewhere = await _findExistingExternalBook(externalBook);
        if (insertedElsewhere != null) return insertedElsewhere;
      }
      rethrow;
    }
  }

  Future<Book?> _findExistingExternalBook(Book externalBook) async {
    final googleBooksId = externalBook.googleBooksId?.trim();
    if (googleBooksId != null && googleBooksId.isNotEmpty) {
      final row = await _client
          .from('books')
          .select()
          .eq('google_books_id', googleBooksId)
          .maybeSingle();
      if (row != null) return Book.fromMap(row);
    }

    final isbn = externalBook.isbn?.trim();
    if (isbn != null && isbn.isNotEmpty) {
      final row = await _client
          .from('books')
          .select()
          .ilike('isbn', isbn)
          .maybeSingle();
      if (row != null) return Book.fromMap(row);
    }
    return null;
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
        .select('id, status, rate, books(*)')
        .eq('user_id', userId);
    return (rows as List).map((row) {
      final storedRate = row['rate'] as int?;
      return LibraryEntry(
        userLibraryId: (row['id'] as num).toInt(),
        book: Book.fromMap(row['books'] as Map<String, dynamic>),
        status: readingStatusFromString(row['status'] as String),
        rate: storedRate == 0 ? null : storedRate,
      );
    }).toList();
  }

  Future<void> createBook({
    required String isbn,
    required String title,
    required String author,
    required String genre,
    PlatformFile? pictureFile,
  }) async {
    final row = await _client
        .from('books')
        .insert({
          'isbn': isbn.trim().isEmpty ? null : isbn.trim(),
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
    required String isbn,
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
            'isbn': isbn.trim().isEmpty ? null : isbn.trim(),
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
          userLibraryId: _demoLibraryIds[demoBooks[0].id]!,
          book: demoBooks[0],
          status: ReadingStatus.currentlyReading,
        ),
        LibraryEntry(
          userLibraryId: _demoLibraryIds[demoBooks[3].id]!,
          book: demoBooks[3],
          status: ReadingStatus.read,
          rate: 9,
        ),
        LibraryEntry(
          userLibraryId: _demoLibraryIds[demoBooks[2].id]!,
          book: demoBooks[2],
          status: ReadingStatus.wantToRead,
        ),
      ];
      return demoEntries
          .where(
            (entry) => !_demoRemovedLibraryEntries.contains(
              '$userId:${entry.book.id}',
            ),
          )
          .map(
            (entry) => LibraryEntry(
              userLibraryId: entry.userLibraryId,
              book: entry.book,
              status:
                  _demoLibraryStatuses['$userId:${entry.book.id}'] ??
                  entry.status,
              rate: entry.rate,
            ),
          )
          .toList();
    }
    final rows = await _client
        .from('user_library')
        .select('id, status, rate, books(*)')
        .eq('user_id', userId);
    return (rows as List).map((row) {
      final storedRate = row['rate'] as int?;
      return LibraryEntry(
        userLibraryId: (row['id'] as num).toInt(),
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
    if (!AppConfig.isSupabaseConfigured) {
      _demoLibraryStatuses['$userId:$bookId'] = status;
      return;
    }
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
      final libraryId = _demoLibraryIds[bookId];
      if (libraryId != null) _demoNotes.remove('$libraryId');
      return;
    }
    await _client
        .from('user_library')
        .delete()
        .eq('user_id', userId)
        .eq('book_id', bookId);
  }

  Future<List<UserNote>> getBookNotes(int userLibraryId) async {
    if (!AppConfig.isSupabaseConfigured) {
      return List.unmodifiable(_demoNotes['$userLibraryId'] ?? const []);
    }
    final rows = await _client
        .from('user_notes')
        .select('id, title, note, created_at')
        .eq('user_library_id', userLibraryId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => UserNote.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addBookNote({
    required int userLibraryId,
    required String title,
    required String note,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      final key = '$userLibraryId';
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
      'user_library_id': userLibraryId,
      'title': title,
      'note': note,
    });
  }

  Future<void> updateBookNote({
    required int userLibraryId,
    required int noteId,
    required String title,
    required String note,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      final notes = _demoNotes['$userLibraryId'];
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
        .eq('user_library_id', userLibraryId);
  }

  Future<void> deleteBookNote({
    required int userLibraryId,
    required int noteId,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      _demoNotes['$userLibraryId']?.removeWhere((item) => item.id == noteId);
      return;
    }
    await _client
        .from('user_notes')
        .delete()
        .eq('id', noteId)
        .eq('user_library_id', userLibraryId);
  }
}
