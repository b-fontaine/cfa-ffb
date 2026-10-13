import 'package:billard_cfa/entities/exercise_diagram/data/diagram_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_library.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// Dossier des assets ; copie de la source unique de vérité
/// (`scripts/sync_diagrammes.sh`, vérifiée par `scripts/check.sh --fast`).
const diagramAssetsDirectory = 'assets/diagrammes/';

/// Charge les schémas depuis les assets de l'application : toutes les pages
/// `pNN.yaml` du dossier, dans l'ordre alphabétique des chemins.
@LazySingleton(as: DiagramRepository)
class AssetDiagramRepository implements DiagramRepository {
  AssetDiagramRepository(this._loadString, this._listAssets);

  @factoryMethod
  AssetDiagramRepository.fromBundle()
    : this(
        rootBundle.loadString,
        () async =>
            (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets(),
      );

  final Future<String> Function(String path) _loadString;
  final Future<List<String>> Function() _listAssets;
  DiagramLibrary? _cached;

  @override
  Future<DiagramLibrary> load() async => _cached ??= await _read();

  Future<DiagramLibrary> _read() async {
    try {
      final paths =
          (await _listAssets())
              .where(
                (path) =>
                    path.startsWith(diagramAssetsDirectory) &&
                    path.endsWith('.yaml'),
              )
              .toList()
            ..sort();
      return DiagramLibrary([
        for (final path in paths) ...parseDiagramPage(await _loadString(path)),
      ]);
    } on Object {
      // Toute erreur de lecture (page mal formée, E/S, manifeste) est un échec
      // du schéma : la couche data ne laisse sortir que des Failure.
      throw const InvariantViolation(InvariantCode.invalidDiagram);
    }
  }
}
