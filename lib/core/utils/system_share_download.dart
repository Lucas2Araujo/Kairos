import 'dart:typed_data';

import 'system_share_download_stub.dart'
    if (dart.library.js_interop) 'system_share_download_web.dart'
    if (dart.library.io) 'system_share_download_io.dart' as impl;

/// Fachada multiplataforma (Android & Web) para compartilhamento nativo e
/// download/salvamento real de arquivos sem adicionar pacotes extras.
class SystemShareDownload {
  const SystemShareDownload._();

  /// Abre o diálogo de compartilhamento nativo do sistema (Android Intent / Web Share).
  /// Caso o navegador desktop não suporte Web Share, copia automaticamente para o Clipboard
  /// e retorna `false` para que a UI exiba o aviso correspondente.
  static Future<bool> shareText({
    required String text,
    String subject = 'Kairós',
  }) {
    return impl.platformShareText(text: text, subject: subject);
  }

  /// Baixa/salva bytes reais no dispositivo (Downloads/Galeria via MediaStore no Android
  /// ou download direto pelo navegador na Web).
  static Future<bool> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    return impl.platformSaveBytes(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
