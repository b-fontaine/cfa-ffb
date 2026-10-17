import 'package:billard_cfa/entities/membership/domain/club_membership.dart';

/// Ce que le démarrage conclut des clubs d'un compte.
sealed class ClubResolution {
  const ClubResolution();
}

/// Le compte n'est dans aucun club.
final class NoClub extends ClubResolution {
  const NoClub();
}

/// Le club actif est connu : seul club, ou club retenu sur cet appareil et
/// toujours valable.
final class ChosenClub extends ClubResolution {
  const ChosenClub(this.club);

  final ClubMembership club;
}

/// Plusieurs clubs et aucun retenu : l'utilisateur choisit.
final class MustChooseClub extends ClubResolution {
  const MustChooseClub();
}

/// Décide du club actif (fonction pure).
///
/// 1. aucun club : [NoClub] ;
/// 2. le club retenu sur l'appareil, s'il est encore dans [memberships] (le
///    rôle courant l'emporte sur celui qui avait été retenu) : [ChosenClub] ;
/// 3. un seul club : [ChosenClub] ;
/// 4. sinon : [MustChooseClub].
ClubResolution resolveActiveClub({
  required List<ClubMembership> memberships,
  ClubMembership? remembered,
}) {
  if (memberships.isEmpty) return const NoClub();
  if (remembered != null) {
    for (final membership in memberships) {
      if (membership.clubId == remembered.clubId) {
        return ChosenClub(membership);
      }
    }
  }
  if (memberships.length == 1) return ChosenClub(memberships.single);
  return const MustChooseClub();
}
