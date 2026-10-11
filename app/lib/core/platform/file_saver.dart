import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/platform/file_saver_io.dart'
    if (dart.library.js_interop) 'package:hisaabchat/core/platform/file_saver_web.dart'
    as impl;

/// What happened to a file the app tried to hand to the user.
enum SaveOutcome {
  /// Written where the user chose (Windows Save As).
  saved,

  /// Given to the browser as a download (web).
  downloaded,

  /// Sent through the share sheet (Android).
  shared,

  /// The user closed the dialog or share sheet.
  cancelled,
}

/// Hands a generated file (an export) to the user the way each platform
/// expects: a browser download on web, a Save As dialog on Windows, the
/// share sheet on Android.
// A small interface so tests can swap in a fake.
// ignore: one_member_abstracts
abstract interface class FileSaver {
  Future<SaveOutcome> save({required String fileName, required Uint8List bytes, required String mimeType});
}

class PlatformFileSaver implements FileSaver {
  const PlatformFileSaver();

  @override
  Future<SaveOutcome> save({required String fileName, required Uint8List bytes, required String mimeType}) =>
      impl.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
}

final fileSaverProvider = Provider<FileSaver>((ref) => const PlatformFileSaver());
