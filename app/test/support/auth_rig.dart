import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/app/auth/local_data_guard.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/invitation/data/key_value_invitation_log.dart';
import 'package:billard_cfa/entities/invitation/data/store_invitation_repository.dart';
import 'package:billard_cfa/entities/membership/data/key_value_active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/member.dart';
import 'package:billard_cfa/entities/membership/domain/member_repository.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/entities/settings/data/in_memory_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/features/delete_account/domain/delete_own_account.dart';
import 'package:billard_cfa/features/manage_settings/domain/reload_rules.dart';
import 'package:billard_cfa/features/select_club/domain/choose_club.dart';
import 'package:billard_cfa/features/sign_in/data/key_value_pending_invitations.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/club_switch_guard.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/lib/operations/in_memory_own_marker_store.dart';
import 'package:billard_cfa/shared/lib/operations/remove_own_markers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:billard_cfa/shared/lib/rules_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/persistence/local_data_cache.dart';
import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:billard_cfa/shared/persistence/send_status.dart';

import 'fixed_clock.dart';
import 'in_memory_memberships_source.dart';

/// Garde de bascule des tests : bloquée à la demande.
class FakeClubSwitchGuard implements ClubSwitchGuard {
  @override
  bool isBlocked = false;
}

/// Les `members` vus par la suppression d'un compte : un club directeur a
/// d'autres directeurs dans [directors] ; retirer le sien retire le club des
/// appartenances (comme le serveur).
class RigMembers implements MemberRepository {
  RigMembers(this._memberships);

  final InMemoryMembershipsSource _memberships;

  /// Les autres directeurs de chaque club.
  final Map<ClubId, List<UserId>> directors = {};

  /// Les retraits demandés (club, compte).
  final List<(ClubId, UserId)> removed = [];

  @override
  Future<List<Member>> membersOf(ClubId club) async => [
    for (final uid in directors[club] ?? const <UserId>[])
      Member(uid: uid, role: Role.director, displayName: uid.value),
  ];

  @override
  Future<void> remove(ClubId club, UserId user) async {
    removed.add((club, user));
    _memberships.revoke(user, club);
  }
}

/// Un `AuthCubit` assemblé avec des doubles en mémoire, et ces doubles : tout
/// ce qu'il faut pour le tester sans graphe `get_it`.
class AuthRig {
  AuthRig({SettingsRepository Function(SessionScope scope)? settings}) {
    rules = RulesStore(RulesConfig());
    reloadRules = ReloadRules(
      settings?.call(scope) ?? InMemorySettingsRepository(),
      rules,
    );
    memory = KeyValueActiveClubMemory(store);
    chooseClub = ChooseClub(memory, guard);
    pending = KeyValuePendingInvitations(store);
    issued = KeyValueInvitationLog(store);
    local = LocalDataGuard.withTiming(
      cache,
      store,
      sends,
      clearedElsewhereWithin: const Duration(milliseconds: 150),
      pollEvery: const Duration(milliseconds: 10),
    );
    members = RigMembers(memberships);
    markers = InMemoryOwnMarkerStore(scope);
    deleteOwnAccount = DeleteOwnAccount.withTimeout(
      auth,
      memberships,
      members,
      RemoveOwnMarkers(markers),
      StoreInvitationRepository(InMemoryDocumentStore(), clock),
      sends,
      ackTimeout: const Duration(milliseconds: 50),
    );
    cubit = AuthCubit(
      startup,
      auth,
      memberships,
      memory,
      chooseClub,
      scope,
      pending,
      issued,
      reloadRules,
      local,
      deleteOwnAccount,
    );
  }

  final InMemoryAuthRepository auth = InMemoryAuthRepository();
  final InMemoryMembershipsSource memberships = InMemoryMembershipsSource();
  final InMemoryKeyValueStore store = InMemoryKeyValueStore();
  final InMemorySessionStartup startup = InMemorySessionStartup();
  final FakeClubSwitchGuard guard = FakeClubSwitchGuard();
  final InMemoryLocalDataCache cache = InMemoryLocalDataCache();
  final SendTracker sends = SendTracker(InMemoryPendingWritesProbe());
  final SessionScope scope = SessionScope();
  late final ActiveClubMemory memory;
  late final ChooseClub chooseClub;
  late final KeyValuePendingInvitations pending;
  late final KeyValueInvitationLog issued;
  late final LocalDataGuard local;
  late final RulesStore rules;
  final FixedClock clock = FixedClock(DateTime(2026, 10, 12, 9, 30));
  late final RigMembers members;
  late final InMemoryOwnMarkerStore markers;
  late final DeleteOwnAccount deleteOwnAccount;
  late final ReloadRules reloadRules;
  late final AuthCubit cubit;
}

/// Appartenances dont la lecture du compte `coach@example.org` attend une
/// réponse manuelle ; les autres comptes sont lus normalement.
class SlowMemberships implements MembershipsSource {
  SlowMemberships(this._slow, this._fast);

  final Future<List<ClubMembership>> _slow;
  final MembershipsSource _fast;

  @override
  Future<List<ClubMembership>> membershipsOf(UserId user) =>
      user.value == 'user-1' ? _slow : _fast.membershipsOf(user);

  @override
  Future<bool> isAdmin(UserId user) => _fast.isAdmin(user);

  @override
  Future<List<OwnMember>> ownMembers(UserId user) => _fast.ownMembers(user);
}
