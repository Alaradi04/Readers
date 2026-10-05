import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../models/library_entry.dart';
import '../../../models/profile.dart';
import '../../../services/book_service.dart';
import 'book_notes_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.profile});
  final Profile profile;
  @override
  State<LibraryPage> createState() => LibraryPageState();
}

class LibraryPageState extends State<LibraryPage> {
  List<LibraryEntry> entries = const [];
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> reload() => load();
  Future<void> load() async {
    final result = await BookService.instance.getLibrary(widget.profile.id);
    if (mounted) setState(() => entries = result);
  }

  Future<void> rate(LibraryEntry entry) async {
    final value = await showDialog<int>(
      context: context,
      builder: (_) =>
          _RatingDialog(bookTitle: entry.book.title, initialRate: entry.rate),
    );
    if (!mounted || value == null || value < 1 || value > 10) return;
    try {
      await BookService.instance.rateBook(
        widget.profile.id,
        entry.book.id,
        value,
      );
      await load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save rating: $exception')),
        );
      }
    }
  }

  Future<void> changeStatus(LibraryEntry entry, ReadingStatus status) async {
    try {
      await BookService.instance.updateStatus(
        widget.profile.id,
        entry.book.id,
        status,
      );
      await load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update status: $exception')),
        );
      }
    }
  }

  Future<void> removeFromLibrary(LibraryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove book from library?'),
        content: Text(
          '"${entry.book.title}" and your notes for it will be removed from your library. The book remains available to other readers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      await BookService.instance.removeFromLibrary(
        widget.profile.id,
        entry.book.id,
      );
      await load();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove book: $exception')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            const Text(
              'My library',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${entries.length} books in your reading life',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ...ReadingStatus.values.map((status) {
              final books = entries
                  .where((entry) => entry.status == status)
                  .toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 10),
                    child: Row(
                      children: [
                        Text(
                          status.label,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppTheme.mint,
                          child: Text(
                            '${books.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.forest,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (books.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Nothing here yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ...books.map(
                      (entry) => _LibraryBookCard(
                        entry: entry,
                        onOpenNotes:
                            status == ReadingStatus.currentlyReading ||
                                status == ReadingStatus.read
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookNotesPage(
                                    userId: widget.profile.id,
                                    book: entry.book,
                                  ),
                                ),
                              )
                            : null,
                        onStatusChanged: (newStatus) =>
                            changeStatus(entry, newStatus),
                        onRemove: () => removeFromLibrary(entry),
                        onRate: status == ReadingStatus.read
                            ? () => rate(entry)
                            : null,
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({required this.bookTitle, this.initialRate});

  final String bookTitle;
  final int? initialRate;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.initialRate?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.bookTitle}'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Your rating (1-10)'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(controller.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _LibraryBookCard extends StatelessWidget {
  const _LibraryBookCard({
    required this.entry,
    required this.onOpenNotes,
    required this.onStatusChanged,
    required this.onRemove,
    this.onRate,
  });

  final LibraryEntry entry;
  final VoidCallback? onOpenNotes;
  final ValueChanged<ReadingStatus> onStatusChanged;
  final VoidCallback onRemove;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    final otherStatuses = ReadingStatus.values
        .where((status) => status != entry.status)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onOpenNotes,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              BookCover(picture: entry.book.picture, width: 58, height: 76),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      entry.book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      entry.book.genre,
                      style: const TextStyle(
                        color: AppTheme.forest,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  if (onOpenNotes != null)
                    IconButton(
                      tooltip: 'Open book notes',
                      onPressed: onOpenNotes,
                      icon: const Icon(Icons.sticky_note_2_outlined),
                      color: AppTheme.forest,
                    ),
                  if (onRate != null)
                    IconButton(
                      tooltip: 'Rate book',
                      onPressed: onRate,
                      icon: Icon(
                        entry.rate == null
                            ? Icons.star_border_rounded
                            : Icons.star_rounded,
                        color: AppTheme.coral,
                      ),
                    ),
                  PopupMenuButton<Object>(
                    tooltip: 'Move book',
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (action) {
                      if (action is ReadingStatus) onStatusChanged(action);
                      if (action == _LibraryBookAction.remove) onRemove();
                    },
                    itemBuilder: (context) => [
                      ...otherStatuses.map(
                        (status) => PopupMenuItem<Object>(
                          value: status,
                          child: Text('Move to ${status.label.toLowerCase()}'),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<Object>(
                        value: _LibraryBookAction.remove,
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded),
                            SizedBox(width: 12),
                            Text('Remove from library'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LibraryBookAction { remove }
