part of 'club_import_cubit.dart';

/// Les étapes de l'écran d'import (FB7, partie B), dans l'ordre. Une étape dont
/// il n'y a rien à décider est sautée (`groups`, `loose`, `confirmations`).
enum ClubImportStep {
  file,
  report,
  groups,
  loose,
  confirmations,
  recap,
  running,
  finished,
}

/// Où en est l'exécution quand elle ne court pas ou s'est arrêtée. `null`
/// (dans l'état) : rien d'anormal. Aucune de ces issues n'est une erreur
/// rouge sauf [failed].
enum ClubImportRun {
  /// Les lots s'écrivent.
  running,

  /// L'arrêt est demandé : il se prend entre deux lots.
  cancelling,

  /// Arrêt demandé et pris entre deux lots.
  cancelled,

  /// Le plafond du jour est atteint : reprendre demain.
  paused,

  /// Le réseau a manqué : reprise automatique au retour du réseau.
  interrupted,

  /// Le serveur a refusé un lot (droits) ou une erreur est survenue.
  failed,

  /// Un import de ce fichier est commencé avec d'autres choix.
  planChanged,
}

/// L'état de l'écran d'import. Ne contient **jamais** le texte du fichier ni
/// l'identité du compte : seulement des comptes, des identifiants de groupes et
/// de quoi afficher les choix.
@freezed
abstract class ClubImportState with _$ClubImportState {
  const factory ClubImportState({
    @Default(ClubImportStep.file) ClubImportStep step,

    /// Une lecture ou un calcul est en cours : les commandes sont inertes.
    @Default(false) bool busy,
    @Default(true) bool online,

    /// Le rôle effectif dans le club (jamais un nom ni un identifiant).
    Role? role,

    /// Le rôle peut créer des groupes dans le club (dérivé du domaine, jamais
    /// recalculé par l'écran).
    @Default(false) bool canCreateGroups,

    /// Le plan courant, calculé avant toute écriture.
    ClubImportPlan? plan,
    @Default(ImportDecisions.none) ImportDecisions decisions,

    /// Il y avait des groupes à décider dans le fichier : l'étape reste
    /// affichée une fois les groupes décidés.
    @Default(false) bool groupsNeeded,

    /// Les groupes du club où associer (selon les droits).
    @Default([]) List<ImportTarget> targets,

    /// Échec de lecture du club ou du fichier (réseau, droits).
    Failure? failure,
    ClubImportRun? run,
    @Default(0) int doneLots,
    @Default(0) int totalLots,

    /// Pourquoi l'exécution a échoué (`ClubImportRun.failed`).
    Failure? runFailure,
  }) = _ClubImportState;
}
