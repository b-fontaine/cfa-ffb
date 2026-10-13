import 'dart:io';

import 'package:billard_cfa/entities/exercise_catalog/data/catalogue_yaml_parser.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/data/asset_diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:flutter_test/flutter_test.dart';

// Correspondance catalogue d'entraînement <-> diagrammes, établie par les
// données : le titre du bloc du catalogue est le titre de la fiche transcrite
// (`sheet`) et le numéro de l'exercice est `exercise`. Aucune table de
// correspondance écrite à la main.
//
// Exercices du catalogue SANS schéma dans la source : aucun à ce jour. Si la
// source en perd un, ce test échoue et nomme l'exercice ; la liste ci-dessous
// ne se complète qu'en constatant l'absence dans le PDF, jamais en inventant un
// schéma.
const _withoutDiagram = <String>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final catalogue = parseCatalogue(
    File('assets/catalogue/catalogue-entrainement.yaml').readAsStringSync(),
  );

  test(
    'every catalogue exercise has its diagram, but the listed ones',
    () async {
      final library = await AssetDiagramRepository.fromBundle().load();

      final missing = [
        for (final block in catalogue.blocks)
          for (final spec in block.exercises)
            if (library
                .find(
                  DiagramKey.training(
                    sheet: block.title,
                    exercise: spec.ref.number,
                  ),
                )
                .isEmpty)
              '${spec.ref.blockId}/${spec.ref.number}',
      ];

      expect(missing, _withoutDiagram);
    },
  );

  test(
    'the diagram of an exercise carries the rate of the catalogue',
    () async {
      final library = await AssetDiagramRepository.fromBundle().load();

      final differences = <String>[];
      for (final block in catalogue.blocks) {
        for (final spec in block.exercises) {
          final diagrams = library.find(
            DiagramKey.training(sheet: block.title, exercise: spec.ref.number),
          );
          for (final diagram in diagrams) {
            final rate = diagram.successRate;
            if (rate != null && rate != spec.rate) {
              differences.add('${diagram.id} : $rate au lieu de ${spec.rate}');
            }
          }
        }
      }

      expect(differences, isEmpty, reason: differences.join('\n'));
    },
  );

  test('a diagram never contradicts a stated catalogue bridge', () async {
    final library = await AssetDiagramRepository.fromBundle().load();

    final differences = <String>[];
    for (final block in catalogue.blocks) {
      for (final spec in block.exercises) {
        final diagrams = library.find(
          DiagramKey.training(sheet: block.title, exercise: spec.ref.number),
        );
        for (final diagram in diagrams) {
          final bridge = switch (diagram.bridge) {
            DiagramBridge.frame => Bridge.frame,
            DiagramBridge.surface => Bridge.surface,
            // « aucun » ou illisible : la transcription n'affirme rien.
            DiagramBridge.none || DiagramBridge.unknown || null => null,
          };
          // Le catalogue ne dit rien (E3 et E4 du quart de bille) : la
          // transcription déduit « surface » du schéma, en le signalant
          // dans `uncertainties` ; seule une contradiction d'un chevalet
          // énoncé est un défaut.
          if (spec.bridge != null && bridge != null && bridge != spec.bridge) {
            differences.add(
              '${diagram.id} : ${bridge.name} au lieu de ${spec.bridge?.name}',
            );
          }
        }
      }
    }

    expect(differences, isEmpty, reason: differences.join('\n'));
  });

  test('no training diagram is orphaned from the catalogue', () async {
    final library = await AssetDiagramRepository.fromBundle().load();
    final reached = <String>{
      for (final block in catalogue.blocks)
        for (final spec in block.exercises)
          for (final diagram in library.find(
            DiagramKey.training(sheet: block.title, exercise: spec.ref.number),
          ))
            diagram.id,
    };
    final training = library.diagrams
        .where((d) => d.kind == DiagramKind.exercise)
        .map((d) => d.id)
        .toSet();

    expect(training.difference(reached), isEmpty);
  });

  test(
    'the sheet repeated in the source gives two diagrams per exercise',
    () async {
      final library = await AssetDiagramRepository.fromBundle().load();
      final block = catalogue.blockById('rejet-naturel')!;

      expect(block.duplicateInSource, isTrue);
      for (final spec in block.exercises) {
        final found = library.find(
          DiagramKey.training(sheet: block.title, exercise: spec.ref.number),
        );

        expect(found, hasLength(2), reason: '${spec.ref}');
        expect(found.first.sourcePage, lessThan(found.last.sourcePage));
      }
    },
  );
}
