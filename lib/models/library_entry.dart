import 'book.dart';

enum ReadingStatus { wantToRead, currentlyReading, read }

extension ReadingStatusLabel on ReadingStatus {
  String get label => switch (this) {
        ReadingStatus.wantToRead => 'Want to read',
        ReadingStatus.currentlyReading => 'Currently reading',
        ReadingStatus.read => 'Read',
      };

  String get databaseValue => switch (this) {
        ReadingStatus.wantToRead => 'want_to_read',
        ReadingStatus.currentlyReading => 'currently_reading',
        ReadingStatus.read => 'read',
      };
}

ReadingStatus readingStatusFromString(String value) => switch (value) {
      'read' => ReadingStatus.read,
      'currently_reading' => ReadingStatus.currentlyReading,
      _ => ReadingStatus.wantToRead,
    };

class LibraryEntry {
  const LibraryEntry({
    required this.userLibraryId,
    required this.book,
    required this.status,
    this.rate,
  });

  final int userLibraryId;
  final Book book;
  final ReadingStatus status;
  final int? rate;
}