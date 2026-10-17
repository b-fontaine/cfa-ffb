import 'dart:typed_data';

import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// `file_picker` tel qu'il se comporte sur le web : `saveFile` déclenche un
/// téléchargement et rend toujours `null`, comme pour une annulation.
class DownloadOnlyFilePicker extends FilePickerPlatform
    with MockPlatformInterfaceMixin {
  /// Fichiers téléchargés, dans l'ordre.
  final List<({String fileName, Uint8List bytes})> downloads = [];

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    downloads.add((fileName: fileName, bytes: bytes));
    return null;
  }
}
