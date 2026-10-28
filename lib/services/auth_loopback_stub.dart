import 'dart:async';

/// Dados de tokens recebidos pelo callback de autenticação.
class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  const AuthTokens({required this.accessToken, this.refreshToken});
}

/// Stub para Web onde HttpServer e File de dart:io não estão disponíveis.
Future<AuthTokens?> startDesktopLoopbackServer({int port = 8000}) async => null;

/// Stub para download de arquivo via stream.
Future<String> downloadFileStream({
  required String url,
  required String targetPath,
  void Function(double progress, int received, int total)? onProgress,
}) async {
  throw UnsupportedError('Download de arquivos não suportado no navegador.');
}

