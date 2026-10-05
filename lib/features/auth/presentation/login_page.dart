import 'package:flutter/material.dart';

import '../../../models/profile.dart';
import '../../../services/auth_service.dart';
import '../../home/presentation/home_shell.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final identifier = TextEditingController();
  final password = TextEditingController();
  bool isRegistering = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (identifier.text.trim().isEmpty || password.text.length < 6) {
      setState(
        () => error =
            'Enter a username or email and a password with at least 6 characters.',
      );
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final Profile profile = isRegistering
          ? await AuthService.instance.signUp(
              username.text.trim().isEmpty
                  ? 'New Reader'
                  : username.text.trim(),
              identifier.text.trim(),
              password.text,
            )
          : await AuthService.instance.signIn(
              identifier.text.trim(),
              password.text,
            );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeShell(profile: profile)),
        );
      }
    } catch (exception) {
      if (mounted) setState(() => error = _friendlyError(exception));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _friendlyError(Object exception) {
    final message = exception.toString();
    if (message.contains('email_send_rate_limit') ||
        message.contains('email rate limit exceeded')) {
      return 'Supabase email limit reached. Disable email confirmation while testing, or wait before trying again.';
    }
    return message.replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D5B4A),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  isRegistering
                      ? 'Join the readers\' room.'
                      : 'A better shelf\nfor every story.',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isRegistering
                      ? 'Keep every book, thought, and next read in one place.'
                      : 'Find your next favorite book and keep your reading life close.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                if (isRegistering) ...[
                  TextField(
                    controller: username,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: identifier,
                  keyboardType: isRegistering
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: isRegistering
                        ? 'Email address'
                        : 'Username or email',
                    prefixIcon: Icon(
                      isRegistering ? Icons.mail_outline : Icons.person_outline,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : submit,
                    child: loading
                        ? const CircularProgressIndicator()
                        : Text(isRegistering ? 'Create account' : 'Sign in'),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      isRegistering = !isRegistering;
                      error = null;
                    }),
                    child: Text(
                      isRegistering
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
