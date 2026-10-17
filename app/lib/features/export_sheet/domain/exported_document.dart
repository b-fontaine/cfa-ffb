import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Un document prêt à enregistrer ou à imprimer : la scène (montrée par
/// l'aperçu), le fichier PDF qui en est issu et le nom proposé.
@immutable
class ExportedDocument {
  const ExportedDocument({
    required this.document,
    required this.bytes,
    required this.fileName,
  });

  final PrintDocument document;
  final List<int> bytes;
  final String fileName;
}
