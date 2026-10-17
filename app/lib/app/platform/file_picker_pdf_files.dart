import 'dart:typed_data';

import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';
import 'package:file_picker/file_picker.dart';

/// Imprime un PDF avec ce que la plate-forme offre (le navigateur) ; absent
/// ailleurs, l'entrée « Imprimer » est alors masquée.
abstract interface class PdfPrinter {
  /// Envoie [bytes] à l'impression ; [title] nomme le travail.
  Future<void> print(Uint8List bytes, {required String title});
}

/// Sortie PDF via `file_picker` (ADR 0021) : téléchargement sur le web, boîte
/// d'enregistrement sur les autres plateformes, comme la sauvegarde.
/// L'impression est celle de [printer], quand la plate-forme en a une.
class FilePickerPdfFiles implements PdfFiles {
  FilePickerPdfFiles({this.printer, this.savesByDownload = false});

  /// L'impression directe de la plate-forme, `null` quand elle n'en a pas.
  final PdfPrinter? printer;

  /// Vrai sur le web : `file_picker` y déclenche un téléchargement et rend
  /// `null`, comme pour une annulation ; rien ne distingue les deux, et le
  /// navigateur n'annule jamais sans que l'utilisateur le voie : le fichier est
  /// donc tenu pour enregistré.
  final bool savesByDownload;

  @override
  bool get canPrint => printer != null;

  @override
  Future<bool> save({
    required String fileName,
    required List<int> bytes,
  }) async {
    final location = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'application/pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return savesByDownload || location != null;
  }

  @override
  Future<void> print({
    required String fileName,
    required List<int> bytes,
  }) async {
    final direct = printer;
    if (direct == null) return;
    await direct.print(Uint8List.fromList(bytes), title: fileName);
  }
}
