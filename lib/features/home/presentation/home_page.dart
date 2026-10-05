import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../models/book.dart';
import '../../../models/library_entry.dart';
import '../../../models/profile.dart';
import '../../../services/book_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.profile});
  final Profile profile;
  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final search = TextEditingController();
  List<Book> books = const [];
  String? genre;
  bool loading = true;
  static const genres = [
    'All genres',
    'Action & Adventure',
    'Biography & Memoir',
    'Business & Economics',
    "Children's / Picture Books",
    'Contemporary Fiction',
    'Cookbooks & Food',
    'Dystopian & Post-Apocalyptic',
    'Essays & Poetry',
    'Fantasy',
    'Historical Fiction',
    'History',
    'Horror & Paranormal',
    'Literary Fiction',
    'Mystery & Thriller',
    'Philosophy',
    'Religion & Spirituality',
    'Romance',
    'Science Fiction',
    'Science & Technology',
    'Self-Help & Psychology',
    'Travel',
    'True Crime',
  ];

  @override
  void initState() {
    super.initState();
    loadBooks();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> loadBooks() async {
    setState(() => loading = true);
    final result = await BookService.instance.searchBooks(
      query: search.text,
      genre: genre,
    );
    if (mounted) {
      setState(() {
        books = result;
        loading = false;
      });
    }
  }

  void showBook(Book book) {
    final pageContext = context;
    showModalBottomSheet<void>(
      context: pageContext,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              book.author,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: AppTheme.coral),
                const SizedBox(width: 5),
                Text('${book.rate}/10  ·  ${book.genre}'),
              ],
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReadingStatus.values
                  .map(
                    (status) => OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await BookService.instance.updateStatus(
                            widget.profile.id,
                            book.id,
                            status,
                          );
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                        } catch (exception) {
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          if (pageContext.mounted) {
                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              SnackBar(
                                content: Text('Could not add book: $exception'),
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        status == ReadingStatus.read
                            ? Icons.check
                            : Icons.bookmark_add_outlined,
                      ),
                      label: Text(status.label),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      onRefresh: loadBooks,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        children: [
          Text(
            'Hello, ${widget.profile.username.split(' ').first}.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Find your next\ngreat read.',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: search,
            onChanged: (_) => loadBooks(),
            decoration: const InputDecoration(
              hintText: 'Search books or authors',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: genre ?? genres.first,
            decoration: const InputDecoration(
              labelText: 'Filter by genre',
              prefixIcon: Icon(Icons.tune_rounded),
            ),
            items: genres
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => genre = value == genres.first ? null : value);
              loadBooks();
            },
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top rated',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              Text(
                '${books.length} books',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(35),
                child: CircularProgressIndicator(),
              ),
            )
          else if (books.isEmpty)
            const Padding(
              padding: EdgeInsets.all(35),
              child: Center(child: Text('No books found.')),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1100
                    ? 3
                    : constraints.maxWidth >= 680
                    ? 2
                    : 1;
                const spacing = 14.0;
                final cardWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: books
                      .map(
                        (book) => SizedBox(
                          width: cardWidth,
                          child: _BookTile(
                            book: book,
                            onTap: () => showBook(book),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    ),
  );
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: Colors.black.withValues(alpha: 0.07)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.forest,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppTheme.coral,
                        size: 19,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        book.rate.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
