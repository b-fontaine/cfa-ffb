import 'dart:ui';

import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/features/backup_data/presentation/ui/import_report_text.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/realistic_backup.dart';
import '../domain/club_import/planner_support.dart';

/// Le rapport d'import se lit en français et en anglais : chaque code, chaque
/// catégorie, chaque état a son texte dans les deux langues, sans paramètre
/// laissé en clair.
void main() {
  late AppLocalizations fr;
  late AppLocalizations en;

  setUpAll(() async {
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  void readable(String text) {
    expect(text, isNotEmpty);
    expect(text, isNot(contains('{')));
    expect(text, isNot(contains('}')));
  }

  test('every problem code is told in both languages', () {
    for (final code in ImportProblemCode.values) {
      final french = importProblemMessage(fr, code);
      final english = importProblemMessage(en, code);
      readable(french);
      readable(english);
      expect(french, isNot(english), reason: '${code.name} non traduit');
    }
  });

  test('every category and every status is told in both languages', () {
    for (final category in ImportCategory.values) {
      readable(importCategoryLabel(fr, category));
      readable(importCategoryLabel(en, category));
    }
    for (final status in ImportStatus.values) {
      readable(importStatusLabel(fr, status));
      readable(importStatusLabel(en, status));
      expect(
        importStatusLabel(fr, status),
        isNot(importStatusLabel(en, status)),
      );
    }
  });

  test('warnings carry their numbers', () {
    final plan = planOf(
      RealisticBackup(),
      limits: const ImportLimits(lotSize: 30, dailyWrites: 60),
      now: DateTime.utc(2026, 12, 20),
    );
    for (final warning in plan.report.warnings) {
      readable(importWarningMessage(fr, warning, plan));
      readable(importWarningMessage(en, warning, plan));
    }
    expect(plan.report.warnings, containsAll(ImportWarning.values.take(3)));
    expect(
      importWarningMessage(en, ImportWarning.largeImport, plan),
      contains('${plan.daysNeeded}'),
    );
    expect(
      importWarningMessage(fr, ImportWarning.staleFile, plan),
      contains('${plan.report.fileAgeDays}'),
    );
  });

  test('count lines, problem lines and choices read in both languages', () {
    final plan = planOf(RealisticBackup(), decisions: ImportDecisions.none);
    for (final l10n in [fr, en]) {
      importCountLines(l10n, plan.report).forEach(readable);
      importUndecidedLines(l10n, plan.report).forEach(readable);
    }
    expect(importUndecidedLines(fr, plan.report).single, contains('2 groupes'));
    expect(importUndecidedLines(en, plan.report).single, contains('2 groups'));
    final blocked = planOf(
      RealisticBackup(),
      preProblems: const [
        ImportProblem(
          ImportProblemCode.duplicateId,
          ImportCategory.attempts,
          count: 3,
          sample: ['a1'],
        ),
      ],
    );
    // Le séparateur est celui de la langue : espace avant les deux-points en
    // français, aucun en anglais (jamais un « : » français dans un texte
    // anglais). Littéraux attendus, pas recalculés.
    expect(
      importFirstProblemLines(fr, blocked.report).single,
      'Passages : ${importProblemMessage(fr, ImportProblemCode.duplicateId)}'
      ' (3)',
    );
    expect(
      importFirstProblemLines(en, blocked.report).single,
      'Attempts: ${importProblemMessage(en, ImportProblemCode.duplicateId)}'
      ' (3)',
    );
    expect(
      importFirstProblemLines(en, blocked.report).single,
      isNot(contains(' : ')),
    );
  });

  test('the notice for fiches a teacher cannot check, in both languages', () {
    const one = ImportReport(counts: {}, unverifiableStudents: 1);
    const many = ImportReport(counts: {}, unverifiableStudents: 3);
    expect(importUndecidedLines(fr, one).single, contains('1 fiche d’élève'));
    expect(importUndecidedLines(fr, many).single, contains('3 fiches'));
    expect(importUndecidedLines(en, one).single, contains('1 student record'));
    expect(
      importUndecidedLines(en, many).single,
      contains('3 student records'),
    );
    for (final l10n in [fr, en]) {
      importUndecidedLines(l10n, many).forEach(readable);
    }
    expect(importUndecidedLines(fr, const ImportReport(counts: {})), isEmpty);
  });

  test('the restore notice and the plurals', () {
    const report = ImportReport(counts: {}, restoredStudents: 1);
    expect(importUndecidedLines(fr, report).single, contains('1 élève'));
    const many = ImportReport(
      counts: {},
      restoredStudents: 3,
      undecidedSessions: ['a'],
      undecidedStudents: [StudentId('s')],
    );
    expect(importUndecidedLines(en, many), hasLength(3));
  });

  test('no first name is ever part of a report text', () {
    final backup = RealisticBackup();
    final plan = planOf(backup, decisions: ImportDecisions.none);
    final text = [
      ...importCountLines(fr, plan.report),
      ...importUndecidedLines(fr, plan.report),
      ...importFirstProblemLines(fr, plan.report),
    ].join(' ');
    for (final student in backup.snapshot.students) {
      expect(text, isNot(contains(student.firstName)));
    }
  });
}
