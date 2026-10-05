import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../models/library_entry.dart';
import '../../../models/profile.dart';
import '../../../services/community_service.dart';

class ReaderProfilePage extends StatefulWidget {
  const ReaderProfilePage({super.key, required this.profile});

  final Profile profile;

  @override
  State<ReaderProfilePage> createState() => _ReaderProfilePageState();
}

class _ReaderProfilePageState extends State<ReaderProfilePage> {
  List<LibraryEntry> entries = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.profile.isPublic) loadLibrary();
  }

  Future<void> loadLibrary() async {
    if (!widget.profile.isPublic) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await CommunityService.instance.getProfileLibrary(
        widget.profile.id,
      );
      if (mounted) {
        setState(() {
          entries = result;
          loading = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = 'Could not load library: $exception';
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.profile.username)),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: loadLibrary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppTheme.mint,
                    backgroundImage: widget.profile.picture == null
                        ? null
                        : NetworkImage(widget.profile.picture!),
                    child: widget.profile.picture == null
                        ? Text(
                            widget.profile.username.isEmpty
                                ? '?'
                                : widget.profile.username
                                      .substring(0, 1)
                                      .toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.forest,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.profile.username,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.profile.isPublic
                        ? 'Public profile'
                        : 'Private profile',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Library',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (!widget.profile.isPublic)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.forest,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This library is private',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Only ${widget.profile.username} can view it.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (loading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('This library is empty.')),
              )
            else
              ...entries.map((entry) => _LibraryBookTile(entry: entry)),
          ],
        ),
      ),
    ),
  );
}

class _LibraryBookTile extends StatelessWidget {
  const _LibraryBookTile({required this.entry});

  final LibraryEntry entry;

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
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          BookCover(picture: entry.book.picture, width: 54, height: 74),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.status.label,
                  style: const TextStyle(
                    color: AppTheme.forest,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (entry.rate != null) ...[
            const Icon(Icons.star_rounded, color: AppTheme.coral, size: 18),
            const SizedBox(width: 3),
            Text('${entry.rate}/10'),
          ],
        ],
      ),
    ),
  );
}
