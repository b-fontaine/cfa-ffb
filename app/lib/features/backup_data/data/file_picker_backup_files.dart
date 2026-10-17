import 'dart:convert';
import 'dart:typed_data';

import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_files.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:injectable/injectable.dart';

/// Fichiers de sauvegarde via `file_picker` : téléchargement sur le web,
/// boîte d'enregistrement sur les autres plateformes.
@LazySingleton(as: BackupFiles, env: [Environment.prod])
class FilePickerBackupFiles implements BackupFiles {
  FilePickerBackupFiles({this.savesByDownload = false});

  /// Fabrique de production : le téléchargement est celui du navigateur.
  @factoryMethod
  FilePickerBackupFiles.platform() : this(savesByDownload: kIsWeb);

  /// Vrai sur le web : `file_picker` y déclenche un téléchargement et rend
  /// `null`, comme pour une annulation ; rien ne distingue les deux, et le
  /// navigateur n'annule jamais sans que l'utilisateur le voie : le fichier est
  /// donc tenu pour enregistré (même choix que `FilePickerPdfFiles`).
  final bool savesByDownload;

  static const _extensions = ['json'];

  @override
  Future<bool> save({required String fileName, required String content}) async {
    final location = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: _extensions,
    );
    return savesByDownload || location != null;
  }

  @override
  Future<String?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _extensions,
    );
    if (file == null) return null;
    // Jamais de lecture en mémoire d'un fichier qui ne peut pas être une
    // sauvegarde : il sera refusé comme illisible.
    final length = await file.length();
    if (length != null && length > BackupCodec.maxContentLength) return '';
    try {
      return utf8.decode(await file.readAsBytes());
    } on FormatException {
      return '';
    }
  }
}
