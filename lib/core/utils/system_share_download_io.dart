import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const MethodChannel _systemChannel = MethodChannel('kairos.app/system');

Future<bool> platformShareText({
  required String text,
  required String subject,
}) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  if (Platform.isAndroid) {
    try {
      final ok = await _systemChannel.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': subject,
      });
      if (ok == true) return true;
    } catch (e) {
      debugPrint('[SystemShareIO] Fallback clipboard no shareText: $e');
    }
  }

  await Clipboard.setData(ClipboardData(text: text));
  return false;
}

Future<bool> platformSaveBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return bytes.isNotEmpty;
  }

  if (Platform.isAndroid) {
    try {
      final savedUri = await _systemChannel.invokeMethod<String>('saveToDownloads', {
        'bytes': bytes,
        'fileName': fileName,
        'mimeType': mimeType,
      });
      if (savedUri != null && savedUri.isNotEmpty) return true;
    } catch (e) {
      debugPrint('[SystemShareIO] Fallback local file em saveBytes: $e');
    }
  }

  try {
    final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final outFile = File('${dir.path}/$fileName');
    await outFile.writeAsBytes(bytes, flush: true);
    return true;
  } catch (e) {
    debugPrint('[SystemShareIO] Erro ao salvar arquivo: $e');
    return false;
  }
}
