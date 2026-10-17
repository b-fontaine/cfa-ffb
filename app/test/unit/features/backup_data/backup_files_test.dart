import 'dart:convert';
import 'dart:typed_data';

import 'package:billard_cfa/features/backup_data/data/file_picker_backup_files.dart';
import 'package:billard_cfa/features/backup_data/data/in_memory_backup_files.dart';
import 'package:billard_cfa/features/backup_data/domain/backup_codec.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Plateforme de sélection de fichiers programmable.
class _FakePlatform extends FilePickerPlatform with MockPlatformInterfaceMixin {
  Uri? saveResult;
  PlatformFile? pickResult;
  String? savedName;
  Uint8List? savedBytes;
  String? savedMime;

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

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => pickResult;
}

final class _PickedFile extends PlatformFile {
  _PickedFile(this._bytes, {int? length, this.readable = true})
    : _length = length ?? _bytes.length;

  final List<int> _bytes;
  final int _length;

  /// Faux : la lecture du contenu échoue (preuve qu'il n'est pas lu).
  final bool readable;

  @override
  String get name => 'sauvegarde.json';

  @override
  Uri get uri => Uri.parse('file:///tmp/sauvegarde.json');

  @override
  XFile get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => _length;

  @override
  Future<int?> length() async => _length;

  @override
  Future<Uint8List> readAsBytes() async {
    if (!readable) throw StateError('le contenu ne devait pas être lu');
    return Uint8List.fromList(_bytes);
  }

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.value(Uint8List.fromList(_bytes));
}

void main() {
  group('FilePickerBackupFiles', () {
    late _FakePlatform platform;
    late FilePickerBackupFiles files;

    setUp(() {
      platform = _FakePlatform();
      FilePickerPlatform.instance = platform;
      files = FilePickerBackupFiles();
    });

    test('saves the content as a JSON file', () async {
      platform.saveResult = Uri.parse('file:///tmp/club.json');

      final saved = await files.save(fileName: 'club.json', content: 'é{}');

      expect(saved, isTrue);
      expect(platform.savedName, 'club.json');
      expect(utf8.decode(platform.savedBytes!), 'é{}');
      expect(platform.savedMime, 'application/json');
    });

    test('reports a cancelled save', () async {
      expect(await files.save(fileName: 'club.json', content: '{}'), isFalse);
    });

    test('counts a browser download as saved without any location', () async {
      // Sur le web, `file_picker` télécharge et rend `null` : rien ne distingue
      // alors un enregistrement d'une annulation.
      final browser = FilePickerBackupFiles(savesByDownload: true);

      final saved = await browser.save(fileName: 'club.json', content: '{}');

      expect(saved, isTrue);
      expect(platform.savedName, 'club.json');
    });

    test('still counts a save with a location when downloading', () async {
      platform.saveResult = Uri.parse('file:///tmp/club.json');
      final browser = FilePickerBackupFiles(savesByDownload: true);

      expect(await browser.save(fileName: 'club.json', content: '{}'), isTrue);
    });

    test('reads the picked file as UTF-8 text', () async {
      platform.pickResult = _PickedFile(utf8.encode('{"é":1}'));

      expect(await files.pick(), '{"é":1}');
    });

    test('returns null when the picker is cancelled', () async {
      expect(await files.pick(), isNull);
    });

    test('does not read a file larger than a backup can be', () async {
      platform.pickResult = _PickedFile(
        const [],
        length: BackupCodec.maxContentLength + 1,
        readable: false,
      );

      expect(await files.pick(), '');
    });

    test('reads a file exactly at the maximum size', () async {
      platform.pickResult = _PickedFile(
        utf8.encode('{}'),
        length: BackupCodec.maxContentLength,
      );

      expect(await files.pick(), '{}');
    });

    test('gives an empty text for a file that is not UTF-8', () async {
      platform.pickResult = _PickedFile([0xff, 0xfe, 0xfd]);

      expect(await files.pick(), '');
    });
  });

  group('InMemoryBackupFiles', () {
    test('keeps the last saved file and serves the next pick', () async {
      final files = InMemoryBackupFiles();

      expect(await files.pick(), isNull);
      expect(files.lastSaved, isNull);

      expect(await files.save(fileName: 'a.json', content: '{}'), isTrue);
      expect(files.lastSaved, (fileName: 'a.json', content: '{}'));

      files.nextPick = 'contenu';
      expect(await files.pick(), 'contenu');
      expect(await files.pick(), isNull);
    });

    test('can simulate a cancelled save', () async {
      final files = InMemoryBackupFiles()..cancelSave = true;

      expect(await files.save(fileName: 'a.json', content: '{}'), isFalse);
      expect(files.lastSaved, isNull);
    });
  });
}
