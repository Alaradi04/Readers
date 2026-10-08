import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../models/profile.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();
  static const profilePicturesBucket = 'profile pictures';
  bool get isDemoMode => !AppConfig.isSupabaseConfigured;
  SupabaseClient get _client => Supabase.instance.client;

  Future<Profile> signIn(String identifier, String password) async {
    if (isDemoMode) {
      final isEmail = identifier.contains('@');
      return Profile(
        id: 'demo',
        username: isEmail ? 'Alex Reader' : identifier,
        email: isEmail ? identifier : '',
      );
    }
    if (identifier.contains('@')) {
      final response = await _client.auth.signInWithPassword(
        email: identifier,
        password: password,
      );
      return _getProfile(response.user!);
    }

    final response = await _client.functions.invoke(
      'sign-in-with-username',
      body: {'username': identifier, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    final error = data['error'] as String?;
    if (error != null) throw Exception(error);
    final refreshToken = data['refresh_token'] as String?;
    if (refreshToken == null) {
      throw Exception('Username sign-in returned no session.');
    }
    final authResponse = await _client.auth.setSession(refreshToken);
    return _getProfile(authResponse.user!);
  }

  Future<Profile> signUp(String username, String email, String password) async {
    if (isDemoMode) {
      return Profile(id: 'demo', username: username, email: email);
    }
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    final user = response.user!;
    if (response.session == null) {
      throw Exception(
        'Account created. Check your email, confirm your account, then sign in.',
      );
    }
    return _getProfile(user);
  }

  Future<void> signInWithGoogle() async {
    if (isDemoMode) {
      throw Exception('Google sign-in requires a Supabase connection.');
    }
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : 'readers://login-callback/',
    );
    if (!launched) {
      throw Exception('Could not start Google sign-in.');
    }
  }

  Future<Profile?> getCurrentProfile() async {
    if (isDemoMode) return null;
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _getProfile(user);
  }

  Future<void> updateProfile(String username) async {
    if (isDemoMode) return;
    final user = _client.auth.currentUser!;
    await _client
        .from('profiles')
        .update({'username': username})
        .eq('id', user.id);
  }

  Future<void> updateProfilePrivacy(bool isPublic) async {
    if (isDemoMode) return;
    final user = _client.auth.currentUser!;
    await _client
        .from('profiles')
        .update({'privacy': isPublic ? 'public' : 'private'})
        .eq('id', user.id);
  }

  Future<String> uploadProfilePicture(PlatformFile image) async {
    if (isDemoMode) {
      throw Exception('Profile pictures require a Supabase connection.');
    }
    final bytes = image.bytes;
    if (bytes == null) throw Exception('Could not read the selected image.');
    if (image.size > 5 * 1024 * 1024) {
      throw Exception('Choose an image smaller than 5 MB.');
    }

    final extension = image.extension?.toLowerCase();
    final contentType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw Exception('Choose a JPG, PNG, or WebP image.'),
    };
    final user = _client.auth.currentUser!;
    final path = '${user.id}/avatar.$extension';
    final storage = _client.storage.from(profilePicturesBucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    final pictureUrl = storage.getPublicUrl(path);
    await _client
        .from('profiles')
        .update({'picture': pictureUrl})
        .eq('id', user.id);
    return pictureUrl;
  }

  Future<void> updatePassword(String password) async {
    if (!isDemoMode) {
      await _client.auth.updateUser(UserAttributes(password: password));
    }
  }

  Future<void> signOut() async {
    if (!isDemoMode) await _client.auth.signOut();
  }

  Future<Profile> _getProfile(User user) async {
    final data = await _client
        .from('profiles')
        .select('id, username, role, picture, privacy')
        .eq('id', user.id)
        .maybeSingle();
    return data == null
        ? Profile(
            id: user.id,
            username: user.userMetadata?['username'] as String? ?? 'Reader',
            email: user.email ?? '',
          )
        : Profile.fromMap({...data, 'email': user.email ?? ''});
  }
}
