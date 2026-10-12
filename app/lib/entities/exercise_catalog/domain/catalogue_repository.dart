import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';

/// Port de chargement du catalogue (implémenté dans la couche data).
abstract interface class CatalogueRepository {
  Future<ExerciseCatalogue> load();
}
