import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/features/backup_data/domain/club_import/import_report.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';

/// Textes du rapport d'import (FB7), en français et en anglais. Le rapport ne
/// porte que des codes, des catégories et des comptes : rien de nominatif ne
/// passe ici, ni dans un journal.
String importCategoryLabel(AppLocalizations l10n, ImportCategory category) =>
    switch (category) {
      ImportCategory.seasons => l10n.importCategorySeasons,
      ImportCategory.groups => l10n.importCategoryGroups,
      ImportCategory.students => l10n.importCategoryStudents,
      ImportCategory.memberships => l10n.importCategoryMemberships,
      ImportCategory.seasonArchives => l10n.importCategorySeasonArchives,
      ImportCategory.plannedSessions => l10n.importCategoryPlannedSessions,
      ImportCategory.sessionRecords => l10n.importCategorySessionRecords,
      ImportCategory.attempts => l10n.importCategoryAttempts,
      ImportCategory.acquisitions => l10n.importCategoryAcquisitions,
      ImportCategory.assessments => l10n.importCategoryAssessments,
      ImportCategory.acknowledgements => l10n.importCategoryAcknowledgements,
    };

String importProblemMessage(
  AppLocalizations l10n,
  ImportProblemCode code,
) => switch (code) {
  ImportProblemCode.unreadable => l10n.importProblemUnreadable,
  ImportProblemCode.versionUnsupported => l10n.importProblemVersionUnsupported,
  ImportProblemCode.invalid => l10n.importProblemInvalid,
  ImportProblemCode.unknownSheet => l10n.importProblemUnknownSheet,
  ImportProblemCode.unknownBlock => l10n.importProblemUnknownBlock,
  ImportProblemCode.inconsistentCatalogue =>
    l10n.importProblemInconsistentCatalogue,
  ImportProblemCode.duplicateId => l10n.importProblemDuplicateId,
  ImportProblemCode.danglingReference => l10n.importProblemDanglingReference,
  ImportProblemCode.orphanAttempt => l10n.importProblemOrphanAttempt,
  ImportProblemCode.badIdentifier => l10n.importProblemBadIdentifier,
  ImportProblemCode.valueTooLong => l10n.importProblemValueTooLong,
  ImportProblemCode.valueOutOfRange => l10n.importProblemValueOutOfRange,
  ImportProblemCode.badDate => l10n.importProblemBadDate,
  ImportProblemCode.tooManyPresent => l10n.importProblemTooManyPresent(
    maxPresentStudents,
  ),
  ImportProblemCode.reopensClosedSeason =>
    l10n.importProblemReopensClosedSeason,
  ImportProblemCode.targetSeasonClosed => l10n.importProblemTargetSeasonClosed,
  ImportProblemCode.outsideSeason => l10n.importProblemOutsideSeason,
  ImportProblemCode.audienceMismatch => l10n.importProblemAudienceMismatch,
  ImportProblemCode.unknownTargetGroup => l10n.importProblemUnknownTargetGroup,
  ImportProblemCode.mergeNotConfirmed => l10n.importProblemMergeNotConfirmed,
  ImportProblemCode.invalidDecision => l10n.importProblemInvalidDecision,
  ImportProblemCode.studentBeingErased => l10n.importProblemStudentBeingErased,
  ImportProblemCode.planChanged => l10n.importProblemPlanChanged,
  ImportProblemCode.roleDenied => l10n.importProblemRoleDenied,
};

/// Une ligne de problème : le message, la catégorie concernée et le compte.
String importProblemLine(AppLocalizations l10n, ImportProblem problem) {
  final message = importProblemMessage(l10n, problem.code);
  final category = problem.category;
  final text = category == null
      ? message
      : l10n.importProblemInCategory(
          importCategoryLabel(l10n, category),
          message,
        );
  return l10n.importProblemLine(text, problem.count);
}

String importWarningMessage(
  AppLocalizations l10n,
  ImportWarning warning,
  ClubImportPlan plan,
) => switch (warning) {
  ImportWarning.staleFile => l10n.importWarningStaleFile(
    plan.report.fileAgeDays ?? 0,
  ),
  ImportWarning.largeImport => l10n.importWarningLargeImport(plan.daysNeeded),
  ImportWarning.settingsIgnored => l10n.importWarningSettingsIgnored,
  ImportWarning.roleScope => l10n.importWarningRoleScope,
};

String importStatusLabel(AppLocalizations l10n, ImportStatus status) =>
    switch (status) {
      ImportStatus.blocked => l10n.importStatusBlocked,
      ImportStatus.needsDecisions => l10n.importStatusNeedsDecisions,
      ImportStatus.needsConfirmation => l10n.importStatusNeedsConfirmation,
      ImportStatus.alreadyImported => l10n.importStatusAlreadyImported,
      ImportStatus.resumable => l10n.importStatusResumable,
      ImportStatus.ready => l10n.importStatusReady,
    };

/// Une ligne de compteurs par catégorie qui compte quelque chose.
List<String> importCountLines(AppLocalizations l10n, ImportReport report) => [
  for (final entry in report.counts.entries)
    if (entry.value.inFile + entry.value.writes + entry.value.alreadyPresent >
        0)
      l10n.importCountLine(
        importCategoryLabel(l10n, entry.key),
        entry.value.inFile,
        entry.value.writes,
        entry.value.alreadyPresent,
        entry.value.ignored,
      ),
];

/// Les premiers problèmes, au plus [limit] lignes.
List<String> importFirstProblemLines(
  AppLocalizations l10n,
  ImportReport report, {
  int limit = 5,
}) => [
  for (final problem in report.firstProblems(limit))
    importProblemLine(l10n, problem),
];

/// Les choix qui manquent, une ligne par sorte.
List<String> importUndecidedLines(AppLocalizations l10n, ImportReport report) =>
    [
      if (report.undecidedGroups.isNotEmpty)
        l10n.importUndecidedGroups(report.undecidedGroups.length),
      if (report.undecidedSessions.isNotEmpty)
        l10n.importUndecidedSessions(report.undecidedSessions.length),
      if (report.undecidedStudents.isNotEmpty)
        l10n.importUndecidedStudents(report.undecidedStudents.length),
      if (report.restoredStudents > 0)
        l10n.importRestoreNotice(report.restoredStudents),
      if (report.unverifiableStudents > 0)
        l10n.importUnverifiableNotice(report.unverifiableStudents),
    ];
