import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';

/// Port de chargement des schémas (implémenté dans la couche data).
abstract interface class DiagramRepository {
  Future<DiagramLibrary> load();
}
