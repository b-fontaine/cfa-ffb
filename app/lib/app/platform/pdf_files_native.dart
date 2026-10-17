import 'package:billard_cfa/app/platform/file_picker_pdf_files.dart';
import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';

/// Hors navigateur : enregistrement seulement, l'entrée « Imprimer » est
/// masquée (l'impression système demande un ADR à part).
PdfFiles createPlatformPdfFiles() => FilePickerPdfFiles();
