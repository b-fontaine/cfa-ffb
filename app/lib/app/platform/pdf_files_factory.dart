// Le navigateur est la valeur par défaut, le mobile et le bureau (`dart:io`)
// n'ont pas d'impression directe.
import 'package:billard_cfa/app/platform/pdf_files_web.dart'
    if (dart.library.io) 'package:billard_cfa/app/platform/pdf_files_native.dart';
import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';

/// La sortie PDF de la plate-forme : enregistrement partout, impression
/// directe sur le web (ADR 0021).
PdfFiles createPdfFiles() => createPlatformPdfFiles();
