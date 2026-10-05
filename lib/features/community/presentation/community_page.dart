import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/profile.dart';
import '../../../services/community_service.dart';
import 'reader_profile_page.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => CommunityPageState();
}

class CommunityPageState extends State<CommunityPage> {
  final search = TextEditingController();
  List<Profile> profiles = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadProfiles();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> reload() => loadProfiles();

  Future<void> loadProfiles() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await CommunityService.instance.searchProfiles(
        search.text,
      );
      if (mounted) {
        setState(() {
          profiles = result;
          loading = false;
        });
      }
    } catch (exception) {
      if (mounted) {
        setState(() {
          error = 'Could not search profiles: $exception';
          loading = false;
        });
      }
    }
  }

  void openProfile(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderProfilePage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        children: [
          const Text(
            'Readers',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Find readers. Private libraries stay locked.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: search,
            onChanged: (_) => loadProfiles(),
            decoration: InputDecoration(
              hintText: 'Search by username',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        search.clear();
                        loadProfiles();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 14),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else if (profiles.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No profiles found.')),
            )
          else
            ...profiles.map(
              (profile) => _ReaderCard(
                profile: profile,
                onTap: () => openProfile(profile),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ReaderCard extends StatelessWidget {
  const _ReaderCard({required this.profile, required this.onTap});

  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: AppTheme.mint,
              backgroundImage: profile.picture == null
                  ? null
                  : NetworkImage(profile.picture!),
              child: profile.picture == null
                  ? Text(
                      profile.username.isEmpty
                          ? '?'
                          : profile.username.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.forest,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
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
                    profile.isPublic ? 'Public library' : 'Private library',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              profile.isPublic
                  ? Icons.arrow_forward_rounded
                  : Icons.lock_outline_rounded,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}
