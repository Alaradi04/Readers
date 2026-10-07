class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nuvjugabiuyybonliwob.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Rbv3leUU2-YBoIXPxTEvYw_nI2ZtPsw',
  );
  static const googleBooksApiKey = String.fromEnvironment(
    'GOOGLE_BOOKS_API_KEY',
    defaultValue: '',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
