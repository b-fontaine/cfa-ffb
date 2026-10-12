import 'package:billard_cfa/entities/exercise_catalog/data/catalogue_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// Chemin de l'asset ; copie de la source unique de vérité
/// (`scripts/sync_catalogue.sh`, vérifiée par `scripts/check.sh --fast`).
const catalogueAssetPath = 'assets/catalogue/catalogue-entrainement.yaml';

/// Charge le catalogue depuis les assets de l'application.
@LazySingleton(as: CatalogueRepository)
class AssetCatalogueRepository implements CatalogueRepository {
  AssetCatalogueRepository(this._loadString);

  @factoryMethod
  AssetCatalogueRepository.fromBundle() : this(rootBundle.loadString);

  final Future<String> Function(String path) _loadString;
  ExerciseCatalogue? _cached;

  @override
  Future<ExerciseCatalogue> load() async =>
      _cached ??= parseCatalogue(await _loadString(catalogueAssetPath));
}
