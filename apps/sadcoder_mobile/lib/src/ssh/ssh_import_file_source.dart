import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

abstract interface class SshImportFileSource {
  Future<String?> pickTextFile({
    required List<String> allowedExtensions,
    required String dialogTitle,
  });
}

class FilePickerSshImportFileSource implements SshImportFileSource {
  const FilePickerSshImportFileSource();

  @override
  Future<String?> pickTextFile({
    required List<String> allowedExtensions,
    required String dialogTitle,
  }) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: allowedExtensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions.isEmpty ? null : allowedExtensions,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes != null) {
      return const Utf8Decoder().convert(bytes);
    }
    final path = file.path;
    if (path == null || path.trim().isEmpty) {
      throw const FileSystemException('Selected file has no readable path.');
    }
    return const Utf8Decoder().convert(await File(path).readAsBytes());
  }
}
