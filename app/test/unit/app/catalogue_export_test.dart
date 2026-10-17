import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/sheet_export.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_animator_sheet.dart';
import 'package:billard_cfa/features/export_sheet/domain/export_results_sheets.dart';
import 'package:billard_cfa/features/export_sheet/domain/print_scene.dart';
import 'package:billard_cfa/features/export_sheet/domain/results_template.dart';
import 'package:billard_cfa/features/run_sheet/domain/resolve_run_plan.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations_en.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations_fr.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show Environment;

/// Garde sur **tout le catalogue** (28 séances, deux publics, deux langues)
/// avec la vraie fonte : aucun caractère absent d'Exo 2 (`θ` est remplacé,
/// tout autre est refusé), la feuille tient en un nombre raisonnable de pages,
/// et les valeurs préremplies d'une fiche résultats tiennent à gauche de la
/// grille.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
  });
  tearDown(getIt.reset);

  /// Pour chaque séance et chaque public : la feuille de l'animateur et les
  /// fiches résultats.
  Future<List<(String, Audience, ExportedDocument, ExportedDocument)>>
  everything(AppLocalizations l10n) async {
    final sheets = await getIt<SessionSheetRepository>().getAll();
    final renderer = getIt<ExportAnimatorSheet>();
    final results = getIt<ExportResultsSheets>();
    final out = <(String, Audience, ExportedDocument, ExportedDocument)>[];
    for (final sheet in sheets) {
      for (final audience in Audience.values) {
        final plan = switch (await getIt<ResolveRunPlan>()(
          sheet.id,
          audience: audience,
          withRecallExercise: false,
        )) {
          Ok(:final value) => value,
          Err(:final failure) => fail('${sheet.id} : $failure'),
        };
        final input = sheetPrintInputFrom(plan, l10n, printedOn: '12 Oct 2026');
        final animator = switch (await renderer(input)) {
          Ok(:final value) => value,
          Err(:final failure) => fail('${sheet.id}/$audience : $failure'),
        };
        final series = resultsPlanFrom(plan, l10n);
        final sheets = switch (await results(
          ResultsSheetsRequest(
            title: series.title,
            fileName: series.fileName,
            series: series.series,
            columns: series.columns,
            labels: series.labels,
          ),
        )) {
          Ok(:final value) => value,
          Err(:final failure) => fail('${sheet.id}/$audience : $failure'),
        };
        out.add((sheet.id.value, audience, animator, sheets));
      }
    }
    return out;
  }

  test('prints the 28 sessions for both audiences, in English', () async {
    final all = await everything(AppLocalizationsEn());

    expect(all, hasLength(56));
    for (final (id, audience, animator, results) in all) {
      expect(animator.document.pages, isNotEmpty, reason: '$id $audience');
      expect(
        animator.document.pages.length,
        lessThanOrEqualTo(7),
        reason: '$id $audience : trop de pages',
      );
      expect(results.document.pages, isNotEmpty, reason: '$id $audience');
    }
  });

  test('prints the 28 sessions for both audiences, in French', () async {
    final all = await everything(AppLocalizationsFr());

    expect(all, hasLength(56));
    for (final (id, audience, animator, _) in all) {
      expect(
        animator.document.pages.length,
        lessThanOrEqualTo(7),
        reason: '$id $audience : trop de pages',
      );
    }
  });

  test(
    'keeps the prefilled values left of the grid, above its bottom line',
    () async {
      for (final (id, audience, _, results) in await everything(
        AppLocalizationsFr(),
      )) {
        for (final page in results.document.pages) {
          for (final item in page.items.whereType<PrintText>()) {
            if (item.tag != 'prefill' && item.tag != 'prefill-label') continue;
            // Dans le bloc du haut, la colonne de gauche s'arrête à la ligne du
            // bas de la grille ; dans celui du bas, 381,5 points plus bas.
            final inBottomBlock = item.y > ResultsTemplate.pageHeight / 2;
            final y = inBottomBlock
                ? item.y - ResultsTemplate.blockPitchY
                : item.y;
            expect(
              y,
              lessThanOrEqualTo(ResultsTemplate.gridBottom),
              reason: '$id $audience : « ${item.text} » déborde',
            );
          }
        }
      }
    },
  );

  test(
    'replaces theta, which Exo 2 lacks, in the sessions that use it',
    () async {
      final all = await everything(AppLocalizationsFr());

      String printed(String id) => [
        for (final (sheet, _, animator, _) in all)
          if (sheet == id)
            ...animator.document.pages
                .expand((p) => p.items)
                .whereType<PrintText>()
                .map((t) => t.text),
      ].join(' ');
      for (final id in ['finesse-1', 'trois-quarts-1']) {
        expect(printed(id), contains('thêta'), reason: id);
      }
      for (final (id, audience, animator, _) in all) {
        final text = animator.document.pages
            .expand((p) => p.items)
            .whereType<PrintText>()
            .map((t) => t.text)
            .join(' ');
        expect(text, isNot(contains('θ')), reason: '$id $audience');
      }
    },
  );
}
