import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

abstract interface class SshPublicKeyExporter {
  Future<String?> exportPublicKey({
    required String publicKeyOpenSsh,
    required String fileName,
    required String dialogTitle,
  });
}

class FilePickerSshPublicKeyExporter implements SshPublicKeyExporter {
  const FilePickerSshPublicKeyExporter();

  @override
  Future<String?> exportPublicKey({
    required String publicKeyOpenSsh,
    required String fileName,
    required String dialogTitle,
  }) {
    final normalized = publicKeyOpenSsh.endsWith('\n')
        ? publicKeyOpenSsh
        : '$publicKeyOpenSsh\n';
    return FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['pub'],
      bytes: Uint8List.fromList(utf8.encode(normalized)),
    );
  }
}
