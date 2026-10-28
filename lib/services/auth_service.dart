import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config/app_config.dart';
import 'auth_loopback_stub.dart' if (dart.library.io) 'auth_loopback_io.dart';
import 'theme_service.dart';

class AuthUser {
  final String id;
  final String email;
  final String name;
  final String avatarUrl;
  final String? defaultDevotionalCategory;
  final String? defaultSabbathSchoolCategory;

  String get displayName => name;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.avatarUrl = '',
    this.defaultDevotionalCategory,
    this.defaultSabbathSchoolCategory,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final meta = json['user_metadata'] as Map<String, dynamic>? ?? {};
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (meta['full_name'] ?? meta['name'] ?? json['email'] ?? 'Usuário').toString(),
      avatarUrl: (meta['avatar_url'] ?? '').toString(),
      defaultDevotionalCategory: meta['default_devo_category']?.toString(),
      defaultSabbathSchoolCategory: meta['default_ss_category']?.toString(),
    );
  }
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  AuthUser? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _errorMessage;

  AuthUser? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static const String _storageKeyToken = 'kairos_auth_token';
  static const String _storageKeyRefreshToken = 'kairos_auth_refresh_token';
  static const String _storageKeyUser = 'kairos_auth_user';
  static const MethodChannel _systemChannel = MethodChannel('kairos.app/system');

  /// Extrai parâmetros (access_token, refresh_token, code, error_description) de uma URI OAuth
  static Map<String, String> extractParamsFromUri(Uri uri) {
    final result = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      final frag = uri.fragment;
      final cleanFrag = frag.contains('?')
          ? frag.split('?').last
          : (frag.startsWith('/') ? frag.substring(1) : frag);
      try {
        result.addAll(Uri.splitQueryString(cleanFrag));
      } catch (_) {}
    }
    return result;
  }

  /// Extrai access_token de uma URI de callback OAuth (query ou fragmento)
  static String? extractAccessTokenFromUri(Uri uri) {
    final token = extractParamsFromUri(uri)['access_token'];
    return (token != null && token.isNotEmpty) ? token : null;
  }

  Future<void> _exchangeCodeForSession(String code) async {
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;

    try {
      final res = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/token?grant_type=authorization_code'),
        headers: {
          'apikey': supabaseKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({'code': code}),
      );

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final token = data['access_token'] as String?;
        final refresh = data['refresh_token'] as String?;
        if (token != null && token.isNotEmpty) {
          await setSessionToken(token, refreshToken: refresh, applyCloudPreferences: true);
        }
      } else {
        debugPrint('[AuthService] Falha ao trocar code por token (HTTP ${res.statusCode})');
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao trocar code por token: $e');
    }
  }

  Future<void> _handleDeepLink(String? link) async {
    if (link == null || link.isEmpty) return;
    try {
      final uri = Uri.parse(link);
      final params = extractParamsFromUri(uri);
      final error = params['error_description'] ?? params['error'];
      if (error != null && error.isNotEmpty) {
        _errorMessage = error;
        debugPrint('[AuthService] Erro OAuth no callback: $error');
        notifyListeners();
        return;
      }
      final token = params['access_token'];
      final refresh = params['refresh_token'];
      if (token != null && token.isNotEmpty) {
        await setSessionToken(token, refreshToken: refresh, applyCloudPreferences: true);
        return;
      }
      final code = params['code'];
      if (code != null && code.isNotEmpty) {
        await _exchangeCodeForSession(code);
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao processar deep link: $e');
    }
  }

  /// Inicializa e restaura sessão salva ou processa callback OAuth
  Future<void> init() async {
    await _restoreLocalSession();

    if (kIsWeb) {
      final params = extractParamsFromUri(Uri.base);
      final token = params['access_token'];
      final refresh = params['refresh_token'];
      if (token != null && token.isNotEmpty) {
        await setSessionToken(token, refreshToken: refresh, applyCloudPreferences: true);
      } else {
        final code = params['code'];
        if (code != null && code.isNotEmpty) {
          await _exchangeCodeForSession(code);
        }
      }
    } else if (!isTestEnvironment && defaultTargetPlatform == TargetPlatform.android) {
      _systemChannel.setMethodCallHandler((call) async {
        if (call.method == 'onDeepLink') {
          final link = call.arguments as String?;
          await _handleDeepLink(link);
        }
      });
      try {
        final initialLink = await _systemChannel.invokeMethod<String>('getInitialLink').timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        );
        if (initialLink != null && initialLink.isNotEmpty) {
          await _handleDeepLink(initialLink);
        }
      } catch (e) {
        debugPrint('[AuthService] Erro ao obter initialLink do Android: $e');
      }
    }
  }

  void _applyUserCloudPreferences(AuthUser user) {
    if (user.defaultDevotionalCategory != null &&
        const {'diario', 'jovem', 'mulher'}.contains(user.defaultDevotionalCategory)) {
      ThemeService().setDefaultDevotionalCategory(user.defaultDevotionalCategory!);
    }
    if (user.defaultSabbathSchoolCategory != null &&
        const {'adultos', 'jovens'}.contains(user.defaultSabbathSchoolCategory)) {
      ThemeService().setDefaultSabbathSchoolCategory(user.defaultSabbathSchoolCategory!);
    }
  }

  /// Renova a sessão usando o refresh_token salvo no Supabase
  Future<bool> refreshSession() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;

    try {
      final res = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {
          'apikey': supabaseKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({'refresh_token': refresh}),
      );

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final newAccess = data['access_token'] as String?;
        final newRefresh = data['refresh_token'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          _accessToken = newAccess;
          if (newRefresh != null && newRefresh.isNotEmpty) {
            _refreshToken = newRefresh;
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_storageKeyToken, _accessToken!);
          if (_refreshToken != null) {
            await prefs.setString(_storageKeyRefreshToken, _refreshToken!);
          }
          final userMap = data['user'] as Map<String, dynamic>?;
          if (userMap != null) {
            _currentUser = AuthUser.fromJson(userMap);
            await prefs.setString(_storageKeyUser, json.encode(userMap));
          }
          notifyListeners();
          return true;
        }
      } else if (res.statusCode == 400 || res.statusCode == 401) {
        // Refresh token revogado ou inválido: encerra sessão
        await signOut();
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao renovar sessão: $e');
    }
    return false;
  }

  Future<void> _restoreLocalSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_storageKeyToken);
      final refresh = prefs.getString(_storageKeyRefreshToken);
      final userJson = prefs.getString(_storageKeyUser);
      if (token != null && token.isNotEmpty) {
        _accessToken = token;
        _refreshToken = refresh;
        if (userJson != null && userJson.isNotEmpty) {
          _currentUser = AuthUser.fromJson(json.decode(userJson));
          notifyListeners();
        }
        final profileOk = await _fetchUserProfile(token);
        if (!profileOk && _refreshToken != null && _refreshToken!.isNotEmpty) {
          await refreshSession();
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao restaurar sessão local: $e');
    }
  }

  Future<void> setSessionToken(
    String token, {
    String? refreshToken,
    bool applyCloudPreferences = false,
  }) async {
    _accessToken = token;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKeyToken, token);
    if (_refreshToken != null && _refreshToken!.isNotEmpty) {
      await prefs.setString(_storageKeyRefreshToken, _refreshToken!);
    }
    final ok = await _fetchUserProfile(token);
    if (ok && applyCloudPreferences && _currentUser != null) {
      _applyUserCloudPreferences(_currentUser!);
    }
  }

  Future<bool> _fetchUserProfile(String token) async {
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
        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        _currentUser = AuthUser.fromJson(data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKeyUser, json.encode(data));
        notifyListeners();

        final meta = data['user_metadata'] as Map<String, dynamic>? ?? {};
        if (meta['default_devo_category'] == null || meta['default_ss_category'] == null) {
          syncPreferencesToCloud();
        }

        // Upsert silencioso em public.profiles
        try {
          http.post(
            Uri.parse('$supabaseUrl/rest/v1/profiles'),
            headers: {
              'apikey': supabaseKey,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Prefer': 'resolution=merge-duplicates',
            },
            body: json.encode({
              'id': _currentUser!.id,
              'email': _currentUser!.email,
              'full_name': _currentUser!.name,
              'avatar_url': _currentUser!.avatarUrl,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }),
          ).catchError((_) => http.Response('', 500));
        } catch (_) {}
        return true;
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao obter perfil do usuário: $e');
    }
    return false;
  }

  Future<bool> syncPreferencesToCloud({
    String? devotionalCategory,
    String? sabbathSchoolCategory,
  }) async {
    if (devotionalCategory != null) {
      ThemeService().setDefaultDevotionalCategory(devotionalCategory);
    }
    if (sabbathSchoolCategory != null) {
      ThemeService().setDefaultSabbathSchoolCategory(sabbathSchoolCategory);
    }

    if (_accessToken == null || _accessToken!.isEmpty) return false;

    Future<http.Response> sendRequest(String token) {
      return http.put(
        Uri.parse('${AppConfig.authSupabaseUrl}/auth/v1/user'),
        headers: {
          'apikey': AppConfig.authSupabaseAnonKey,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'data': {
            'default_devo_category': ThemeService().defaultDevotionalCategory,
            'default_ss_category': ThemeService().defaultSabbathSchoolCategory,
          },
        }),
      );
    }

    try {
      var res = await sendRequest(_accessToken!);
      if (res.statusCode == 401 && _refreshToken != null && _refreshToken!.isNotEmpty) {
        final refreshed = await refreshSession();
        if (refreshed && _accessToken != null) {
          res = await sendRequest(_accessToken!);
        }
      }

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        _currentUser = AuthUser.fromJson(data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_storageKeyUser, json.encode(data));
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AuthService] Erro ao sincronizar preferências na nuvem: $e');
    }
    return false;
  }

  /// Inicia o fluxo de login Google compatível com a plataforma atual
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
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
            // Usuário cancelou o seletor de contas do Google
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
              final supabaseRefresh = data['refresh_token'] as String?;
              if (supabaseToken != null && supabaseToken.isNotEmpty) {
                await setSessionToken(supabaseToken, refreshToken: supabaseRefresh, applyCloudPreferences: true);
                return;
              }
            }
            debugPrint('[AuthService] Falha na troca do idToken com Supabase (HTTP ${res.statusCode}). Usando fallback OAuth.');
          } else {
            debugPrint('[AuthService] GoogleSignIn nativo não retornou idToken. Usando fallback OAuth.');
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
          final tokensFuture = startDesktopLoopbackServer(port: 8000);
          const redirectUrl = 'http://localhost:8000/callback';
          final oauthUrl = Uri.parse(
            '$supabaseUrl/auth/v1/authorize?provider=google&redirect_to=${Uri.encodeComponent(redirectUrl)}',
          );
          await launchUrl(oauthUrl, mode: LaunchMode.externalApplication);
          final tokens = await tokensFuture;
          if (tokens != null && tokens.accessToken.isNotEmpty) {
            await setSessionToken(tokens.accessToken, refreshToken: tokens.refreshToken, applyCloudPreferences: true);
          }
        } catch (e) {
          _errorMessage = 'Falha no login desktop: $e';
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
    } catch (e) {
      _errorMessage = 'Erro no processo de login: $e';
      debugPrint('[AuthService] Erro no signInWithGoogle: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Realiza logout e limpa o armazenamento local
  Future<void> signOut() async {
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKeyToken);
      await prefs.remove(_storageKeyRefreshToken);
      await prefs.remove(_storageKeyUser);
    } catch (_) {}
    notifyListeners();
  }
}
