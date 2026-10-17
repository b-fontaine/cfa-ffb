import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/text_measure.dart';

/// Une session de rendu : la fonte chargée, qui mesure le texte pour la mise
/// en page puis dessine la scène avec les mêmes métriques.
abstract interface class PrintSession {
  /// Mesure du texte dans la fonte du document.
  TextMeasure get measure;

  /// Le PDF de [document] (octets du fichier).
  Future<List<int>> render(PrintDocument document);
}

/// Port du rendu PDF (ADR 0021) : implémenté dans la couche `data` avec le
/// paquet `pdf`, seul endroit de l'application à le connaître.
abstract interface class PrintRenderer {
  /// Charge la fonte et ouvre une session de rendu.
  Future<PrintSession> open();
}
