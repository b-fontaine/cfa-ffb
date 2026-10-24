import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_deletion.freezed.dart';

/// L'étape en cours d'une suppression de compte (avancement affiché).
@freezed
sealed class AccountDeletionStep with _$AccountDeletionStep {
  /// Vérification du mot de passe (réauthentification) et contrôles.
  const factory AccountDeletionStep.checkingIdentity() = CheckingIdentity;

  /// Retrait du club [clubName], [index] sur [count] (à partir de 1) ;
  /// [clubName] est `null` pour un club supprimé ou sans nom lisible, dont le
  /// `member` du compte reste à retirer.
  const factory AccountDeletionStep.leavingClub({
    required int index,
    required int count,
    String? clubName,
  }) = LeavingClub;

  /// Suppression du compte d'authentification lui-même.
  const factory AccountDeletionStep.removingAccount() = RemovingAccount;
}

/// Pourquoi la suppression est refusée, **avant toute écriture**.
enum AccountDeletionRefusal {
  /// Des écritures faites sur l'appareil n'ont pas encore été envoyées : elles
  /// seraient perdues, et leur envoi après la suppression du `member` serait
  /// refusé par les règles.
  unsentWrites,

  /// Un compte administrateur ne se supprime pas depuis l'application : il se
  /// supprime en console (`procedure-droits-et-effacement.md`).
  administrator,

  /// Le compte est le dernier directeur d'un club (décision D1 du
  /// 2026-10-24) : l'administrateur doit d'abord créer un successeur.
  lastDirector,
}

/// Pourquoi une suppression a échoué.
enum AccountDeletionError {
  /// Mot de passe incorrect (vérifié avant toute écriture).
  wrongPassword,

  /// La vérification du mot de passe est trop ancienne pour supprimer le
  /// compte d'authentification : la redemander.
  passwordCheckExpired,

  /// Pas de réseau, ou accusé du serveur attendu en vain.
  network,

  /// Trop de tentatives : le service demande d'attendre.
  tooManyRequests,

  /// Toute autre panne du service (refus, erreur inattendue).
  unavailable,
}

/// Ce qui était déjà fait quand la suppression s'est arrêtée.
enum AccountDeletionProgress {
  /// Rien n'a été écrit.
  nothingDeleted,

  /// La purge des données du club a commencé et s'est arrêtée en route : une
  /// partie a pu être supprimée. Rejouer reprend sans danger.
  clubDataPartlyRemoved,

  /// Toutes les données du club sont supprimées ; seul le compte
  /// d'authentification reste. Rejouer ne touche plus aucun club.
  clubDataRemoved,
}

/// Issue d'une suppression de compte.
@freezed
sealed class AccountDeletionResult with _$AccountDeletionResult {
  /// Le compte et ses données de club sont supprimés.
  const factory AccountDeletionResult.deleted() = AccountDeleted;

  /// Refusée avant toute écriture ; [clubName] nomme le club du dernier
  /// directeur.
  const factory AccountDeletionResult.refused(
    AccountDeletionRefusal reason, {
    String? clubName,
  }) = AccountDeletionRefused;

  /// Arrêtée par un échec ; [progress] dit ce qui était déjà fait.
  const factory AccountDeletionResult.failed(
    AccountDeletionError error, {
    @Default(AccountDeletionProgress.nothingDeleted)
    AccountDeletionProgress progress,
  }) = AccountDeletionFailed;
}
