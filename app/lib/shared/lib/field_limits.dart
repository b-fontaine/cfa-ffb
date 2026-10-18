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
