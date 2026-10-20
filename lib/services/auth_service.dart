import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config/app_config.dart';
import 'auth_loopback_stub.dart' if (dart.library.io) 'auth_loopback_io.dart';

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

  /// Inicializa e restaura sessão salva ou processa callback OAuth
  Future<void> init() async {
    if (kIsWeb) {
      String? token = Uri.base.queryParameters['access_token'];
      if (token == null && Uri.base.fragment.isNotEmpty) {
        final frag = Uri.base.fragment;
        final cleanFrag = frag.contains('?') ? frag.split('?').last : (frag.startsWith('/') ? frag.substring(1) : frag);
        final params = Uri.splitQueryString(cleanFrag);
        token = params['access_token'];
      }
      if (token != null && token.isNotEmpty) {
        await setSessionToken(token);
      }
    }
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

  /// Inicia o fluxo de login Google compatível com a plataforma atual
  Future<void> signInWithGoogle() async {
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;

    // 1. Android e iOS: GoogleSignIn nativo com troca de id_token via REST
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final googleSignIn = GoogleSignIn(
          serverClientId: AppConfig.googleWebClientId.isNotEmpty ? AppConfig.googleWebClientId : null,
          scopes: ['email', 'profile'],
        );
        final account = await googleSignIn.signIn();
        if (account == null) {
          return;
        }

        final auth = await account.authentication;
        final idToken = auth.idToken;
        final accessToken = auth.accessToken;

        if (idToken != null && idToken.isNotEmpty) {
          final res = await http.post(
            Uri.parse('$supabaseUrl/auth/v1/token?grant_type=id_token'),
            headers: {
              'apikey': supabaseKey,
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'provider': 'google',
              'id_token': idToken,
              if (accessToken != null) 'access_token': accessToken,
            }),
          );

          if (res.statusCode == 200) {
            final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
            final supabaseToken = data['access_token'] as String?;
            if (supabaseToken != null && supabaseToken.isNotEmpty) {
              await setSessionToken(supabaseToken);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('[AuthService] GoogleSignIn nativo falhou: $e. Usando fallback OAuth.');
      }

      // Fallback Mobile via Deep Link OAuth
      const redirectUrl = 'nhaapp://login-callback';
      final oauthUrl = Uri.parse(
        '$supabaseUrl/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}',
      );
      await launchUrl(oauthUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // 2. Desktop (Linux, Windows, macOS): Loopback HTTP local (http://localhost:8000/callback)
    if (!kIsWeb) {
      try {
        final tokenFuture = startDesktopLoopbackServer(port: 8000);
        const redirectUrl = 'http://localhost:8000/callback';
        final oauthUrl = Uri.parse(
          '$supabaseUrl/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}',
        );
        await launchUrl(oauthUrl, mode: LaunchMode.externalApplication);
        final token = await tokenFuture;
        if (token != null && token.isNotEmpty) {
          await setSessionToken(token);
        }
      } catch (e) {
        debugPrint('[AuthService] Desktop OAuth loopback erro: $e');
      }
      return;
    }

    // 3. Web: Redirecionamento na mesma origem
    final redirectUrl = Uri.base.origin + Uri.base.path;
    final oauthUrl = Uri.parse(
      '$supabaseUrl/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}',
    );
    await launchUrl(oauthUrl, mode: LaunchMode.platformDefault);
  }

  /// Realiza logout e limpa o armazenamento local
  Future<void> signOut() async {
    _currentUser = null;
    _accessToken = null;
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKeyToken);
      await prefs.remove(_storageKeyUser);
    } catch (_) {}
    notifyListeners();
  }
}
