import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/ui/failure_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _genericEn = 'Something went wrong. Check the data and try again.';
const _genericFr =
    'Une erreur est survenue. Vérifiez les données et réessayez.';

/// Attentes littérales (anglais, français) de chaque code : écrites en dur,
/// jamais relues depuis les ARB, pour qu'une inversion de messages échoue.
const _expected = <InvariantCode, (String, String)>{
  InvariantCode.blankName: (
    'The first name is required.',
    'Le prénom est obligatoire.',
  ),
  InvariantCode.nameRequired: (
    'A name is required.',
    'Un nom est obligatoire.',
  ),
  InvariantCode.nameTooLong: (
    'This name is too long.',
    'Ce nom est trop long.',
  ),
  InvariantCode.invalidInvitation: (_genericEn, _genericFr),
  InvariantCode.actionNotAllowed: (
    'Your role does not allow this action.',
    'Votre rôle ne permet pas cette action.',
  ),
  InvariantCode.ageConfirmationRequired: (
    'Confirm that this student is 15 or older, or invite a parent instead.',
    'Confirmez que cet élève a 15 ans ou plus, ou invitez plutôt un parent.',
  ),
  InvariantCode.studentChoiceRequired: (
    'Choose the student first.',
    'Choisissez d’abord l’élève.',
  ),
  InvariantCode.passesLimitReached: (
    'At most two passes per exercise and per session.',
    'Deux passages au plus par exercice et par séance.',
  ),
  InvariantCode.studentNotPresent: (
    'This student is not present at the session.',
    'Cet élève n’est pas présent à la séance.',
  ),
  InvariantCode.studentNotInGroup: (
    'This student is not a member of the group on that date.',
    'Cet élève n’est pas membre du groupe à cette date.',
  ),
  InvariantCode.pottedExceedsTotal: (
    'Balls potted cannot exceed the attempts.',
    'Les billes empochées ne peuvent pas dépasser les tentatives.',
  ),
  InvariantCode.totalOutOfRange: (
    'The number of attempts must be between 1 and 16.',
    'Le nombre de tentatives doit être compris entre 1 et 16.',
  ),
  InvariantCode.totalBelowSheet: (
    'The attempts cannot be fewer than the exercise sheet requires.',
    'Les tentatives ne peuvent pas être inférieures à celles de la fiche.',
  ),
  InvariantCode.negativePotted: (
    'Balls potted cannot be negative.',
    'Le nombre de billes empochées ne peut pas être négatif.',
  ),
  InvariantCode.audienceHistoryTooLong: (
    'The audience history is limited to 10 entries.',
    'L’historique de public est limité à 10 entrées.',
  ),
  InvariantCode.audienceUnchanged: (
    'The student already follows this audience.',
    'L’élève suit déjà ce public.',
  ),
  InvariantCode.audienceChangeNotChronological: (
    'The effective date must be after the last audience change.',
    'La date d’effet doit être postérieure au dernier changement de public.',
  ),
  InvariantCode.scoreOutOfRange: (
    'Each criterion is scored from 1 to 4.',
    'Chaque critère se note de 1 à 4.',
  ),
  InvariantCode.dateInFuture: (
    'The date cannot be in the future.',
    'La date ne peut pas être dans le futur.',
  ),
  InvariantCode.commentTooLong: (
    'The comment is limited to 500 characters.',
    'Le commentaire est limité à 500 caractères.',
  ),
  InvariantCode.nothingToTeach: (
    'All students have completed level 1: there is nothing left to teach.',
    'Tous les élèves ont terminé le niveau 1 : il n’y a plus rien à enseigner.',
  ),
  InvariantCode.noStudents: (
    'Select at least one student.',
    'Sélectionnez au moins un élève.',
  ),
  InvariantCode.seasonOutsidePeriod: (
    'This date is outside the season.',
    'Cette date est en dehors de la saison.',
  ),
  InvariantCode.backupUnreadable: (
    'This file is not a readable backup.',
    'Ce fichier n’est pas une sauvegarde lisible.',
  ),
  InvariantCode.backupVersionUnsupported: (
    'This backup comes from a newer version of the app.',
    'Cette sauvegarde provient d’une version plus récente de l’application.',
  ),
  InvariantCode.backupInvalid: (
    'This file contains invalid data.',
    'Ce fichier contient des données invalides.',
  ),
  InvariantCode.backupReopensClosedSeason: (
    'This file predates the closing of a season of this club: importing it '
        'would bring erased students back.',
    'Ce fichier date d’avant la clôture d’une saison de ce club : l’importer '
        'rétablirait des élèves effacés.',
  ),
  InvariantCode.backupInconsistent: (
    'This file is inconsistent: missing references or duplicates.',
    'Ce fichier est incohérent : références manquantes ou doublons.',
  ),
  InvariantCode.backupUnknownSheet: (
    'This file refers to a catalogue session that this version of the app '
        'does not know.',
    'Ce fichier désigne une séance du catalogue que cette version de '
        'l’application ne connaît pas.',
  ),
  InvariantCode.blockAlreadyAcquired: (
    'This block is already marked as acquired for this student.',
    'Ce bloc est déjà marqué acquis pour cet élève.',
  ),
  InvariantCode.groupNameTaken: (
    'Another group of this season already has this name.',
    'Un autre groupe de cette saison porte déjà ce nom.',
  ),
  InvariantCode.groupNotEmpty: (
    'This group still has members: move them first.',
    'Ce groupe a encore des élèves : déplacez-les d’abord.',
  ),
  InvariantCode.groupHasRecords: (
    'This group has recorded sessions: it cannot be deleted.',
    'Ce groupe a des séances saisies : il ne peut pas être supprimé.',
  ),
  InvariantCode.groupHasPlanned: (
    'This group has planned sessions: delete them or change their group '
        'first.',
    'Ce groupe a des séances planifiées : supprimez-les ou changez leur '
        'groupe d’abord.',
  ),
  InvariantCode.groupChoiceRequired: (
    'Several groups fit: choose one.',
    'Plusieurs groupes conviennent : choisissez-en un.',
  ),
  InvariantCode.moveBeforeLastPresence: (
    'Choose a date after the student’s last session in the current group.',
    'Choisissez une date postérieure à la dernière séance de l’élève '
        'dans son groupe actuel.',
  ),
  InvariantCode.seasonClosed: (
    'This season is closed: it accepts no new entry.',
    'Cette saison est close : elle n’accepte plus de saisie.',
  ),
  InvariantCode.seasonAlreadyClosed: (
    'This season is already closed.',
    'Cette saison est déjà close.',
  ),
  InvariantCode.unprintableContent: (
    'A session text contains a character the document font cannot draw: '
        'the export is refused rather than printing an empty box.',
    'Un texte de la séance contient un caractère que la police du document '
        'ne sait pas dessiner : l’export est refusé plutôt que d’imprimer un '
        'carré vide.',
  ),
  InvariantCode.alertNotActive: (
    'This alert is no longer active: there is nothing to acknowledge.',
    'Cette alerte n’est plus active : il n’y a rien à acquitter.',
  ),
  InvariantCode.backupUnknownBlock: (
    'The backup refers to a block unknown to the catalogue.',
    'La sauvegarde cite un bloc inconnu du catalogue.',
  ),
  InvariantCode.unknownSheet: (
    'This catalogue session is unknown: choose another one.',
    'Cette séance du catalogue est inconnue : choisissez-en une autre.',
  ),
  InvariantCode.invalidRules: (
    'These settings are not accepted: nothing was saved.',
    "Ces réglages ne sont pas acceptés : rien n'a été enregistré.",
  ),
  InvariantCode.invalidPeriod: (_genericEn, _genericFr),
  InvariantCode.invalidRange: (_genericEn, _genericFr),
  InvariantCode.invalidExerciseRef: (_genericEn, _genericFr),
  InvariantCode.successRateOutOfRange: (_genericEn, _genericFr),
  InvariantCode.invalidPassIndex: (_genericEn, _genericFr),
  InvariantCode.unknownExercise: (_genericEn, _genericFr),
  InvariantCode.unknownBlock: (_genericEn, _genericFr),
  InvariantCode.unknownGroup: (_genericEn, _genericFr),
  InvariantCode.audienceMismatch: (
    'This group is for another audience: use the audience change instead.',
    'Ce groupe est d’un autre public : passez par le changement de public.',
  ),
  InvariantCode.emptyAudienceHistory: (_genericEn, _genericFr),
  InvariantCode.membershipAlreadyOpen: (
    'The student already belongs to this group.',
    'L’élève fait déjà partie de ce groupe.',
  ),
  InvariantCode.membershipNotOpen: (
    'This student does not belong to a group at the moment.',
    'Cet élève n’appartient à aucun groupe en ce moment.',
  ),
  InvariantCode.membershipPeriodInvalid: (_genericEn, _genericFr),
  InvariantCode.recallEqualsMainBlock: (_genericEn, _genericFr),
  InvariantCode.invalidCatalogue: (_genericEn, _genericFr),
  InvariantCode.invalidDiagram: (_genericEn, _genericFr),
  InvariantCode.invalidSheet: (_genericEn, _genericFr),
};

