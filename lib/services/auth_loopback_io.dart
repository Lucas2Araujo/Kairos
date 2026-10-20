import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Servidor HTTP temporário em loopback IPv4 para plataformas Desktop.
/// Captura os tokens OAuth do Supabase via redirecionamento de bridge HTML/JS.
Future<String?> startDesktopLoopbackServer({int port = 8000}) async {
  HttpServer? server;
  final completer = Completer<String?>();

  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } catch (_) {
    return null;
  }

  const successHtml = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Login Concluído</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background-color: #121212;
            color: #ffffff;
            text-align: center;
        }
        .card {
            background-color: #1e1e1e;
            padding: 40px;
            border-radius: 16px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.5);
            max-width: 420px;
        }
        h2 { color: #4caf50; margin-top: 0; }
        p { color: #cccccc; line-height: 1.5; font-size: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <h2>Autenticação Concluída!</h2>
        <p>Login com Google realizado com sucesso no aplicativo Hinário Adventista.</p>
        <p>Você já pode fechar esta janela do navegador e retornar ao app.</p>
    </div>
</body>
</html>''';

  const bridgeHtml = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Conectando ao Hinário...</title>
    <script>
        window.onload = function() {
            var hash = window.location.hash;
            if (hash && hash.length > 1) {
                window.location.href = window.location.pathname + "?" + hash.substring(1);
            } else {
                var search = window.location.search;
                if (!search) {
                    document.getElementById("status").innerText = "Aguardando resposta de autenticação...";
                }
            }
        };
    </script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background-color: #121212;
            color: #ffffff;
            text-align: center;
        }
        .spinner {
            border: 4px solid #333333;
            border-top: 4px solid #7c4dff;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px auto;
        }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div>
        <div class="spinner"></div>
        <h3 id="status">Finalizando conexão com o aplicativo...</h3>
    </div>
</body>
</html>''';

  final timeoutTimer = Timer(const Duration(minutes: 3), () {
    if (!completer.isCompleted) completer.complete(null);
    server?.close(force: true);
  });

  server.listen((HttpRequest req) async {
    final uri = req.uri;
    if (uri.path == '/callback') {
      final token = uri.queryParameters['access_token'];
      if (token != null && token.isNotEmpty) {
        req.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(successHtml);
        await req.response.close();

        if (!completer.isCompleted) completer.complete(token);
        timeoutTimer.cancel();
        Future.delayed(const Duration(milliseconds: 300), () => server?.close(force: true));
        return;
      }

      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(bridgeHtml);
      await req.response.close();
      return;
    }

    req.response
      ..statusCode = HttpStatus.notFound
      ..write('Not Found');
    await req.response.close();
  });

  return completer.future;
}

/// Baixa arquivo via streaming em disco com notificação de progresso.
Future<String> downloadFileStream({
  required String url,
  required String targetPath,
  void Function(double progress, int received, int total)? onProgress,
}) async {
  final client = http.Client();
  try {
    final response = await client.send(http.Request('GET', Uri.parse(url)));
    if (response.statusCode != 200) {
      throw HttpException('Falha HTTP ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    int received = 0;

    final file = File(targetPath);
    final sink = file.openWrite();

    await response.stream.listen((chunk) {
      received += chunk.length;
      sink.add(chunk);
      if (onProgress != null && total > 0) {
        onProgress(received / total, received, total);
      }
    }).asFuture();

    await sink.flush();
    await sink.close();
    return file.path;
  } finally {
    client.close();
  }
}
