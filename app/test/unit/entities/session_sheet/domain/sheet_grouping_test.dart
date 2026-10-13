import 'package:billard_cfa/entities/session_sheet/domain/sheet_grouping.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/session_sheet_fixtures.dart';

Illustration _ref(String id, String diagram) => Illustration.diagramRef(
  id: id,
  caption: 'Légende.',
  alt: 'Texte alternatif.',
  diagramId: diagram,
);

void main() {
  group('groupByTechnique', () {
    test('ranks the techniques by teaching order and counts their parts', () {
      final groups = groupByTechnique(catalogueFixture().reversed);

      expect(groups.map((g) => (g.rank, g.technique, g.partCount)), [
        (1, 'posture', 1),
        (2, 'demi-bille', 2),
        (3, 'quart', 1),
      ]);
    });

    test('orders the sessions of a technique by part', () {
      final demi = groupByTechnique(catalogueFixture().reversed)[1];

      expect(demi.sheets.map((s) => s.part), [1, 2]);
    });

    test('is empty for an empty catalogue', () {
      expect(groupByTechnique(const []), isEmpty);
    });
  });

  group('partCountOf', () {
    test('counts the sessions of a technique', () {
      final all = catalogueFixture();

      expect(partCountOf(all, 'demi-bille'), 2);
      expect(partCountOf(all, 'quart'), 1);
      expect(partCountOf(all, 'inconnue'), 0);
    });
  });

  group('diagramIdsOf', () {
    test('holds the exercise diagrams and the diagram references', () {
      final sheet = buildSheet(
        illustrations: [_ref('i1', 'jeux-p07-g1'), contactIllustration('c1')],
      );

      expect(diagramIdsOf(sheet, null), {
        'entrainement-p05-e1',
        'entrainement-p05-e2',
        'jeux-p07-g1',
      });
    });

    test('adds the diagram references of the previous session', () {
      final previous = buildSheet(
        technique: 'bille-pleine',
        illustrations: [_ref('p1', 'initiation-p07-e1')],
      );
      final sheet = buildSheet();

      expect(diagramIdsOf(sheet, previous), contains('initiation-p07-e1'));
      expect(diagramIdsOf(sheet, null), isNot(contains('initiation-p07-e1')));
    });
  });
}
