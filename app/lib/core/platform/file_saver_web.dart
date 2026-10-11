import 'dart:js_interop';
import 'dart:typed_data';

import 'package:hisaabchat/core/platform/file_saver.dart';
import 'package:web/web.dart' as web;

/// Starts a normal browser download (goes to the Downloads folder).
Future<SaveOutcome> saveFile({required String fileName, required Uint8List bytes, required String mimeType}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor
    ..click()
    ..remove();
  // Give the browser a moment to start the download before freeing the blob.
  Future<void>.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url)).ignore();
  return SaveOutcome.downloaded;
}
