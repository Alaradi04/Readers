import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/profile.dart';
import '../../../services/auth_service.dart';
import '../../auth/presentation/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.profile});
  final Profile profile;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController username;
  final password = TextEditingController();
  String? picture;
  bool uploadingPicture = false;
  late bool isPublic;
  bool updatingPrivacy = false;

  @override
  void initState() {
    super.initState();
    username = TextEditingController(text: widget.profile.username);
    picture = widget.profile.picture;
    isPublic = widget.profile.isPublic;
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> choosePicture() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted || result == null) return;
    setState(() => uploadingPicture = true);
    try {
      final pictureUrl = await AuthService.instance.uploadProfilePicture(
        result.files.single,
      );
      if (mounted) {
        setState(() => picture = pictureUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload profile picture: $exception'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingPicture = false);
    }
  }

  Future<void> save() async {
    if (username.text.trim().isEmpty) return;
    await AuthService.instance.updateProfile(username.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> updatePrivacy(bool value) async {
    setState(() => updatingPrivacy = true);
    try {
      await AuthService.instance.updateProfilePrivacy(value);
      if (mounted) setState(() => isPublic = value);
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update privacy: $exception')),
        );
      }
    } finally {
      if (mounted) setState(() => updatingPrivacy = false);
    }
  }

  Future<void> changePassword() async {
    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }
    await AuthService.instance.updatePassword(password.text);
    password.clear();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password updated')));
    }
  }

  Future<void> logout() async {
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
        children: [
          const Text(
            'Profile',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.mint,
                  child: ClipOval(
                    child: picture == null || picture!.isEmpty
                        ? SizedBox(
                            width: 96,
                            height: 96,
                            child: Center(
                              child: Text(
                                widget.profile.username
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  color: AppTheme.forest,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : Image.network(
                            picture!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Text(
                                    widget.profile.username
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      color: AppTheme.forest,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                          ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    tooltip: 'Change profile picture',
                    onPressed: uploadingPicture ? null : choosePicture,
                    icon: uploadingPicture
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              widget.profile.email,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 34),
          const Text(
            'Your details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: username,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: save,
              child: const Text('Save username'),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Privacy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: isPublic,
            onChanged: updatingPrivacy ? null : updatePrivacy,
            title: const Text('Public profile'),
            subtitle: Text(
              isPublic
                  ? 'Other readers can find your profile and view your library.'
                  : 'Only you and admins can see your profile and library.',
            ),
            secondary: Icon(
              isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Security',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: changePassword,
              child: const Text('Change password'),
            ),
          ),
          const SizedBox(height: 34),
          TextButton.icon(
            onPressed: logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
}
