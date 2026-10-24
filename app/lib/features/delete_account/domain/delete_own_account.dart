import 'dart:async';

import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_repository.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/member_repository.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/remove_own_markers.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';
import 'package:billard_cfa/shared/lib/send_status.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : le compte connecté **supprime son compte** et ses données de
/// club (FB8 partie B, tranche B2 ; ADR 0025 décision 7(e) ; décisions D1 et
/// D4 du 2026-10-24). Les fiches d'élèves, leurs résultats et les séances
/// restent au club : ils appartiennent au club, pas au compte.
///
/// **Ordre sûr**, et pourquoi :
///
/// 1. **Envois en attente** : refus s'il en reste. Une écriture faite hors
///    ligne partirait après le retrait du `member` et serait refusée par les
///    règles (donc perdue), ou viderait la file au mauvais moment.
/// 2. **Réauthentification** (`AuthRepository.reauthenticate`) **avant toute
///    écriture** : un mot de passe faux ou l'absence de réseau ne laissent
///    rien de supprimé, et Firebase exige une connexion récente pour
///    supprimer un compte (`requires-recent-login`).
/// 3. **Contrôles** (lectures seules) : un administrateur est refusé (il se
///    supprime en console) ; le **dernier directeur** d'un club aussi
///    (décision D1 : garde de l'application, `MemberRepository.membersOf`, une
///    règle ne pouvant pas compter les membres). Puis **tous les `members`
///    du compte, lus au serveur** (`MembershipsSource.ownMembers`), y compris
///    dans un club supprimé ou sans nom : ce sont eux qu'on quitte.
/// 4. **Pour chaque club**, tant que le compte en est membre (les règles ne
///    lui permettent ces écritures qu'à ce titre) : révocation de **ses
///    invitations inutilisées**, lues au serveur (émises depuis n'importe
///    quel appareil ; `InvitationRepository.unusedIssuedBy`), suppression de
///    **ses marqueurs**, lus au serveur (B1), puis de **son `member` en
///    dernier**. Chaque écriture attend l'accusé du serveur (au plus
///    [ackTimeout]) : sans lui, on s'arrête. Une lecture au serveur
///    impossible (hors ligne) arrête aussi : jamais une liste vide venue du
///    cache ne fait passer au `member`.
/// 5. **Suppression du compte d'authentification**, en tout dernier : tant
///    qu'il existe, le titulaire peut reprendre ; supprimé d'abord, il ne
///    pourrait plus rien effacer de ses données de club.
///
/// **Issues** : tout échec (`AuthFailure`, `Failure` du service ou du
/// stockage local, délai d'accusé dépassé) devient une issue
/// [AccountDeletionResult] avec ce qui était déjà fait ; aucun n'est relancé.
///
/// **Interruptions** : chaque étape est rejouable. Rejouer relit les
/// `members` du compte (ceux qu'il a quittés n'y sont plus), relit ses
/// marqueurs et ses invitations inutilisées (celles qui restent). Si la purge
/// est faite mais que le compte n'a pas pu être supprimé, le compte reste
/// **sans club** : l'écran « Aucun club » propose de nouveau la suppression.
///
/// Limites connues (déclarées dans l'ADR 0024, notes FB8b) : un **directeur
/// rétrogradé** en enseignant ne peut plus lister ses anciens marqueurs
/// d'opération (règles) : ils restent jusqu'au filet de 90 jours (B5) ; le
/// dernier directeur d'un club **supprimé ou sans nom** n'est pas contrôlé
/// (aucun club à garder) ; deux directeurs qui se suppriment en même temps
/// peuvent laisser un club sans directeur (filet : l'administrateur en
/// invite un) ; une écriture partie après l'accusé attendu en vain reste
/// dans la file du SDK et partira à la reconnexion (rejouer la suppression
/// reprend où elle en est).
@injectable
class DeleteOwnAccount {
  DeleteOwnAccount(
    AuthRepository auth,
    MembershipsSource memberships,
    MemberRepository members,
    RemoveOwnMarkers removeOwnMarkers,
    InvitationRepository invitations,
    SendStatus sends,
  ) : this.withTimeout(
        auth,
        memberships,
        members,
        removeOwnMarkers,
        invitations,
        sends,
      );

  /// Délai d'accusé réglable (les tests le raccourcissent) : un constructeur
  /// à part, pour que l'injection n'ait que le principal à résoudre.
  DeleteOwnAccount.withTimeout(
    this._auth,
    this._memberships,
    this._members,
    this._removeOwnMarkers,
    this._invitations,
    this._sends, {
    this.ackTimeout = const Duration(seconds: 30),
  });

  final AuthRepository _auth;
  final MembershipsSource _memberships;
  final MemberRepository _members;
  final RemoveOwnMarkers _removeOwnMarkers;
  final InvitationRepository _invitations;
  final SendStatus _sends;

  /// Combien de temps attendre l'accusé du serveur pour une écriture (révoquer
  /// une invitation, retirer son `member`).
  final Duration ackTimeout;

