import 'package:billard_cfa/entities/exercise_catalog/data/asset_catalogue_repository.dart';
import 'package:billard_cfa/entities/session_sheet/data/asset_session_sheet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Contrat de la suggestion de séance (ADR 0009) sur les vrais assets : tout
// exercice d'un bloc qui a des séances est contenu dans exactement une séance
// du bloc, et un bloc sans séance est exactement
// `quantites-de-billes` et `trajectoires-blanche`. Sans cela, la proposition
// redonnée (« toutes faites ») ou l'exercice de tête pourraient manquer.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every exercise of a block with sessions is in exactly one', () async {
    final sheets = await AssetSessionSheetRepository.fromBundle().getAll();
    final catalogue = await AssetCatalogueRepository.fromBundle().load();

    final blocksWithSessions = {for (final s in sheets) s.catalogueBlock};
    for (final block in catalogue.blocks) {
      if (!blocksWithSessions.contains(block.id)) continue;
      for (final spec in block.exercises) {
        final holders = [
          for (final sheet in sheets)
            if (sheet.catalogueBlock == block.id &&
                sheet.exercises.any((e) => e.ref == spec.ref))
              sheet.id.value,
        ];

        expect(holders, hasLength(1), reason: '${spec.ref} : $holders');
      }
    }
  });

  test('only two blocks of the catalogue have no session (S8)', () async {
    final sheets = await AssetSessionSheetRepository.fromBundle().getAll();
    final catalogue = await AssetCatalogueRepository.fromBundle().load();

    final withSessions = {for (final s in sheets) s.catalogueBlock};
    final without = {
      for (final block in catalogue.blocks)
        if (!withSessions.contains(block.id)) block.id,
    };

    expect(without, {'quantites-de-billes', 'trajectoires-blanche'});
  });
}
