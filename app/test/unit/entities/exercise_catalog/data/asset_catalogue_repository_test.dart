import 'dart:io';

import 'package:billard_cfa/entities/exercise_catalog/data/asset_catalogue_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('with the real asset', () {
    final repository = AssetCatalogueRepository.fromBundle();

    test('loads 13 blocks and 64 exercises', () async {
      final catalogue = await repository.load();

      expect(catalogue.blocks, hasLength(13));
      expect(catalogue.exercises, hasLength(64));
    });

    test('teaches the bank rebound before the natural rejection [U]', () async {
      final catalogue = await repository.load();
      final ids = catalogue.blocks.map((b) => b.id).toList();

      expect(
        ids.indexOf('rebond-bande'),
        lessThan(ids.indexOf('rejet-naturel')),
      );
    });

    test('starts with power and ends with white ball trajectories', () async {
      final catalogue = await repository.load();

      expect(catalogue.blocks.first.id, 'puissance');
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
