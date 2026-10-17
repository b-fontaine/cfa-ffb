import 'package:billard_cfa/entities/membership/domain/active_club_memory.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/club_switch_guard.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// La bascule de club est refusée : une séance guidée ou une saisie est
/// ouverte.
class ClubSwitchBlocked implements Exception {
  const ClubSwitchBlocked();

  @override
  String toString() => 'ClubSwitchBlocked()';
}

/// Retient le club actif de `user` sur cet appareil.
///
/// `switching` : un club est déjà actif (bascule) ; la bascule est interdite
/// tant que le `ClubSwitchGuard` la bloque. Le premier choix, sans club actif,
/// n'a rien à perdre et passe toujours.
@injectable
class ChooseClub {
  ChooseClub(this._memory, this._guard);

  final ActiveClubMemory _memory;
  final ClubSwitchGuard _guard;

  Future<void> call({
    required UserId user,
    required ClubMembership club,
    required bool switching,
  }) async {
    if (switching && _guard.isBlocked) throw const ClubSwitchBlocked();
    await _memory.write(user, club);
  }
}
