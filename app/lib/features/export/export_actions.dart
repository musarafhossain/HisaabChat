import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaabchat/core/network/api_exception.dart';
import 'package:hisaabchat/core/platform/file_saver.dart';
import 'package:hisaabchat/core/widgets/toast.dart';
import 'package:hisaabchat/features/export/data/export_repository.dart';

/// Fetches an export from the server and hands it to the user (download,
/// Save As or share sheet), with a toast for the result. Returns true when
/// the file reached the user.
Future<bool> runExport(BuildContext context, WidgetRef ref, Future<ExportFile> Function(ExportRepository) build) async {
  final toast = AppToast.of(context);
  final saver = ref.read(fileSaverProvider);
  try {
    final file = await build(ref.read(exportRepositoryProvider));
    final outcome = await saver.save(fileName: file.fileName, bytes: file.bytes, mimeType: file.mimeType);
    switch (outcome) {
      case SaveOutcome.saved:
        toast.show('Saved ${file.fileName}', kind: ToastKind.success);
      case SaveOutcome.downloaded:
        toast.show('Downloading ${file.fileName}', kind: ToastKind.success);
      case SaveOutcome.shared:
      case SaveOutcome.cancelled:
        break;
    }
    return outcome != SaveOutcome.cancelled;
  } on ApiException catch (error) {
    toast.show(error.message, kind: ToastKind.error);
  } on Exception {
    toast.show('Couldn’t save the file', kind: ToastKind.error);
  }
  return false;
}

/// "Export CSV" for one account or one person (all their transactions).
Future<bool> exportCsvFor(BuildContext context, WidgetRef ref, {String? accountId, String? personId}) =>
    runExport(context, ref, (repo) => repo.transactionsCsv(accountId: accountId, personId: personId));
