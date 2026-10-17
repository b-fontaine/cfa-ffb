import 'package:billard_cfa/app/auth/auth_cubit.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/membership/data/in_memory_memberships_source.dart';
import 'package:billard_cfa/entities/membership/data/key_value_active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/features/select_club/domain/choose_club.dart';
import 'package:billard_cfa/shared/lib/club_switch_guard.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';

/// Garde de bascule des tests : bloquée à la demande.
class FakeClubSwitchGuard implements ClubSwitchGuard {
  @override
  bool isBlocked = false;
}

/// Un `AuthCubit` assemblé avec des doubles en mémoire, et ces doubles : tout
/// ce qu'il faut pour le tester sans graphe `get_it`.
class AuthRig {
  AuthRig() {
    memory = KeyValueActiveClubMemory(store);
    chooseClub = ChooseClub(memory, guard);
    cubit = AuthCubit(startup, auth, memberships, memory, chooseClub, scope);
  }

  final InMemoryAuthRepository auth = InMemoryAuthRepository();
  final InMemoryMembershipsSource memberships = InMemoryMembershipsSource();
  final InMemoryKeyValueStore store = InMemoryKeyValueStore();
  final InMemorySessionStartup startup = InMemorySessionStartup();
  final FakeClubSwitchGuard guard = FakeClubSwitchGuard();
  final SessionScope scope = SessionScope();
  late final ActiveClubMemory memory;
  late final ChooseClub chooseClub;
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
}
