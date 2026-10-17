import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';

/// Double de la sortie PDF : conserve le dernier fichier enregistré et les
/// impressions, et simule l'annulation de la boîte d'enregistrement.
class FakePdfFiles implements PdfFiles {
  FakePdfFiles({this.printSupported = true});

  final bool printSupported;

  /// Simule l'annulation de la boîte d'enregistrement.
  bool cancelSave = false;

  /// Simule un échec d'écriture (levé par [save]).
  Exception? saveError;

  /// Simule un échec d'impression (levé par [print]).
  Exception? printError;

  /// Fichiers enregistrés, dans l'ordre.
  final List<({String fileName, List<int> bytes})> saved = [];

  /// Documents envoyés à l'impression, dans l'ordre.
  final List<({String fileName, List<int> bytes})> printed = [];

  ({String fileName, List<int> bytes})? get lastSaved =>
      saved.isEmpty ? null : saved.last;

  @override
  bool get canPrint => printSupported;

  @override
  Future<bool> save({
    required String fileName,
    required List<int> bytes,
  }) async {
    final error = saveError;
    if (error != null) throw error;
    if (cancelSave) return false;
    saved.add((fileName: fileName, bytes: List.of(bytes)));
    return true;
  }

  @override
  Future<void> print({
    required String fileName,
    required List<int> bytes,
  }) async {
    final error = printError;
    if (error != null) throw error;
    printed.add((fileName: fileName, bytes: List.of(bytes)));
  }
}
