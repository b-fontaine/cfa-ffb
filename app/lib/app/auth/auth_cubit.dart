import 'dart:async';

import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/domain/account.dart';
import 'package:billard_cfa/entities/account/domain/auth_failure.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/invitation/domain/invitation_log.dart';
import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/features/select_club/domain/choose_club.dart';
import 'package:billard_cfa/features/select_club/domain/resolve_active_club.dart';
import 'package:billard_cfa/features/sign_in/domain/pending_invitations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

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
  ) : super(const AuthUnknown());

  final SessionStartup _startup;
  final AuthRepository _auth;
  final MembershipsSource _memberships;
  final ActiveClubMemory _memory;
  final ChooseClub _chooseClub;
  final SessionScope _scope;
  final PendingInvitations _pending;
  final InvitationLog _issued;

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
    _activate(account, club, choices, isAdmin: isAdmin);
    return true;
  }

  /// Déconnecte : la session du SDK est fermée, puis le club retenu sur
  /// l'appareil est effacé (ADR 0024, décision 22) et l'état passe à
  /// `signedOut`. Si le SDK refuse de fermer la session, rien ne change :
  /// l'utilisateur reste connecté, dans son club, avec sa mémoire intacte
  /// (jamais « session ouverte mais club oublié »).
  Future<void> signOut() async {
    final user = _account?.id ?? _scope.id;
    try {
      await _auth.signOut();
    } on AuthFailure {
      return;
    }
    if (user != null) {
      await _memory.clear(user);
      await _issued.clear(user);
    }
    // Sans attendre le flux (SDK lent) : l'interface ne montre plus de club.
    _generation++;
    _setSignedOut();
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
      _setSignedOut();
      return;
    }
    await _resolve(account, generation);
  }

  void _setSignedOut() {
    _account = null;
    _scope.signOut();
    if (!isClosed) emit(const AuthSignedOut());
  }

  Future<void> _resolve(Account account, int generation) async {
    try {
      _account = account;
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
          _scope.deactivateClub();
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
          _scope.deactivateClub();
          emit(const AuthIndisponible());
        } else {
          _activate(account, remembered, [remembered]);
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
          _scope.deactivateClub();
          emit(
            AuthNoClub(
              account: account,
              choices: const [],
              isAdmin: isAdmin,
              pendingInvitation: pending,
            ),
          );
        case MustChooseClub():
          _scope.deactivateClub();
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
          _activate(account, club, memberships, isAdmin: isAdmin);
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
        _scope.deactivateClub();
        emit(const AuthIndisponible());
      }
    }
  }

  void _activate(
    Account account,
    ClubMembership club,
    List<ClubMembership> choices, {
    bool isAdmin = false,
  }) {
    _scope.activate(
      club.clubId,
      club.role,
      groupIds: club.groupIds,
      studentIds: club.studentIds,
    );
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
