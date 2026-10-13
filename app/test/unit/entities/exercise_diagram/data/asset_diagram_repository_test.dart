import 'dart:io';

import 'package:billard_cfa/entities/exercise_diagram/data/asset_diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';

String _page(String id, {String kind = 'exercise', String color = 'white'}) =>
    '''
version: 1
source: {file: "T.pdf", page: 1, rank: S}
diagrams:
  - id: $id
    kind: $kind
    sheet: "Fiche"
    caption: "Légende."
    description: "Texte."
    uncertainties: []
    balls:
      - {id: w, color: $color, at: [1, 1]}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('with the real assets', () {
    final repository = AssetDiagramRepository.fromBundle();

    test('loads the 103 table diagrams of the three transcriptions', () async {
      final library = await repository.load();

      expect(library.diagrams, hasLength(103));
    });

    test(
      'holds the entrainement, initiation and jeux transcriptions only',
      () async {
        final library = await repository.load();
        final families = library.diagrams.map((d) => d.id.split('-').first);

        expect(families.toSet(), {'entrainement', 'initiation', 'jeux'});
      },
    );

    test('reads the first training exercise', () async {
      final library = await repository.load();
      final found = library.find(
        DiagramKey.training(sheet: 'La puissance', exercise: 1),
      );

      expect(found.single.id, 'entrainement-p01-e1');
      expect(found.single.successRate!.successes, 7);
      expect(found.single.successRate!.attempts, 9);
    });

    test('returns the same library on the second load', () async {
      expect(
        identical(await repository.load(), await repository.load()),
        isTrue,
      );
    });
  });

  group('with injected loaders', () {
    test('reads the yaml pages of the directory, in path order', () async {
      final repository = AssetDiagramRepository(
        (path) async => _page(path.split('/').last.split('.').first),
        () async => [
          'assets/diagrammes/jeux/p02.yaml',
          'assets/catalogue/catalogue-entrainement.yaml',
          'assets/diagrammes/README.md',
          'assets/diagrammes/entrainement/p01.yaml',
        ],
      );

      final library = await repository.load();

      expect(library.diagrams.map((d) => d.id), ['p01', 'p02']);
    });

    test('loads each page once and caches the library', () async {
      var loads = 0;
      final repository = AssetDiagramRepository((path) async {
        loads++;
        return File('assets/diagrammes/jeux/p01.yaml').readAsStringSync();
      }, () async => ['assets/diagrammes/jeux/p01.yaml']);

      await repository.load();
      await repository.load();

      expect(loads, 1);
    });

    test('reports an unreadable page as an invalid diagram', () async {
      final repository = AssetDiagramRepository(
        (path) async => _page('x', color: 'pink'),
        () async => ['assets/diagrammes/jeux/p01.yaml'],
      );

      await expectLater(
        repository.load,
        throwsA(
          isA<InvariantViolation>().having(
            (e) => e.code,
            'code',
            InvariantCode.invalidDiagram,
          ),
        ),
      );
    });

    test(
      'reports a page that cannot be loaded as an invalid diagram',
      () async {
        final repository = AssetDiagramRepository(
          (path) async => throw StateError('lecture impossible'),
          () async => ['assets/diagrammes/jeux/p01.yaml'],
        );

        await expectLater(
          repository.load,
          throwsA(
            isA<InvariantViolation>().having(
              (e) => e.code,
              'code',
              InvariantCode.invalidDiagram,
            ),
          ),
        );
      },
    );

    test(
      'reports an unreadable asset manifest as an invalid diagram',
      () async {
        final repository = AssetDiagramRepository(
          (path) async => _page('x'),
          () async => throw StateError('manifeste illisible'),
        );

        await expectLater(
          repository.load,
          throwsA(
            isA<InvariantViolation>().having(
              (e) => e.code,
              'code',
              InvariantCode.invalidDiagram,
            ),
          ),
        );
      },
    );
  });
}
