/// Configurações da aplicação Web obtidas em tempo de compilação (--dart-define).
/// 
/// O Supabase utiliza a chave anônima pública (anon key) desenhada para
/// requisições client-side com proteção via RLS (Row Level Security).
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
