import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/book.dart';
import '../../../models/user_note.dart';
import '../../../services/book_service.dart';

class BookNotesPage extends StatefulWidget {
  const BookNotesPage({
    super.key,
    required this.userLibraryId,
    required this.book,
  });

  final int userLibraryId;
  final Book book;

  @override
  State<BookNotesPage> createState() => _BookNotesPageState();
}

class _BookNotesPageState extends State<BookNotesPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  List<UserNote> _notes = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes = await BookService.instance.getBookNotes(
        widget.userLibraryId,
      );
      if (mounted) setState(() => _notes = notes);
    } catch (exception) {
      if (mounted) setState(() => _error = 'Could not load notes: $exception');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await BookService.instance.addBookNote(
        userLibraryId: widget.userLibraryId,
        title: _titleController.text.trim(),
        note: _noteController.text.trim(),
      );
      _titleController.clear();
      _noteController.clear();
      await _loadNotes();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save note: $exception')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editNote(UserNote note) async {
    final draft = await showDialog<({String title, String note})>(
      context: context,
      builder: (_) => _NoteEditorDialog(note: note),
    );
    if (draft == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await BookService.instance.updateBookNote(
        userLibraryId: widget.userLibraryId,
        noteId: note.id,
        title: draft.title,
        note: draft.note,
      );
      await _loadNotes();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update note: $exception')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteNote(UserNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this note?'),
        content: Text('"${note.title}" will be permanently removed.'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await BookService.instance.deleteBookNote(
        userLibraryId: widget.userLibraryId,
        noteId: note.id,
      );
      await _loadNotes();
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete note: $exception')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Book notes')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            widget.book.title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.book.author,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          const Text(
            'Add a note',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Add a title for your note.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 7,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Your note'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Write something before saving.'
                      : null,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveNote,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: const Text('Save note'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Text(
                'Your notes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '${_notes.length}',
                style: const TextStyle(
                  color: AppTheme.forest,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            TextButton.icon(
              onPressed: _loadNotes,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_error!),
            )
          else if (_notes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Your notes for this book will appear here.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          else
            ..._notes.map(_noteTile),
        ],
      ),
    ),
  );

  Widget _noteTile(UserNote note) {
    final date = note.createdAt.toLocal();
    final dateLabel =
        '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Added $dateLabel',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit note',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _editNote(note),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete note',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : () => _deleteNote(note),
                color: AppTheme.coral,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 10),
            child: Divider(height: 1),
          ),
          SelectableText(note.note, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _NoteEditorDialog extends StatefulWidget {
  const _NoteEditorDialog({required this.note});

  final UserNote note;

  @override
  State<_NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<_NoteEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _noteController = TextEditingController(text: widget.note.note);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (
      title: _titleController.text.trim(),
      note: _noteController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit note'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Add a title for your note.'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteController,
              minLines: 3,
              maxLines: 7,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Your note'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Write something before saving.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save changes')),
    ],
  );
}
