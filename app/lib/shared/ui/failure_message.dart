import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';

/// Message localisé d'un échec métier (jamais un code technique affiché).
String failureMessage(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      NotFound() => l10n.failNotFound,
      InvariantViolation(:final code) => switch (code) {
        InvariantCode.blankName => l10n.failBlankName,
        InvariantCode.passesLimitReached => l10n.failPassesLimit,
        InvariantCode.studentNotPresent => l10n.failStudentNotPresent,
        InvariantCode.studentNotInGroup => l10n.failStudentNotInGroup,
        InvariantCode.pottedExceedsTotal => l10n.failPottedExceedsTotal,
        InvariantCode.totalOutOfRange => l10n.failTotalOutOfRange,
        InvariantCode.totalBelowSheet => l10n.failTotalBelowSheet,
        InvariantCode.negativePotted => l10n.failNegativePotted,
        InvariantCode.audienceUnchanged => l10n.failAudienceUnchanged,
        InvariantCode.audienceChangeNotChronological =>
          l10n.failAudienceNotChronological,
        InvariantCode.scoreOutOfRange => l10n.failScoreOutOfRange,
        InvariantCode.dateInFuture => l10n.failDateInFuture,
        InvariantCode.commentTooLong => l10n.failCommentTooLong,
        InvariantCode.nothingToTeach => l10n.failNothingToTeach,
        InvariantCode.noStudents => l10n.failNoStudents,
        InvariantCode.seasonOutsidePeriod => l10n.failSeasonOutsidePeriod,
        InvariantCode.backupUnreadable => l10n.failBackupUnreadable,
        InvariantCode.backupVersionUnsupported => l10n.failBackupVersion,
        InvariantCode.backupInvalid => l10n.failBackupInvalid,
        InvariantCode.backupInconsistent => l10n.failBackupInconsistent,
        InvariantCode.backupUnknownSheet => l10n.failBackupUnknownSheet,
        InvariantCode.backupUnknownBlock => l10n.failBackupUnknownBlock,
        InvariantCode.blockAlreadyAcquired => l10n.failBlockAlreadyAcquired,
        InvariantCode.unknownSheet => l10n.failUnknownSheet,
        InvariantCode.invalidPeriod ||
        InvariantCode.invalidRange ||
        InvariantCode.invalidExerciseRef ||
        InvariantCode.successRateOutOfRange ||
        InvariantCode.invalidPassIndex ||
        InvariantCode.unknownExercise ||
        InvariantCode.unknownBlock ||
        InvariantCode.unknownGroup ||
        InvariantCode.audienceMismatch ||
        InvariantCode.emptyAudienceHistory ||
        InvariantCode.membershipAlreadyOpen ||
        InvariantCode.membershipNotOpen ||
        InvariantCode.membershipPeriodInvalid ||
        InvariantCode.recallEqualsMainBlock ||
        InvariantCode.invalidCatalogue ||
        InvariantCode.invalidDiagram ||
        InvariantCode.invalidSheet ||
        InvariantCode.invalidRules => l10n.failGeneric,
      },
    };
