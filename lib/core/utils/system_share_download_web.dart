import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@JS('navigator')
external JSObject get _navigator;

@JS('document')
external JSObject get _document;

@JS('URL')
external JSObject get _urlApi;

@JS('Blob')
extension type _JSBlob._(JSObject _) implements JSObject {
  external factory _JSBlob(JSArray<JSAny> blobParts, JSObject options);
}

Future<bool> platformShareText({
  required String text,
  required String subject,
}) async {
  try {
    if (_navigator.has('share')) {
      final shareData = JSObject()
        ..['title'] = subject.toJS
        ..['text'] = text.toJS;
      final promise = _navigator.callMethod<JSPromise<JSAny?>>('share'.toJS, shareData);
      await promise.toDart;
      return true;
    }
  } catch (e) {
    debugPrint('[SystemShareWeb] navigator.share indisponível ou cancelado: $e');
  }

  await Clipboard.setData(ClipboardData(text: text));
  return false;
}

Future<bool> platformSaveBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  try {
    final parts = <JSAny>[bytes.toJS].toJS;
    final options = JSObject()..['type'] = mimeType.toJS;
    final blob = _JSBlob(parts, options);
    final objectUrl = _urlApi.callMethod<JSString>('createObjectURL'.toJS, blob);

    final anchor = _document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
    anchor['href'] = objectUrl;
    anchor['download'] = fileName.toJS;
    final style = anchor['style'] as JSObject?;
    if (style != null) {
      style['display'] = 'none'.toJS;
    }

    final body = _document['body'] as JSObject?;
    body?.callMethod<JSAny?>('appendChild'.toJS, anchor);
    anchor.callMethod<JSAny?>('click'.toJS);
    body?.callMethod<JSAny?>('removeChild'.toJS, anchor);
    _urlApi.callMethod<JSAny?>('revokeObjectURL'.toJS, objectUrl);
    return true;
  } catch (e) {
    debugPrint('[SystemShareWeb] Erro ao iniciar download na Web: $e');
    return false;
  }
}
