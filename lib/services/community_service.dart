import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../models/book.dart';
import '../models/library_entry.dart';
import '../models/profile.dart';

class CommunityService {
  CommunityService._();

  static final instance = CommunityService._();
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Profile>> searchProfiles(String query) async {
    if (!AppConfig.isSupabaseConfigured) return const [];
    final currentUserId = _client.auth.currentUser?.id;
    var request = _client
        .from('profiles')
        .select('id, username, picture, role, privacy');
    final searchTerm = query.trim();
    if (searchTerm.isNotEmpty) {
      request = request.ilike('username', '%$searchTerm%');
    }
    final rows = await request.order('username');
    return (rows as List)
        .map((row) => Profile.fromMap(row as Map<String, dynamic>))
        .where((profile) => profile.id != currentUserId && !profile.isAdmin)
        .toList();
  }

  Future<List<LibraryEntry>> getProfileLibrary(String profileId) async {
    if (!AppConfig.isSupabaseConfigured) return const [];
    final rows = await _client
        .from('user_library')
      .select('id, status, rate, books(*)')
        .eq('user_id', profileId);
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
}