void main() {
  late AppLocalizations en;
  late AppLocalizations fr;

  setUp(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  test('every invariant code has an explicit expectation', () {
    expect(_expected.keys.toSet(), InvariantCode.values.toSet());
  });

  for (final entry in _expected.entries) {
    test('maps ${entry.key.name} to its English and French message', () {
      final failure = InvariantViolation(entry.key);

      expect(failureMessage(en, failure), entry.value.$1);
      expect(failureMessage(fr, failure), entry.value.$2);
    });
  }

  test('maps NotFound to the not found message', () {
    const failure = NotFound('student', 's1');

    expect(failureMessage(en, failure), 'Item not found.');
    expect(failureMessage(fr, failure), 'Élément introuvable.');
  });

  test('maps the failures of the remote service', () {
    expect(
      failureMessage(en, const ServiceFailure(ServiceFailureCode.unavailable)),
      'The service is not responding. Check your connection and try again.',
    );
    expect(
      failureMessage(fr, const ServiceFailure(ServiceFailureCode.unavailable)),
      'Le service ne répond pas. Vérifiez votre connexion puis réessayez.',
    );
    expect(
      failureMessage(en, const ServiceFailure(ServiceFailureCode.denied)),
      'You are not allowed to do this.',
    );
    expect(
      failureMessage(fr, const ServiceFailure(ServiceFailureCode.denied)),
      'Vous n’avez pas le droit de faire cela.',
    );
    expect(
      failureMessage(en, const ServiceFailure(ServiceFailureCode.other)),
      _genericEn,
    );
    expect(
      failureMessage(fr, const ServiceFailure(ServiceFailureCode.other)),
      _genericFr,
    );
  });

  test('only the documented codes fall back to the generic message', () {
    final generic = {
      for (final entry in _expected.entries)
        if (entry.value.$1 == _genericEn) entry.key,
    };

    expect(generic, hasLength(15));
  });
}
