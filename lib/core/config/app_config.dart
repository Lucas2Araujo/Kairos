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

  static const String _customSupabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _customSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static String get authSupabaseUrl => _customSupabaseUrl.isNotEmpty ? _customSupabaseUrl : defaultAuthSupabaseUrl;
  static String get authSupabaseAnonKey => _customSupabaseAnonKey.isNotEmpty ? _customSupabaseAnonKey : defaultAuthSupabaseAnonKey;

  static String get devotionalSupabaseUrl => defaultDevotionalSupabaseUrl;
  static String get devotionalSupabaseAnonKey => defaultDevotionalSupabaseAnonKey;
}
