// Bornes de longueur des textes que l'application envoie au serveur. Elles
// sont **identiques** à celles de `firestore.rules` (une règle refuse
// au-delà) ; `app/test/unit/shared/field_limits_test.dart` lit le fichier de
// règles et échoue si l'un et l'autre divergent.

/// Nom d'un club.
const int maxClubNameLength = 80;

/// Nom affiché d'un membre à son équipe.
const int maxDisplayNameLength = 40;

/// Prénom d'un élève (ADR 0024, décision 13 : minimisation).
const int maxFirstNameLength = 40;

/// Changements de public dans la fiche d'un élève (`audienceHistoryOk`).
const int maxAudienceHistory = 10;

/// Libellé d'une saison (`seasonShape`).
const int maxSeasonLabelLength = 80;

/// Nom d'un groupe (`groupShape`).
const int maxGroupNameLength = 80;

/// Titre d'une séance planifiée (`sessionShape`).
const int maxSessionTitleLength = 120;

/// Élèves présents à une séance donnée (`recordShape`, `presentStudentIds`).
const int maxPresentStudents = 60;

/// Référence à une séance : identifiant d'une saisie cité par un passage
/// (`sessionId`), séance planifiée citée par une saisie (`plannedSessionId`),
/// dans `attemptShape` et `recordShape`. L'identifiant d'une saisie liée à une
/// séance du catalogue (`sittingId`) la respecte.
const int maxSessionReferenceLength = 64;

/// Identifiant d'un groupe, d'une saison, d'un élève ou d'un bloc cité par une
/// donnée (`groupOwned`, `studentOwned`, `attemptShape` : `size() <= 64`) ;
/// l'import (FB7) refuse un fichier dont un identifiant dépasse la borne.
const int maxIdentifierLength = 64;

/// Numéro d'exercice d'un passage ou d'un acquittement (`presInt(d,
/// 'exerciseNumber', 0, 1000)`).
const int maxExerciseNumber = 1000;

/// Texte ISO 8601 que `DocumentValues.encodeDate` écrit et que `isoText` des
/// règles accepte : l'import vérifie chaque date du fichier avant d'écrire.
final RegExp isoDateText = RegExp(
  '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])'
  r'T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]{1,6})?Z?$',
);
