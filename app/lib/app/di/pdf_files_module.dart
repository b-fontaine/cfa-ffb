import 'package:billard_cfa/app/platform/pdf_files_factory.dart';
import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';
import 'package:injectable/injectable.dart';

/// Câblage de la sortie PDF (ADR 0021) : une seule pour toute l'application.
@module
abstract class PdfFilesModule {
  @singleton
  PdfFiles pdfFiles() => createPdfFiles();
}
