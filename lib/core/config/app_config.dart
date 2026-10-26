/// Configurações da aplicação Web obtidas em tempo de compilação (--dart-define)
/// com fallbacks automáticos para os projetos Supabase do app.
class AppConfig {
  AppConfig._();

  // Supabase Principal (Auth, Quizzes, Gamificação, Usuários)
  static const String defaultAuthSupabaseUrl = 'https://cjlqpvdkvuuopgjhidud.supabase.co';
  static const String defaultAuthSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqbHFwdmRrdnV1b3BnamhpZHVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk1NjAzODIsImV4cCI6MjEwNTEzNjM4Mn0.Q8swHh15cK94d4r9uSNwA2uY-5Hoo8QMTwc1n8wCMho';

  // Supabase Devocionais
  static const String defaultDevotionalSupabaseUrl = 'https://opbzivfgfkljqknrdvkq.supabase.co';
  static const String defaultDevotionalSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wYnppdmZnZmtsanFrbnJkdmtxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwODQ3MDIsImV4cCI6MjEwNDY2MDcwMn0.ph5gU8NnTGRN-vubHg3VREzomAuZS5g_qk6ZeCSri6s';

  // Cliente OAuth 2.0 Web configurado no Supabase / Google Cloud Console
  static const String defaultGoogleWebClientId = '59262708239-bp2ph1k2k0d0cdscfp40nnm65pc4fu8u.apps.googleusercontent.com';

  static const String _customSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _customSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static const String _customGoogleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
  static const String _customR2PublicUrl = String.fromEnvironment('R2_PUBLIC_URL', defaultValue: '');
  static const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.7.0.2');

  // Fallback padrão para o Cloudflare R2
  static const String defaultR2PublicUrl = 'https://pub-e5cb1f141cac4ba4b66a3a22426dbb9f.r2.dev';

  static String get authSupabaseUrl => _customSupabaseUrl.isNotEmpty ? _customSupabaseUrl : defaultAuthSupabaseUrl;
  static String get authSupabaseAnonKey => _customSupabaseAnonKey.isNotEmpty ? _customSupabaseAnonKey : defaultAuthSupabaseAnonKey;

  static String get devotionalSupabaseUrl => defaultDevotionalSupabaseUrl;
  static String get devotionalSupabaseAnonKey => defaultDevotionalSupabaseAnonKey;

  static String get googleWebClientId => _customGoogleClientId.isNotEmpty ? _customGoogleClientId : defaultGoogleWebClientId;

  /// URL pública base do Cloudflare R2 para streaming e download dos hinos
  static String get r2AudioBaseUrl => _customR2PublicUrl.isNotEmpty ? _customR2PublicUrl.replaceAll(RegExp(r'/+$'), '') : defaultR2PublicUrl;
}
