import 'package:billard_cfa/entities/session_sheet/data/session_sheet_yaml_parser.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// Dossier des assets ; copie de la source unique de vérité
/// (`scripts/sync_fiches.sh`, vérifiée par `scripts/check.sh --fast`).
const sheetAssetsDirectory = 'assets/fiches/';

/// Charge les séances du catalogue depuis les assets de l'application : tous
/// les fichiers `NN-<id>.yaml` du dossier, rendus dans l'ordre du catalogue.
///
/// Lecture seule. Un fichier mal formé, un identifiant ou un ordre en double
/// font échouer la lecture avec `invalidSheet` : la couche data ne laisse
/// sortir que des [Failure].
@LazySingleton(as: SessionSheetRepository)
class AssetSessionSheetRepository implements SessionSheetRepository {
  AssetSessionSheetRepository(this._loadString, this._listAssets);

  @factoryMethod
  AssetSessionSheetRepository.fromBundle()
    : this(
        rootBundle.loadString,
        () async =>
            (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets(),
      );

  final Future<String> Function(String path) _loadString;
  final Future<List<String>> Function() _listAssets;
  List<SessionSheet>? _cached;

  @override
  Future<List<SessionSheet>> getAll() async => _cached ??= await _read();

  @override
  Future<SessionSheet?> getById(SheetId id) async {
    for (final sheet in await getAll()) {
      if (sheet.id == id) return sheet;
    }
    return null;
  }

  Future<List<SessionSheet>> _read() async {
    try {
      final paths =
          (await _listAssets())
              .where(
                (path) =>
                    path.startsWith(sheetAssetsDirectory) &&
                    path.endsWith('.yaml'),
              )
              .toList()
            ..sort();
      final sheets = [
        for (final path in paths) parseSessionSheet(await _loadString(path)),
      ]..sort((a, b) => a.order.compareTo(b.order));
      final ids = sheets.map((s) => s.id).toSet();
      final orders = sheets.map((s) => s.order).toSet();
      if (ids.length != sheets.length || orders.length != sheets.length) {
        throw const InvariantViolation(
          InvariantCode.invalidSheet,
          'identifiant ou ordre en double dans le catalogue',
        );
      }
      return List.unmodifiable(sheets);
    } on Failure {
      rethrow;
    } on Object catch (e) {
      // Toute autre erreur (E/S, manifeste) est un échec du catalogue.
      throw InvariantViolation(InvariantCode.invalidSheet, '$e');
    }
  }
}