  /// Supprime le compte [user] (le compte connecté) après avoir vérifié
  /// [password] ; [onProgress] reçoit chaque étape.
  Future<AccountDeletionResult> call({
    required UserId user,
    required String password,
    void Function(AccountDeletionStep step)? onProgress,
  }) async {
    final report = onProgress ?? (_) {};
    try {
      if (await _sends.hasUnsentWrites()) {
        return const AccountDeletionResult.refused(
          AccountDeletionRefusal.unsentWrites,
        );
      }
    } on Failure {
      // Suivi des envois illisible : rien n'est encore écrit.
      return const AccountDeletionResult.failed(
        AccountDeletionError.unavailable,
      );
    }
    report(const AccountDeletionStep.checkingIdentity());
    try {
      await _auth.reauthenticate(password);
    } on AuthFailure catch (failure) {
      return AccountDeletionResult.failed(_errorOf(failure.code));
    } on Failure catch (failure) {
      return AccountDeletionResult.failed(_failureError(failure));
    }

    final List<_Leaving> leaving;
    try {
      if (await _memberships.isAdmin(user)) {
        return const AccountDeletionResult.refused(
          AccountDeletionRefusal.administrator,
        );
      }
      final clubs = await _memberships.membershipsOf(user);
      for (final club in clubs) {
        if (club.role != Role.director) continue;
        final members = await _members.membersOf(club.clubId);
        final successor = members.any(
          (member) => member.role == Role.director && member.uid != user,
        );
        if (!successor) {
          return AccountDeletionResult.refused(
            AccountDeletionRefusal.lastDirector,
            clubName: club.clubName,
          );
        }
      }
      leaving = _leavingOrder(clubs, await _memberships.ownMembers(user));
    } on MembershipsUnavailable {
      return const AccountDeletionResult.failed(AccountDeletionError.network);
    } on MembershipsDenied {
      return const AccountDeletionResult.failed(
        AccountDeletionError.unavailable,
      );
    } on Failure catch (failure) {
      return AccountDeletionResult.failed(_failureError(failure));
    }

    for (final (index, club) in leaving.indexed) {
      report(
        AccountDeletionStep.leavingClub(
          clubName: club.name,
          index: index + 1,
          count: leaving.length,
        ),
      );
      try {
        await _leave(user, club);
      } on Failure catch (failure) {
        return AccountDeletionResult.failed(
          _failureError(failure),
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        );
      } on TimeoutException {
        return const AccountDeletionResult.failed(
          AccountDeletionError.network,
          progress: AccountDeletionProgress.clubDataPartlyRemoved,
        );
      }
    }

    final progress = leaving.isEmpty
        ? AccountDeletionProgress.nothingDeleted
        : AccountDeletionProgress.clubDataRemoved;
    report(const AccountDeletionStep.removingAccount());
    try {
      await _auth.deleteAccount();
    } on AuthFailure catch (failure) {
      return AccountDeletionResult.failed(
        _errorOf(failure.code),
        progress: progress,
      );
    } on Failure catch (failure) {
      return AccountDeletionResult.failed(
        _failureError(failure),
        progress: progress,
      );
    }
    return const AccountDeletionResult.deleted();
  }

  /// Les clubs à quitter : **chaque `member` du compte lu au serveur**
  /// ([owned]), dans l'ordre des clubs nommés ([named], pour l'avancement),
  /// puis ceux d'un club supprimé ou sans nom (aucun nom à montrer). Un club
  /// nommé dont le `member` n'existe plus au serveur n'est pas repris.
  static List<_Leaving> _leavingOrder(
    List<ClubMembership> named,
    List<OwnMember> owned,
  ) {
    final roles = {for (final member in owned) member.clubId: member.role};
    return [
      for (final club in named)
        if (roles.containsKey(club.clubId))
          (clubId: club.clubId, role: roles[club.clubId], name: club.clubName),
      for (final member in owned)
        if (!named.any((club) => club.clubId == member.clubId))
          (clubId: member.clubId, role: member.role, name: null),
    ];
  }

  /// Quitte [club], tant que le compte en est membre : ses invitations
  /// **inutilisées** (lues au serveur, émises depuis n'importe quel
  /// appareil), ses marqueurs (lus au serveur), puis son `member`.
  Future<void> _leave(UserId user, _Leaving club) async {
    final role = club.role;
    if (role != null && role.invitableRoles.isNotEmpty) {
      for (final code in await _invitations.unusedIssuedBy(user, club.clubId)) {
        await _invitations.revoke(code).timeout(ackTimeout);
      }
    }
    if (role != null) await _removeOwnMarkers(club.clubId, role);
    await _members.remove(club.clubId, user).timeout(ackTimeout);
  }

  /// Un échec du service ou du stockage local : `network` s'il est
  /// injoignable, `unavailable` sinon (refus, erreur inattendue).
  static AccountDeletionError _failureError(Failure failure) =>
      failure is ServiceFailure &&
          failure.code == ServiceFailureCode.unavailable
      ? AccountDeletionError.network
      : AccountDeletionError.unavailable;

  static AccountDeletionError _errorOf(AuthFailureCode code) => switch (code) {
    AuthFailureCode.invalidCredentials => AccountDeletionError.wrongPassword,
    AuthFailureCode.recentLoginRequired =>
      AccountDeletionError.passwordCheckExpired,
    AuthFailureCode.network => AccountDeletionError.network,
    AuthFailureCode.tooManyRequests => AccountDeletionError.tooManyRequests,
    AuthFailureCode.emailNotVerified ||
    AuthFailureCode.invalidEmail ||
    AuthFailureCode.weakPassword ||
    AuthFailureCode.invalidInvitationCode ||
    AuthFailureCode.registrationFailed ||
    AuthFailureCode.unavailable => AccountDeletionError.unavailable,
  };
}

/// Un club à quitter : son identifiant, le rôle du compte (`null` s'il est
/// illisible : seul le `member` est retiré) et son nom (`null` pour un club
/// supprimé ou sans nom).
typedef _Leaving = ({ClubId clubId, Role? role, String? name});
