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
