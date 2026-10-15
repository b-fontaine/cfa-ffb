import 'package:billard_cfa/entities/exercise_catalog/data/asset_catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/data/asset_diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/entities/session_sheet/data/asset_session_sheet_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/presentation/sheet_illustration_view.dart';
import 'package:billard_cfa/features/browse_sheets/domain/get_sheet.dart';
import 'package:billard_cfa/features/browse_sheets/domain/list_sheets.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_catalogue.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_catalogue_view.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/sheet_detail_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Contrat de rendu sur les 28 vraies séances de `assets/fiches/` : aucune
// erreur de rendu (débordement compris) pour chaque séance et chaque
// illustration, en français et en anglais, pour les deux publics, texte
// agrandi à 200 % sur téléphone et tablette en paysage.

const _locales = [Locale('fr'), Locale('en')];

/// (nom, taille logique, facteur de texte).
const _screens = [
  ('téléphone, texte à 200 %', Size(360, 800), 2.0),
  ('tablette en paysage', Size(1024, 768), 1.0),
];

Widget _app(Locale locale, double textScale, Widget body) => MaterialApp(
  theme: AppTheme.light(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SessionSheet> sheets;
  late Map<String, SheetDetail> details;
  late GetSheet getSheet;

  setUpAll(() async {
    final repository = AssetSessionSheetRepository.fromBundle();
    sheets = await repository.getAll();
    getSheet = GetSheet(
      repository,
      AssetCatalogueRepository.fromBundle(),
      AssetDiagramRepository.fromBundle(),
      RulesConfig(),
    );
    details = {};
    for (final sheet in sheets) {
      final result = await getSheet(sheet.id);
      details[sheet.id.value] = switch (result) {
        Ok(:final value) => value,
        Err(:final failure) => throw StateError('$failure'),
      };
    }
  });

  test('the catalogue holds 28 sessions of 14 techniques', () async {
    final catalogue = switch (await ListSheets(
      AssetSessionSheetRepository.fromBundle(),
    )()) {
      Ok(:final value) => value,
      Err(:final failure) => throw StateError('$failure'),
    };

    expect(catalogue.sheetCount, 28);
    expect(catalogue.techniqueCount, 14);
  });

  test('every referenced diagram and exercise rate is found', () {
    for (final detail in details.values) {
      final sheet = detail.sheet;
      expect(detail.diagramsUnreadable, isFalse, reason: '${sheet.id}');
      for (final exercise in sheet.exercises) {
        expect(
          detail.exerciseSpecs[exercise.id],
          isNotNull,
          reason: '${sheet.id} ${exercise.id} : taux du catalogue',
        );
        expect(
          detail.diagrams[exercise.diagramId],
          isNotNull,
          reason: '${sheet.id} ${exercise.id} : schéma ${exercise.diagramId}',
        );
      }
    }
  });

  for (final locale in _locales) {
    for (final (screenName, size, scale) in _screens) {
      testWidgets(
        'the catalogue renders in ${locale.languageCode}, $screenName',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final catalogue = switch (await tester.runAsync(
            ListSheets(AssetSessionSheetRepository.fromBundle()).call,
          )) {
            Ok(:final value) => value,
            _ => throw StateError('catalogue illisible'),
          };

          for (final filtered in [
            catalogue,
            catalogue.filtered(SheetReviewFilter.toReview),
          ]) {
            await tester.pumpWidget(
              _app(
                locale,
                scale,
                SheetCatalogueView(
                  catalogue: filtered,
                  filter: SheetReviewFilter.none,
                  onFilter: (_) {},
                  onOpenSheet: (_) {},
                ),
              ),
            );
            await tester.pump();

            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  // Les 28 séances, un test par séance : un échec nomme la séance.
  for (final id in _frozenSheetIds) {
    testWidgets('$id renders without error in both languages, both audiences, '
        'large text and tablet', (tester) async {
      final detail = details[id]!;
      for (final locale in _locales) {
        for (final audience in Audience.values) {
          for (final (screenName, size, scale) in _screens) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              _app(
                locale,
                scale,
                SheetDetailView(
                  detail: detail,
                  audience: audience,
                  onAudienceChanged: (_) {},
                ),
              ),
            );
            await tester.pump();

            expect(
              tester.takeException(),
              isNull,
              reason: '$id ${locale.languageCode} ${audience.name} $screenName',
            );
          }
        }
      }
      addTearDown(tester.view.reset);
    });

    testWidgets('$id : every illustration renders with a spoken description', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final detail = details[id]!;
      final specs = {
        for (final e in detail.diagrams.entries)
          e.key: tableDiagramSpecOf(e.value),
      };
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final illustration in detail.sheet.illustrations) {
        await tester.pumpWidget(
          _app(
            const Locale('fr'),
            1,
            SheetIllustrationView(
              illustration: illustration,
              diagrams: specs,
              proposal: true,
            ),
          ),
        );
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: '$id illustration ${illustration.id}',
        );
        expect(
          find.bySemanticsLabel(illustration.alt),
          findsWidgets,
          reason: '$id illustration ${illustration.id} : texte alternatif',
        );
      }
      handle.dispose();
    });
  }
}

/// Identifiants des 28 séances (FORMAT § 1.3), figés par
/// `session_sheets_contract_test.dart`.
const _frozenSheetIds = [
  'posture-1',
  'posture-2',
  'puissance-1',
  'puissance-2',
  'bille-fantome-1',
  'bille-pleine-1',
  'bille-pleine-2',
  'demi-bille-1',
  'demi-bille-2',
  'trois-quarts-1',
  'trois-quarts-2',
  'quart-1',
  'finesse-1',
  'rebond-bande-1',
  'rebond-bande-2',
  'rejet-naturel-1',
  'rejet-naturel-2',
  'coule-1',
  'coule-2',
  'coule-3',
  'carreau-1',
  'carreau-2',
  'angle-droit-1',
  'angle-droit-2',
  'retro-1',
  'retro-2',
  'retro-3',
  'retro-4',
];
