import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';

/// Message localisé d'un échec métier (jamais un code technique affiché).
String failureMessage(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      NotFound() => l10n.failNotFound,
      ServiceFailure(:final code) => switch (code) {
        ServiceFailureCode.unavailable => l10n.failServiceUnavailable,
        ServiceFailureCode.denied => l10n.failServiceDenied,
        ServiceFailureCode.other => l10n.failGeneric,
      },
      InvariantViolation(:final code) => switch (code) {
        InvariantCode.blankName => l10n.failBlankName,
        InvariantCode.nameRequired => l10n.failNameRequired,
        InvariantCode.nameTooLong => l10n.failNameTooLong,
        InvariantCode.actionNotAllowed => l10n.failActionNotAllowed,
        InvariantCode.ageConfirmationRequired =>
          l10n.failAgeConfirmationRequired,
        InvariantCode.studentChoiceRequired => l10n.failStudentChoiceRequired,
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
        InvariantCode.backupReopensClosedSeason =>
          l10n.failBackupReopensClosedSeason,
        InvariantCode.backupUnknownBlock => l10n.failBackupUnknownBlock,
        InvariantCode.blockAlreadyAcquired => l10n.failBlockAlreadyAcquired,
        InvariantCode.alertNotActive => l10n.failAlertNotActive,
        InvariantCode.unknownSheet => l10n.failUnknownSheet,
        InvariantCode.groupNameTaken => l10n.failGroupNameTaken,
        InvariantCode.groupNotEmpty => l10n.failGroupNotEmpty,
        InvariantCode.groupHasRecords => l10n.failGroupHasRecords,
        InvariantCode.groupHasPlanned => l10n.failGroupHasPlanned,
        InvariantCode.groupChoiceRequired => l10n.failGroupChoiceRequired,
        InvariantCode.moveBeforeLastPresence => l10n.failMoveBeforeLastPresence,
        InvariantCode.seasonClosed => l10n.failSeasonClosed,
        InvariantCode.seasonAlreadyClosed => l10n.failSeasonAlreadyClosed,
        InvariantCode.membershipNotOpen => l10n.failMembershipNotOpen,
        InvariantCode.membershipAlreadyOpen => l10n.failMembershipAlreadyOpen,
        InvariantCode.audienceMismatch => l10n.failAudienceMismatch,
        InvariantCode.unprintableContent => l10n.failUnprintableContent,

        InvariantCode.invalidRules => l10n.failInvalidRules,
        InvariantCode.invalidPeriod ||
        InvariantCode.invalidRange ||
        InvariantCode.invalidExerciseRef ||
        InvariantCode.successRateOutOfRange ||
        InvariantCode.invalidPassIndex ||
        InvariantCode.unknownExercise ||
        InvariantCode.unknownBlock ||
        InvariantCode.unknownGroup ||
        InvariantCode.emptyAudienceHistory ||
        InvariantCode.membershipPeriodInvalid ||
        InvariantCode.recallEqualsMainBlock ||
        InvariantCode.invalidCatalogue ||
        InvariantCode.invalidDiagram ||
        InvariantCode.invalidInvitation ||
        InvariantCode.invalidSheet => l10n.failGeneric,
      },
    };
