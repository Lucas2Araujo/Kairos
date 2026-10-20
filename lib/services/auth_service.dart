import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
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

  /// Inicializa e restaura sessão salva ou processa tokens do redirect OAuth
  Future<void> init() async {
    _handleOAuthRedirectUrl();
    _restoreLocalSession();
  }

  void _restoreLocalSession() {
    try {
      final token = web.window.localStorage.getItem(_storageKeyToken);
      final userJson = web.window.localStorage.getItem(_storageKeyUser);
      if (token != null && userJson != null) {
        _accessToken = token;
        _currentUser = AuthUser.fromJson(json.decode(userJson));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao restaurar sessão local: $e');
    }
  }

  /// Processa fragmento da URL (#access_token=... ou ?code=...) após retorno do Supabase
  void _handleOAuthRedirectUrl() {
    try {
      final hash = web.window.location.hash;
      if (hash.isNotEmpty && hash.contains('access_token=')) {
        final rawHash = hash.startsWith('#') ? hash.substring(1) : hash;
        final params = Uri.splitQueryString(rawHash);
        final token = params['access_token'];
        if (token != null && token.isNotEmpty) {
          _accessToken = token;
          web.window.localStorage.setItem(_storageKeyToken, token);
          
          // Limpa o hash da URL para ficar limpo
          web.window.history.replaceState(null, '', web.window.location.pathname);
          _fetchUserProfile(token);
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao processar redirect de auth: $e');
    }
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
        web.window.localStorage.setItem(_storageKeyUser, json.encode(data));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao obter perfil do usuário: $e');
    }
  }

  /// Inicia o fluxo oficial de login Google via Supabase OAuth
  void signInWithGoogle() {
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final redirectUrl = web.window.location.origin;

    final oauthUrl = Uri.parse(
      '$supabaseUrl/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}',
    );

    debugPrint('[AuthService] Redirecionando para Google OAuth: $oauthUrl');
    web.window.location.assign(oauthUrl.toString());
  }

  /// Realiza logout e limpa o armazenamento local
  void signOut() {
    _currentUser = null;
    _accessToken = null;
    try {
      web.window.localStorage.removeItem(_storageKeyToken);
      web.window.localStorage.removeItem(_storageKeyUser);
    } catch (_) {}
    notifyListeners();
  }
}
