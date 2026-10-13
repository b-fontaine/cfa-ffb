import 'dart:io';

import 'package:billard_cfa/entities/exercise_catalog/data/asset_catalogue_repository.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('with the real asset', () {
    final repository = AssetCatalogueRepository.fromBundle();

    test('loads 15 blocks and 72 exercises', () async {
      final catalogue = await repository.load();

      // 13 blocs [S] (64 exercices) + 2 blocs [Prop] de 4 exercices.
      expect(catalogue.blocks, hasLength(15));
      expect(catalogue.exercises, hasLength(72));
    });

    test('proposes exactly the posture and ghost ball blocks [Prop]', () async {
      final catalogue = await repository.load();
      final proposals = catalogue.blocks.where((b) => b.isProposal);

      expect(proposals.map((b) => b.id), ['posture', 'bille-fantome']);
      for (final block in proposals) {
        expect(block.exercises, hasLength(4), reason: block.id);
        expect(
          block.exercises.map((e) => e.source),
          everyElement(Provenance.prop),
        );
        expect(block.exercises.every((e) => !e.bronze), isTrue);
      }
    });

    test('teaches posture, power, ghost ball, then full ball [Prop]', () async {
      final catalogue = await repository.load();
      final ids = catalogue.blocks.map((b) => b.id).toList();

      expect(ids.take(4), [
        'posture',
        'puissance',
        'bille-fantome',
        'bille-pleine',
      ]);
    });

    test('keeps the federal blocks sourced', () async {
      final catalogue = await repository.load();

      expect(catalogue.blocks.where((b) => !b.isProposal), hasLength(13));
    });

    test('teaches the bank rebound before the natural rejection [U]', () async {
      final catalogue = await repository.load();
      final ids = catalogue.blocks.map((b) => b.id).toList();

      expect(
        ids.indexOf('rebond-bande'),
        lessThan(ids.indexOf('rejet-naturel')),
      );
    });

    test('starts with posture and ends with white ball trajectories', () async {
      final catalogue = await repository.load();

      expect(catalogue.blocks.first.id, 'posture');
      expect(catalogue.blocks.last.id, 'trajectoires-blanche');
    });

    test('requires 5 passed passes by default [U]', () async {
      expect((await repository.load()).defaultPassesRequired, 5);
    });

    test('reads the first exercise rate 7 on 9', () async {
      final spec = (await repository.load()).exercise(ref('puissance', 1))!;

      expect(spec.rate, rate(7, 9));
    });
  });

  group('with an injected loader', () {
    test(
      'reads the configured asset path once and caches the catalogue',
      () async {
        var loads = 0;
        final repository = AssetCatalogueRepository((path) async {
          loads++;
          expect(path, catalogueAssetPath);
          return File('assets/catalogue/catalogue-entrainement.yaml')
              .readAsStringSync();
        });

        final first = await repository.load();
        final second = await repository.load();

        expect(identical(first, second), isTrue);
        expect(loads, 1);
      },
    );
  });
}
