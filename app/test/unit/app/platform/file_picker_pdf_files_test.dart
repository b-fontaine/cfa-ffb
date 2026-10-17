import 'dart:typed_data';

import 'package:billard_cfa/app/platform/file_picker_pdf_files.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Plateforme de sélection de fichiers programmable.
class _FakePlatform extends FilePickerPlatform with MockPlatformInterfaceMixin {
  Uri? saveResult;
  String? savedName;
  Uint8List? savedBytes;
  String? savedMime;
  FileType? savedType;
  List<String>? savedExtensions;

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
    savedName = fileName;
    savedBytes = bytes;
    savedMime = mimeType;
    return saveResult;
  }
}

class _RecordingPrinter implements PdfPrinter {
  final List<({Uint8List bytes, String title})> jobs = [];

  @override
  Future<void> print(Uint8List bytes, {required String title}) async {
    jobs.add((bytes: bytes, title: title));
  }
}

void main() {
  late _FakePlatform platform;

  setUp(() {
    platform = _FakePlatform();
    FilePickerPlatform.instance = platform;
  });

  group('save', () {
    test('hands the bytes to the file picker as a PDF file', () async {
      platform.saveResult = Uri.parse('file:///tmp/seance.pdf');

      final saved = await FilePickerPdfFiles().save(
        fileName: 'seance-x-enfants.pdf',
        bytes: [37, 80, 68, 70, 45],
      );

      expect(saved, isTrue);
      expect(platform.savedName, 'seance-x-enfants.pdf');
      expect(platform.savedBytes, [37, 80, 68, 70, 45]);
      expect(platform.savedMime, 'application/pdf');
    });

    test('counts a browser download as saved without any location', () async {
      // Sur le web, `file_picker` déclenche un téléchargement et rend `null` :
      // rien ne distingue alors un enregistrement d'une annulation.
      final saved = await FilePickerPdfFiles(savesByDownload: true)
          .save(fileName: 'x.pdf', bytes: [1]);

      expect(saved, isTrue);
      expect(platform.savedName, 'x.pdf');
    });

    test(
      'still reports a cancelled dialog elsewhere than on the web',
      () async {
        final saved = await FilePickerPdfFiles().save(
          fileName: 'x.pdf',
          bytes: [1],
        );

        expect(saved, isFalse);
      },
    );

    test('reports a cancelled dialog as not saved', () async {
      final saved = await FilePickerPdfFiles().save(
        fileName: 'x.pdf',
        bytes: [1],
      );

      expect(saved, isFalse);
    });
  });

  group('print', () {
    test('cannot print without a printer, and printing does nothing', () async {
      final files = FilePickerPdfFiles();

      expect(files.canPrint, isFalse);
      await files.print(fileName: 'x.pdf', bytes: [1]);
      expect(platform.savedName, isNull);
    });

    test('sends the bytes to the printer of the platform', () async {
      final printer = _RecordingPrinter();
      final files = FilePickerPdfFiles(printer: printer);

      expect(files.canPrint, isTrue);
      await files.print(fileName: 'x.pdf', bytes: [1, 2, 3]);

      expect(printer.jobs, hasLength(1));
      expect(printer.jobs.single.bytes, [1, 2, 3]);
      expect(printer.jobs.single.title, 'x.pdf');
    });

    test('never saves when printing', () async {
      final files = FilePickerPdfFiles(printer: _RecordingPrinter());

      await files.print(fileName: 'x.pdf', bytes: [1]);

      expect(platform.savedName, isNull);
    });
  });
}
