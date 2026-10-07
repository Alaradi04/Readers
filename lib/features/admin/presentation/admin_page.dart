import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../models/book.dart';
import '../../../models/profile.dart';
import '../../../services/book_service.dart';
import '../../community/presentation/profile_library_sheet.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => AdminPageState();
}

class AdminPageState extends State<AdminPage> {
  final search = TextEditingController();
  final profileSearch = TextEditingController();
  List<Book> books = const [];
  List<Profile> profiles = const [];
  int? userCount;
  int? bookCount;
  bool loadingBooks = true;
  bool loadingProfiles = true;
  bool googleBooksSearch = false;
  bool externalSearchSubmitted = false;
  int _bookSearchRequest = 0;
  String? importingGoogleBooksId;
  String? error;
  String? profileError;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    search.dispose();
    profileSearch.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    await Future.wait([loadStats(), loadBooks(), loadProfiles()]);
  }

  Future<void> loadStats() async {
    try {
      final stats = await BookService.instance.getAdminStats();
      if (mounted) {
        setState(() {
          userCount = stats['users'];
          bookCount = stats['books'];
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() => error = 'Could not load dashboard: $exception');
      }
    }
  }

  Future<void> loadBooks() async {
    if (googleBooksSearch && search.text.trim().isEmpty) {
      setState(() {
        books = const [];
        loadingBooks = false;
        error = null;
        externalSearchSubmitted = false;
      });
      return;
    }
    final request = ++_bookSearchRequest;
    setState(() {
      loadingBooks = true;
      error = null;
    });
    try {
      final result = googleBooksSearch
          ? await BookService.instance.searchExternalBooks(search.text)
          : await BookService.instance.searchBooks(query: search.text);
      if (mounted && request == _bookSearchRequest) {
        setState(() {
          books = result;
          loadingBooks = false;
          externalSearchSubmitted = googleBooksSearch;
        });
      }
    } catch (exception) {
      if (mounted && request == _bookSearchRequest) {
        setState(() {
          error = 'Could not load books: $exception';
          books = const [];
          loadingBooks = false;
          externalSearchSubmitted = googleBooksSearch;
        });
      }
    }
  }

  void _onBookSearchChanged(String _) {
    if (googleBooksSearch) {
      _bookSearchRequest++;
      setState(() {
        books = const [];
        loadingBooks = false;
        error = null;
        externalSearchSubmitted = false;
      });
    } else {
      loadBooks();
    }
  }

  void _setBookSearchSource(bool useGoogleBooks) {
    _bookSearchRequest++;
    setState(() {
      googleBooksSearch = useGoogleBooks;
      books = const [];
      loadingBooks = false;
      error = null;
      externalSearchSubmitted = false;
    });
    if (!useGoogleBooks) loadBooks();
  }

  Future<void> _importExternalBook(Book book) async {
    final googleBooksId = book.googleBooksId;
    if (googleBooksId == null || importingGoogleBooksId != null) return;
    setState(() => importingGoogleBooksId = googleBooksId);
    try {
      await BookService.instance.getOrCreateBookFromExternal(book);
      final stats = await BookService.instance.getAdminStats();
      if (mounted) setState(() => bookCount = stats['books']);
      if (mounted) _showMessage('Book added to the catalog.');
    } catch (exception) {
      if (mounted) _showMessage('Could not import book: $exception');
    } finally {
      if (mounted) setState(() => importingGoogleBooksId = null);
    }
  }

  Future<void> loadProfiles() async {
    setState(() {
      loadingProfiles = true;
      profileError = null;
    });
    try {
      final result = await BookService.instance.searchProfiles(
        query: profileSearch.text,
      );
      if (mounted) {
        setState(() {
          profiles = result;
          loadingProfiles = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          profileError = 'Could not load profiles: $exception';
          loadingProfiles = false;
        });
      }
    }
  }

  Future<void> viewLibrary(Profile profile) async {
    try {
      final entries = await BookService.instance.getUserLibraryForAdmin(
        profile.id,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: ProfileLibrarySheet(profile: profile, entries: entries),
        ),
      );
    } catch (exception) {
      if (mounted) _showMessage('Could not load this library: $exception');
    }
  }

  Future<void> editBook([Book? book]) async {
    final values = await showDialog<_BookValues>(
      context: context,
      builder: (context) => _BookEditorDialog(book: book),
    );
    if (values == null) return;
    try {
      if (book == null) {
        await BookService.instance.createBook(
          isbn: values.isbn,
          title: values.title,
          author: values.author,
          genre: values.genre,
          pictureFile: values.pictureFile,
        );
      } else {
        await BookService.instance.updateBook(
          book.id!,
          isbn: values.isbn,
          title: values.title,
          author: values.author,
          genre: values.genre,
          picture: book.picture,
          pictureFile: values.pictureFile,
        );
      }
      await reload();
      if (mounted) _showMessage(book == null ? 'Book added.' : 'Book updated.');
    } catch (exception) {
      if (mounted) _showMessage('Could not save book: $exception');
    }
  }

  Future<void> removeBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text('Remove "${book.title}" from the catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await BookService.instance.deleteBook(book.id!);
      await reload();
      if (mounted) _showMessage('Book removed.');
    } catch (exception) {
      if (mounted) _showMessage('Could not remove book: $exception');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        children: [
          const Text(
            'Admin dashboard',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Users',
                  value: userCount?.toString() ?? '—',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Books',
                  value: bookCount?.toString() ?? '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Manage books',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filled(
                tooltip: 'Add book',
                onPressed: () => editBook(),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: search,
            onChanged: _onBookSearchChanged,
            onSubmitted: (_) => loadBooks(),
            decoration: InputDecoration(
              hintText: googleBooksSearch
                  ? 'Search Google Books'
                  : 'Search books or authors',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: googleBooksSearch
                  ? IconButton(
                      tooltip: 'Search Google Books',
                      onPressed: loadingBooks ? null : loadBooks,
                      icon: const Icon(Icons.search_rounded),
                    )
                  : search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        search.clear();
                        loadBooks();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Catalog')),
              ButtonSegment(value: true, label: Text('Google Books')),
            ],
            selected: {googleBooksSearch},
            onSelectionChanged: (selection) =>
                _setBookSearchSource(selection.first),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          if (loadingBooks)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(),
              ),
            )
          else if (books.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No books found.')),
            )
          else
            ...books.map(
              (book) => _AdminBookTile(
                book: book,
                onEdit: googleBooksSearch ? null : () => editBook(book),
                onRemove: googleBooksSearch ? null : () => removeBook(book),
                onImport: googleBooksSearch
                    ? () => _importExternalBook(book)
                    : null,
                importing: importingGoogleBooksId == book.googleBooksId,
              ),
            ),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Profiles',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${profiles.length}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: profileSearch,
            onChanged: (_) => loadProfiles(),
            decoration: InputDecoration(
              hintText: 'Search profiles by username',
              prefixIcon: const Icon(Icons.person_search_rounded),
              suffixIcon: profileSearch.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        profileSearch.clear();
                        loadProfiles();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          if (profileError != null) ...[
            const SizedBox(height: 12),
            Text(
              profileError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          if (loadingProfiles)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (profiles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No profiles found.')),
            )
          else
            ...profiles.map(
              (profile) => _AdminProfileCard(
                profile: profile,
                onViewLibrary: () => viewLibrary(profile),
              ),
            ),
        ],
      ),
    ),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _AdminBookTile extends StatelessWidget {
  const _AdminBookTile({
    required this.book,
    required this.onEdit,
    required this.onRemove,
    this.onImport,
    this.importing = false,
  });

  final Book book;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;
  final VoidCallback? onImport;
  final bool importing;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.mint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: BookCover(picture: book.picture, width: 76, height: 112),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  book.genre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.forest,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: AppTheme.coral,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      book.rate.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: onImport != null
                ? [
                    IconButton(
                      tooltip: 'Add to catalog',
                      onPressed: importing ? null : onImport,
                      icon: importing
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.library_add_outlined),
                    ),
                  ]
                : [
                    IconButton(
                      tooltip: 'Edit book',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove book',
                      onPressed: onRemove,
                      color: Theme.of(context).colorScheme.error,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
          ),
        ],
      ),
    ),
  );
}

