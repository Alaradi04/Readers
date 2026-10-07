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
        entry.book.id!,
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
        entry.book.id!,
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

  Widget _buildStatusSection(ReadingStatus status, List<LibraryEntry> books) {
    return DragTarget<LibraryEntry>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) => changeStatus(details.data, status),
      builder: (context, candidates, rejected) {
        final isHovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isHovering ? AppTheme.mint.withValues(alpha: 0.3) : null,
            border: isHovering ? Border.all(color: AppTheme.forest) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
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
                                userLibraryId: entry.userLibraryId,
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
          ),
        );
      },
    );
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
        entry.book.id!,
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
            const SizedBox(height: 4),
            Text(
              'Swipe to move one status, or long-press and drag to any status.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ...ReadingStatus.values.map((status) {
              final books = entries
                  .where((entry) => entry.status == status)
                  .toList();
              return _buildStatusSection(status, books);
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

class _LibraryBookCard extends StatefulWidget {
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
  State<_LibraryBookCard> createState() => _LibraryBookCardState();
}

class _LibraryBookCardState extends State<_LibraryBookCard> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => LongPressDraggable<LibraryEntry>(
        data: widget.entry,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: constraints.maxWidth,
            child: _buildCard(context),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: _buildCard(context)),
        child: _buildCard(context),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final otherStatuses = ReadingStatus.values
        .where((status) => status != widget.entry.status)
        .toList();
    return GestureDetector(
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) {
        _dragDistance += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        final dragDistance = _dragDistance;
        _dragDistance = 0;
        final velocity = details.primaryVelocity ?? 0;
        if (dragDistance.abs() < 48 && velocity.abs() < 400) return;

        final direction = dragDistance.abs() >= 48
            ? dragDistance.sign
            : velocity.sign;
        final statusIndex = ReadingStatus.values.indexOf(widget.entry.status);
        final targetIndex = statusIndex + (direction < 0 ? 1 : -1);
        if (targetIndex >= 0 && targetIndex < ReadingStatus.values.length) {
          widget.onStatusChanged(ReadingStatus.values[targetIndex]);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: widget.onOpenNotes,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                BookCover(
                  picture: widget.entry.book.picture,
                  width: 58,
                  height: 76,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.entry.book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.entry.book.genre,
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
                    if (widget.onOpenNotes != null)
                      IconButton(
                        tooltip: 'Open book notes',
                        onPressed: widget.onOpenNotes,
                        icon: const Icon(Icons.sticky_note_2_outlined),
                        color: AppTheme.forest,
                      ),
                    if (widget.onRate != null)
                      IconButton(
                        tooltip: 'Rate book',
                        onPressed: widget.onRate,
                        icon: Icon(
                          widget.entry.rate == null
                              ? Icons.star_border_rounded
                              : Icons.star_rounded,
                          color: AppTheme.coral,
                        ),
                      ),
                    PopupMenuButton<Object>(
                      tooltip: 'Move book',
                      icon: const Icon(Icons.more_vert_rounded),
                      onSelected: (action) {
                        if (action is ReadingStatus) {
                          widget.onStatusChanged(action);
                        }
                        if (action == _LibraryBookAction.remove) {
                          widget.onRemove();
                        }
                      },
                      itemBuilder: (context) => [
                        ...otherStatuses.map(
                          (status) => PopupMenuItem<Object>(
                            value: status,
                            child: Text(
                              'Move to ${status.label.toLowerCase()}',
                            ),
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
      ),
    );
  }
}

enum _LibraryBookAction { remove }
