import 'dart:async';

import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/app/auth/local_data_guard.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/features/delete_account/domain/account_deletion.dart';
import 'package:billard_cfa/features/delete_account/domain/delete_own_account.dart';
import 'package:billard_cfa/features/manage_settings/domain/reload_rules.dart';
import 'package:billard_cfa/features/select_club/domain/choose_club.dart';
import 'package:billard_cfa/features/select_club/domain/resolve_active_club.dart';
import 'package:billard_cfa/features/sign_in/domain/pending_invitations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Issue d'une demande de déconnexion.
enum SignOutResult {
  /// Déconnecté ; le cache local est vidé.
  signedOut,

  /// Refusée : des écritures faites sans réseau n'ont pas encore été envoyées
  /// et la déconnexion les perdrait. L'utilisateur confirme, puis l'appel est
  /// refait avec `discardUnsent`.
  unsentWrites,

  /// Le service d'authentification a refusé de fermer la session : rien n'a
  /// changé.
  refused,
}

/// Chef d'orchestre de la session (ADR 0024, décision 31).
///
/// Vit dans la couche `app` : il compose l'initialisation de Firebase, les
/// comptes (`entities/account`), les clubs (`entities/membership`) et la
/// sélection du club actif (`features/select_club`), qui ne peuvent pas
/// s'importer entre elles.
///
/// - `unknown` tant que le service d'authentification n'est pas prêt et que la
///   session persistée n'est pas lue (écran de démarrage) ;
/// - `signedOut` sans compte, ou avec une adresse non vérifiée ;
/// - `noClub` sans club actif (aucun club, ou plusieurs à choisir) ;
/// - `ready` avec club et rôle ; le club actif retenu sur l'appareil rouvre
///   l'application **hors ligne** (session persistée du SDK + club retenu) ;
/// - `indisponible` si le service ne démarre pas, ou si les clubs sont
///   illisibles (réseau) sans club retenu ;
/// - `accessDenied` si le serveur refuse la lecture des clubs (règle, index) :
///   pas de « Réessayer », seulement la déconnexion.
///
/// Un seul exemplaire pour toute l'application : c'est lui que le routeur
/// écoute et qui écrit le [SessionScope] lu par les dépôts.
@LazySingleton()
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(
    this._startup,
    this._auth,
    this._memberships,
    this._memory,
    this._chooseClub,
    this._scope,
    this._pending,
    this._issued,
    this._rules,
    this._local,
    this._deleteOwnAccount,
  ) : super(const AuthUnknown());

  final SessionStartup _startup;
  final AuthRepository _auth;
  final MembershipsSource _memberships;
  final ActiveClubMemory _memory;
  final ChooseClub _chooseClub;
  final SessionScope _scope;
  final PendingInvitations _pending;
  final InvitationLog _issued;
  final ReloadRules _rules;
  final LocalDataGuard _local;
  final DeleteOwnAccount _deleteOwnAccount;

  /// Délai au-delà duquel un démarrage resté sans réponse (SDK qui ne
  /// s'initialise pas, première session jamais livrée) mène à `indisponible`
  /// au lieu de laisser l'écran de démarrage pour toujours. Réglable pour les
  /// tests.
  @visibleForTesting
  Duration startupTimeout = const Duration(seconds: 20);

  Timer? _startupDeadline;
  StreamSubscription<Account?>? _accounts;
  Account? _account;
  bool _started = false;

  /// Un compte de plus à traiter rend caduque la résolution précédente.
  int _generation = 0;
  bool _signingOut = false;

  /// L'effacement du cache local, demandé par une déconnexion, n'a pas abouti :
  /// l'état `signedOut` le porte à l'écran de connexion.
  bool _erasurePending = false;

  /// Vrai quand un compte vérifié est connecté (même si ses clubs sont
  /// illisibles) : « Se déconnecter » a alors un sens.
  bool get hasSession => _account != null;

  /// Lance la session (une seule fois par exemplaire).
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _boot(_startup.ready);
  }

  /// « Réessayer » de l'écran « indisponible » : relance l'initialisation si
  /// elle avait échoué, puis relit la session et les clubs.
  Future<void> retry() async {
    _started = true;
    _stopWatching();
    if (state is! AuthUnknown) emit(const AuthUnknown());
    await _boot(_startup.retry());
  }

  /// Relit les clubs du compte connecté (l'invitation a pu être acceptée).
  Future<void> refresh() async {
    final account = _account;
    if (account == null || state is AuthUnknown) return;
    await _resolve(account, ++_generation);
  }

  /// Choisit le club actif. Renvoie `false` si la bascule est refusée (séance
  /// guidée ou saisie ouverte) ; le club actif ne change alors pas.
  Future<bool> chooseClub(ClubMembership club) async {
    final account = _account;
    final current = state;
    final choices = switch (current) {
      AuthNoClub(:final choices) => choices,
      AuthReady(:final choices) => choices,
      _ => null,
    };
    final isAdmin = switch (current) {
      AuthNoClub(:final isAdmin) => isAdmin,
      AuthReady(:final isAdmin) => isAdmin,
      _ => false,
    };
    if (account == null || choices == null) return false;
    try {
      await _chooseClub(
        user: account.id,
        club: club,
        switching: current is AuthReady,
      );
    } on ClubSwitchBlocked {
      return false;
    }
    _generation++;
    await _activate(account, club, choices, isAdmin: isAdmin);
    return true;
  }

  /// Déconnecte : la session du SDK est fermée, puis le club retenu sur
  /// l'appareil est effacé (ADR 0024, décision 22), le **cache local des
  /// données du club** est vidé (C4) et l'état passe à `signedOut`. Si le SDK
  /// refuse de fermer la session, rien ne change : l'utilisateur reste
  /// connecté, dans son club, avec sa mémoire intacte (jamais « session
  /// ouverte mais club oublié »).
  ///
  /// Des écritures hors ligne encore **non envoyées** seraient perdues avec le
  /// cache : sans [discardUnsent], la déconnexion est refusée
  /// ([SignOutResult.unsentWrites]) pour que l'interface le demande.
  Future<SignOutResult> signOut({bool discardUnsent = false}) async {
    if (!discardUnsent && await _local.hasUnsentWrites()) {
      return SignOutResult.unsentWrites;
    }
    final user = _account?.id ?? _scope.id;
    _signingOut = true;
    try {
      await _auth.signOut();
    } on AuthFailure {
      _signingOut = false;
      return SignOutResult.refused;
    }
    await _forgetOnDevice(user);
    return SignOutResult.signedOut;
  }

  /// Ce que la déconnexion et la suppression du compte font sur l'appareil,
  /// une fois la session fermée : oublier le club retenu et le journal des
  /// invitations de [user], vider le cache local, passer à `signedOut`.
  Future<void> _forgetOnDevice(UserId? user) async {
    if (user != null) {
      await _memory.clear(user);
      await _issued.clear(user);
    }
    try {
      await _local.release();
      _erasurePending = false;
    } on Object catch (error, stackTrace) {
      // Cache non vidé (disque, autre onglet) : l'utilisateur est tout de même
      // déconnecté, mais l'échec est **traité**, pas seulement journalisé : le
      // repère « effacement en attente » reste consigné sur l'appareil (il est
      // retenté au démarrage suivant et avant toute lecture d'un compte), et
      // l'écran de connexion le dit avec « Réessayer l'effacement ».
      _erasurePending = true;
      _report(error, stackTrace, 'while clearing the local data cache');
    }
    // Sans attendre le flux (SDK lent) : l'interface ne montre plus de club.
    _generation++;
    _setSignedOut();
    // Web : la page se recharge (instance Firestore terminée) ; ne rend pas la
    // main si elle recharge.
    _signingOut = false;
    await _local.reopen();
  }

  /// Supprime le compte connecté et ses données de club (FB8 partie B,
  /// tranche B2) : le cas d'usage `DeleteOwnAccount` vérifie [password],
  /// contrôle, purge chaque club puis supprime le compte d'authentification.
  ///
  /// - **Supprimé** : la session est fermée par le service ; l'appareil oublie
  ///   ensuite ce que la déconnexion oublie (club retenu, invitations émises,
  ///   cache local), plus le code d'invitation gardé à l'inscription.
  ///   `_signingOut` est levé **avant** : la fin de session qu'émet le service
  ///   n'est pas prise pour une session perdue ailleurs (rechargement).
  /// - **Arrêté après le début de la purge** : les clubs sont relus, la
  ///   session reflète ce qui reste (souvent « Aucun club », où la suppression
  ///   est de nouveau proposée).
  /// - **Refusé**, ou échoué avant toute écriture : rien ne change.
  Future<AccountDeletionResult> deleteAccount(
    String password, {
    void Function(AccountDeletionStep step)? onProgress,
  }) async {
    final account = _account;
    if (account == null) {
      return const AccountDeletionResult.failed(
        AccountDeletionError.unavailable,
      );
    }
    _signingOut = true;
    final AccountDeletionResult result;
    try {
      result = await _deleteOwnAccount(
        user: account.id,
        password: password,
        onProgress: onProgress,
      );
    } on Object {
      _signingOut = false;
      rethrow;
    }
    switch (result) {
      case AccountDeleted():
        // `_forgetOnDevice` baisse `_signingOut` une fois la session oubliée.
        await _pending.clear(account.id);
        await _forgetOnDevice(account.id);
      case AccountDeletionFailed(:final progress)
          when progress != AccountDeletionProgress.nothingDeleted:
        _signingOut = false;
        await refresh();
      case AccountDeletionRefused() || AccountDeletionFailed():
        _signingOut = false;
    }
    return result;
  }

  /// « Réessayer l'effacement » de l'écran de connexion : retente l'effacement
  /// du cache local resté en attente. En cas de nouvel échec, le message reste.
  Future<void> retryErasure() async {
    try {
      final cleared = await _local.settleErasure();
      _erasurePending = false;
      if (state is AuthSignedOut && !isClosed) emit(const AuthSignedOut());
      // Web : la page se recharge (instance Firestore terminée) ; ne rend pas
      // la main si elle recharge.
      if (cleared) await _local.reopen();
    } on Object catch (error, stackTrace) {
      _report(error, stackTrace, 'while retrying the local data erasure');
    }
  }

  /// Retente, au démarrage, un effacement resté en attente : **avant** toute
  /// lecture de compte, donc avant qu'une session (la même ou une autre) ne
  /// touche au cache. Un échec laisse le message à l'écran de connexion ; si un
  /// compte est tout de même connecté, `claim` retente et, en cas d'échec,
  /// l'application est `indisponible` plutôt que de servir le cache.
  Future<void> _settleErasureAtStartup() async {
    try {
      final cleared = await _local.settleErasure();
      _erasurePending = false;
      if (cleared) await _local.reopen();
    } on Object catch (error, stackTrace) {
      _erasurePending = true;
      _report(error, stackTrace, 'while settling the local data erasure');
    }
  }

  void _report(Object error, StackTrace stackTrace, String context) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'auth_cubit',
        context: ErrorDescription(context),
      ),
    );
  }

  Future<void> _boot(Future<bool> ready) async {
    final generation = ++_generation;
    _startupDeadline?.cancel();
    _startupDeadline = Timer(startupTimeout, () {
      // Sans réponse : « indisponible » (avec « Réessayer »). Un compte livré
      // plus tard est tout de même traité (l'abonnement reste ouvert).
      if (!isClosed && state is AuthUnknown) emit(const AuthIndisponible());
    });
    final usable = await ready;
    if (isClosed || generation != _generation) return;
    if (!usable) {
      _startupDeadline?.cancel();
      emit(const AuthIndisponible());
      return;
    }
    await _settleErasureAtStartup();
    if (isClosed || generation != _generation) return;
    _stopWatching();
    _accounts = _auth.watchAccount().listen(
      (account) => unawaited(_onAccount(account)),
      onError: (Object error) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            library: 'auth_cubit',
            context: ErrorDescription('while watching the account'),
          ),
        );
        _startupDeadline?.cancel();
        if (!isClosed) emit(const AuthIndisponible());
      },
    );
  }

  Future<void> _onAccount(Account? account) async {
    _startupDeadline?.cancel();
    final generation = ++_generation;
    if (account == null || !account.emailVerified) {
      final wasSignedIn = _account != null && !_signingOut;
      _setSignedOut();
      // Session perdue ailleurs : si un autre onglet vide le cache, ce
      // onglet-ci a une instance Firestore terminée : on le recharge (sinon
      // la reconnexion n'y trouverait aucun propriétaire, donc aucune remise
      // en service). Un cache qui reste (jeton révoqué) garde ses écritures.
      if (wasSignedIn) unawaited(_reloadIfClearedElsewhere(generation));
      return;
    }
    await _resolve(account, generation);
  }

  Future<void> _reloadIfClearedElsewhere(int generation) async {
    // Une seule défense contre un compte revenu entre-temps : `stop`, que le
    // garde consulte avant et après chaque lecture ; pas de seconde
    // vérification ici.
    final cleared = await _local.clearedElsewhere(
      stop: () => isClosed || generation != _generation,
    );
    if (cleared) await _local.reopen();
  }

  void _setSignedOut() {
    _account = null;
    _scope.signOut();
    _rules.reset();
    if (!isClosed) emit(AuthSignedOut(erasurePending: _erasurePending));
  }

  Future<void> _resolve(Account account, int generation) async {
    try {
      _account = account;
      // Le cache local appartient à UN compte : celui d'un autre est vidé
      // avant toute lecture (un échec lève : `indisponible`, jamais de donnée
      // servie au mauvais compte).
      if (await _local.claim(account.id.value)) {
        // Web : recharge la page (la session persistée la reprend, le cache
        // est alors à ce compte) ; ne rend pas la main si elle recharge.
        await _local.reopen();
      }
      if (isClosed || generation != _generation) return;
      _scope.signIn(account.id);
      List<ClubMembership>? memberships;
      var isAdmin = false;
      try {
        memberships = await _memberships.membershipsOf(account.id);
        isAdmin = await _memberships.isAdmin(account.id);
      } on MembershipsUnavailable {
        memberships = null;
      } on MembershipsDenied catch (denied) {
        // Refus du serveur (règle, index) : réessayer ou rouvrir sur le club
        // retenu n'y change rien. Cas attendu, donc pas d'erreur Flutter : le
        // journal ne reçoit que le code technique, jamais d'e-mail ni
        // d'identifiant de compte.
        debugPrint('auth_cubit: clubs refused by the server ($denied)');
        if (!isClosed && generation == _generation) {
          _deactivateClub();
          emit(const AuthAccessDenied());
        }
        return;
      }
      final remembered = await _memory.read(account.id);
      final pending = await _pending.read(account.id);
      if (isClosed || generation != _generation) return;
      _scope.signIn(account.id, isAdmin: isAdmin);
      if (memberships == null) {
        // Clubs illisibles (hors ligne) : seul le club retenu sur l'appareil
        // permet d'ouvrir l'application.
        if (remembered == null) {
          _deactivateClub();
          emit(const AuthIndisponible());
        } else {
          await _activate(account, remembered, [remembered]);
        }
        return;
      }
      switch (resolveActiveClub(
        memberships: memberships,
        remembered: remembered,
      )) {
        case NoClub():
          await _memory.clear(account.id);
          if (isClosed || generation != _generation) return;
          _deactivateClub();
          emit(
            AuthNoClub(
              account: account,
              choices: const [],
              isAdmin: isAdmin,
              pendingInvitation: pending,
            ),
          );
        case MustChooseClub():
          _deactivateClub();
          emit(
            AuthNoClub(
              account: account,
              choices: memberships,
              isAdmin: isAdmin,
              pendingInvitation: pending,
            ),
          );
        case ChosenClub(:final club):
          if (remembered != club) await _memory.write(account.id, club);
          if (isClosed || generation != _generation) return;
          await _activate(account, club, memberships, isAdmin: isAdmin);
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'auth_cubit',
          context: ErrorDescription('while resolving the active club'),
        ),
      );
      if (!isClosed && generation == _generation) {
        _deactivateClub();
        emit(const AuthIndisponible());
      }
    }
  }

  /// Retire le club actif et les règles de ce club.
  void _deactivateClub() {
    _scope.deactivateClub();
    _rules.reset();
  }

  /// Active [club] : la portée d'abord, puis ses réglages (un document par
  /// club, illisible avant), **avant** d'émettre `ready` : les écrans lisent
  /// les règles du club, pas celles du précédent ni les valeurs par défaut.
  Future<void> _activate(
    Account account,
    ClubMembership club,
    List<ClubMembership> choices, {
    bool isAdmin = false,
  }) async {
    final generation = _generation;
    _scope.activate(
      club.clubId,
      club.role,
      groupIds: club.groupIds,
      studentIds: club.studentIds,
    );
    await _rules(isCurrent: () => !isClosed && generation == _generation);
    // Une résolution plus récente (autre compte, déconnexion) a repris la main.
    if (isClosed || generation != _generation) return;
    emit(
      AuthReady(
        account: account,
        club: club,
        choices: choices,
        isAdmin: isAdmin,
      ),
    );
  }

  @override
  @disposeMethod
  Future<void> close() async {
    _startupDeadline?.cancel();
    _stopWatching();
    await super.close();
  }

  /// Arrête d'écouter les comptes. L'annulation n'est pas attendue : elle ne
  /// se termine pas dans la zone simulée des tests de widgets, et rien ne
  /// dépend de sa fin.
  void _stopWatching() {
    unawaited(_accounts?.cancel());
    _accounts = null;
  }
}
