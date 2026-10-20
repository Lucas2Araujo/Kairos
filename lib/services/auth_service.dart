import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config/app_config.dart';

class AuthUser {
  final String id;
  final String email;
  final String name;
  final String avatarUrl;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl = '',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final meta = json['user_metadata'] as Map<String, dynamic>? ?? {};
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (meta['full_name'] ?? meta['name'] ?? json['email'] ?? 'Usuário').toString(),
      avatarUrl: (meta['avatar_url'] ?? '').toString(),
    );
  }
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AuthUser? _currentUser;
  String? _accessToken;
  final bool _isLoading = false;

  AuthUser? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;

  static const String _storageKeyToken = 'kairos_auth_token';
  static const String _storageKeyUser = 'kairos_auth_user';

  /// Inicializa e restaura sessão salva
  Future<void> init() async {
    await _restoreLocalSession();
  }

  Future<void> _restoreLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_storageKeyToken);
      final userJson = prefs.getString(_storageKeyUser);
      if (token != null && userJson != null) {
        _accessToken = token;
        _currentUser = AuthUser.fromJson(json.decode(userJson));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao restaurar sessão local: $e');
    }
  }

  Future<void> setSessionToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKeyToken, token);
    await _fetchUserProfile(token);
  }

  Future<void> _fetchUserProfile(String token) async {
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;

    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/auth/v1/user'),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        _currentUser = AuthUser.fromJson(data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKeyUser, json.encode(data));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao obter perfil do usuário: $e');
    }
  }

  /// Inicia o fluxo de login Google via Supabase OAuth
  Future<void> signInWithGoogle() async {
    final supabaseUrl = AppConfig.authSupabaseUrl;
    const redirectUrl = 'nhaapp://login-callback';

    final oauthUrl = Uri.parse(
      '$supabaseUrl/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}',
    );

    debugPrint('[AuthService] Redirecionando para Google OAuth: $oauthUrl');
    await launchUrl(oauthUrl, mode: LaunchMode.externalApplication);
  }

  /// Realiza logout e limpa o armazenamento local
  Future<void> signOut() async {
    _currentUser = null;
    _accessToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKeyToken);
      await prefs.remove(_storageKeyUser);
    } catch (_) {}
    notifyListeners();
  }
}
