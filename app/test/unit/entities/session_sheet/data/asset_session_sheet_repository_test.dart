import 'package:billard_cfa/entities/session_sheet/data/asset_session_sheet_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:flutter_test/flutter_test.dart';

String _sheet({
  required String technique,
  required int part,
  required int order,
  String? previous,
}) =>
    '''
version: 1
id: $technique-$part
order: $order
technique: $technique
part: $part
title: Titre $technique
technical_sheets: [5]
previous: ${previous ?? 'null'}
catalogue_block: $technique
notion: Une notion.
theme: {name: Deux mots, pitch: Un pitch.}
recall:
  points: [Un, Deux]
  question: {ask: Q ?, answer: R.}
  src: S
theory:
  sections:
    - id: t1
      title: Théorie
      weight: {children: 1, adults: 1}
      body: [Une phrase.]
      key_point: Retenir.
      demo: null
      illustrations: []
      src: S
illustrations: []
training:
  exercises:
    - id: e1
      ref: {block: $technique, n: 1}
      diagram: entrainement-p01-e1
      title: Exo
      weight: {children: 1, adults: 1}
      setup: Mise en place.
      instruction: Consigne.
      expected: Attendu.
      mistakes: []
      playful: {hook: Accroche., challenge: Défi.}
      passes: 1
      src: S
game:
  title: Jeu
  source_game: 7
  adapted: false
  players: Deux
  materials: null
  setup_illustration: null
  rules: [Règle.]
  scoring: Score.
  end: Fin.
  playful_variant: Variante.
${previous == null ? '' : '  link_previous: {notion_of: $previous, rule: Règle., note: Note.}\n'}  weight: {children: 1, adults: 1}
  adaptation: {children: null, adults: null}
  src: S
review:
  prompts: [Bilan ?]
sources:
  - {rank: S, file: Fiches.pdf, page: 1, note: Fiche}
''';

const _dir = 'assets/fiches/';

AssetSessionSheetRepository _repository(
  Map<String, String> files, {
  List<String>? listing,
}) => AssetSessionSheetRepository(
  (path) async => files[path] ?? (throw StateError('absent : $path')),
  () async => listing ?? files.keys.toList(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('with the real assets', () {
    final repository = AssetSessionSheetRepository.fromBundle();

    test('loads the pilot sheet', () async {
      final all = await repository.getAll();

      expect(all.map((s) => s.id.value), contains('demi-bille-1'));
    });

    test('finds a sheet by id and returns null for an unknown one', () async {
      final found = await repository.getById(SheetId('demi-bille-1'));

      expect(found, isNotNull);
      expect(found!.order, 9);
      expect(await repository.getById(SheetId('inconnue-9')), isNull);
    });
  });

  group('with injected loaders', () {
    final files = {
      '${_dir}02-puissance-2.yaml': _sheet(
        technique: 'puissance',
        part: 2,
        order: 2,
        previous: 'puissance-1',
      ),
      '${_dir}01-puissance-1.yaml': _sheet(
        technique: 'puissance',
        part: 1,
        order: 1,
      ),
    };

    test(
      'returns the sheets in catalogue order, whatever the listing',
      () async {
        final all = await _repository(files).getAll();

        expect(all.map((s) => s.order), [1, 2]);
      },
    );

    test('reads only the yaml files of the sheet directory', () async {
      final repository = _repository(
        files,
        listing: [
          ...files.keys,
          'assets/catalogue/catalogue-entrainement.yaml',
          '${_dir}README.md',
          'assets/diagrammes/jeux/p07.yaml',
        ],
      );

      expect(await repository.getAll(), hasLength(2));
    });

    test('loads once', () async {
      var reads = 0;
      final repository = AssetSessionSheetRepository((path) async {
        reads++;
        return files[path]!;
      }, () async => files.keys.toList());

      final first = await repository.getAll();
      final second = await repository.getAll();

      expect(identical(first, second), isTrue);
      expect(reads, 2);
    });

    test('finds a sheet by id', () async {
      final found = await _repository(files).getById(SheetId('puissance-2'));

      expect(found!.part, 2);
      expect(found.previous, SheetId('puissance-1'));
    });

    test('turns any malformed file into invalidSheet', () async {
      final repository = _repository({'${_dir}01-x-1.yaml': 'version: 1'});

      await expectLater(
        repository.getAll(),
        throwsA(
          isA<InvariantViolation>().having(
            (e) => e.code,
            'code',
            InvariantCode.invalidSheet,
          ),
        ),
      );
    });

    test('turns a read error into invalidSheet', () async {
      final repository = AssetSessionSheetRepository(
        (path) async => throw StateError('E/S'),
        () async => ['${_dir}01-x-1.yaml'],
      );

      await expectLater(
        repository.getAll(),
        throwsA(
          isA<InvariantViolation>().having(
            (e) => e.code,
            'code',
            InvariantCode.invalidSheet,
          ),
        ),
      );
    });

    test('refuses two sheets with the same id', () async {
      final repository = _repository({
        '${_dir}01-puissance-1.yaml': files['${_dir}01-puissance-1.yaml']!,
        '${_dir}09-puissance-1.yaml': files['${_dir}01-puissance-1.yaml']!,
      });

      await expectLater(
        repository.getAll(),
        throwsA(
          isA<InvariantViolation>().having(
            (e) => e.code,
            'code',
            InvariantCode.invalidSheet,
          ),
        ),
      );
    });

    test('refuses two sheets with the same order', () async {
      final repository = _repository({
        '${_dir}01-puissance-1.yaml': files['${_dir}01-puissance-1.yaml']!,
        '${_dir}01-bille-pleine-1.yaml': _sheet(
          technique: 'bille-pleine',
          part: 1,
          order: 1,
        ),
      });

      await expectLater(
        repository.getAll(),
        throwsA(isA<InvariantViolation>()),
      );
    });

    test('an empty directory is an empty catalogue', () async {
      expect(await _repository({}).getAll(), isEmpty);
    });
  });
}