class _AdminProfileCard extends StatelessWidget {
  const _AdminProfileCard({required this.profile, required this.onViewLibrary});

  final Profile profile;
  final VoidCallback onViewLibrary;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.mint,
            child: profile.picture == null || profile.picture!.isEmpty
                ? Text(
                    profile.username.isEmpty
                        ? '?'
                        : profile.username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.forest,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : ClipOval(
                    child: Image.network(
                      profile.picture!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Text(
                        profile.username.isEmpty
                            ? '?'
                            : profile.username.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.forest,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.isPublic ? 'Public profile' : 'Private profile',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'View library',
            onPressed: onViewLibrary,
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
    ),
  );
}

class _BookValues {
  const _BookValues({
    required this.isbn,
    required this.title,
    required this.author,
    required this.genre,
    this.pictureFile,
  });

  final String isbn;
  final String title;
  final String author;
  final String genre;
  final PlatformFile? pictureFile;
}

class _BookEditorDialog extends StatefulWidget {
  const _BookEditorDialog({this.book});

  final Book? book;

  @override
  State<_BookEditorDialog> createState() => _BookEditorDialogState();
}

class _BookEditorDialogState extends State<_BookEditorDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController author;
  late final TextEditingController genre;
  late final TextEditingController isbn;
  PlatformFile? pictureFile;

  @override
  void initState() {
    super.initState();
    isbn = TextEditingController(text: widget.book?.isbn ?? '');
    title = TextEditingController(text: widget.book?.title ?? '');
    author = TextEditingController(text: widget.book?.author ?? '');
    genre = TextEditingController(text: widget.book?.genre ?? '');
  }

  @override
  void dispose() {
    isbn.dispose();
    title.dispose();
    author.dispose();
    genre.dispose();
    super.dispose();
  }

  Future<void> _choosePicture() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted || result == null) return;
    final selected = result.files.single;
    if (selected.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected image.')),
      );
      return;
    }
    setState(() => pictureFile = selected);
  }

  Widget _picturePreview() {
    final bytes = pictureFile?.bytes;
    if (bytes == null) {
      return BookCover(picture: widget.book?.picture, width: 62, height: 82);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 62,
        height: 82,
        color: AppTheme.mint,
        alignment: Alignment.center,
        child: Image.memory(bytes, width: 62, height: 82, fit: BoxFit.contain),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.book == null ? 'Add book' : 'Edit book'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: isbn,
                decoration: const InputDecoration(labelText: 'ISBN (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: title,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: author,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Author'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: genre,
                validator: _required,
                decoration: const InputDecoration(labelText: 'Genre'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _picturePreview(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _choosePicture,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        pictureFile == null ? 'Choose cover' : 'Change cover',
                      ),
                    ),
                  ),
                ],
              ),
              if (pictureFile != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    pictureFile!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _BookValues(
              isbn: isbn.text.trim(),
              title: title.text,
              author: author.text,
              genre: genre.text,
              pictureFile: pictureFile,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}
