import 'dart:typed_data';
import 'package:flutter/services.dart';

Future<bool> platformShareText({
  required String text,
  required String subject,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  return false;
}

Future<bool> platformSaveBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  return false;
}
