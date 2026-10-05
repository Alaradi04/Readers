import 'package:flutter/material.dart';

import '../../../core/widgets/book_cover.dart';
import '../../../models/library_entry.dart';
import '../../../models/profile.dart';

class ProfileLibrarySheet extends StatelessWidget {
  const ProfileLibrarySheet({
    super.key,
    required this.profile,
    required this.entries,
  });

  final Profile profile;
  final List<LibraryEntry> entries;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: profile.picture == null
                    ? null
                    : NetworkImage(profile.picture!),
                child: profile.picture == null
                    ? Text(
                        profile.username.isEmpty
                            ? '?'
                            : profile.username.substring(0, 1).toUpperCase(),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "${profile.username}'s library",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${entries.length} books',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Expanded(child: Center(child: Text('This library is empty.')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (context, index) => const Divider(height: 18),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final details = [
                    entry.book.author,
                    entry.status.label,
                    if (entry.rate != null) '${entry.rate}/10',
                  ].join(' · ');
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: BookCover(
                      picture: entry.book.picture,
                      width: 42,
                      height: 58,
                    ),
                    title: Text(
                      entry.book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}
