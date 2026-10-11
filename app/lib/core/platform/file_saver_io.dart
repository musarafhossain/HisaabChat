import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:hisaabchat/core/platform/file_saver.dart';
import 'package:share_plus/share_plus.dart';

Future<SaveOutcome> saveFile({required String fileName, required Uint8List bytes, required String mimeType}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        subject: fileName,
      ),
    );
    return result.status == ShareResultStatus.dismissed ? SaveOutcome.cancelled : SaveOutcome.shared;
  }

  final extension = fileName.contains('.') ? fileName.split('.').last : '';
  final location = await getSaveLocation(
    suggestedName: fileName,
    acceptedTypeGroups: [
      if (extension.isNotEmpty)
        XTypeGroup(label: extension.toUpperCase(), extensions: [extension], mimeTypes: [mimeType]),
    ],
  );
  if (location == null) return SaveOutcome.cancelled;
  var path = location.path;
  if (extension.isNotEmpty && !path.toLowerCase().endsWith('.$extension')) path = '$path.$extension';
  await File(path).writeAsBytes(bytes, flush: true);
  return SaveOutcome.saved;
}
