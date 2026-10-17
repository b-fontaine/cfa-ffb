import 'package:billard_cfa/entities/club/domain/club.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Port d'accès aux clubs (implémenté dans la couche data).
///
/// Les droits sont ceux de `firestore.rules` : l'administrateur liste, crée et
/// supprime ; le directeur renomme son club ; tout membre lit le sien. Les
/// échecs du service lèvent `ServiceFailure`.
abstract interface class ClubRepository {
  /// Tous les clubs (administrateur).
  Future<List<Club>> all();

  Future<Club?> byId(ClubId id);

  /// Crée le club (administrateur).
  Future<void> create(Club club);

  /// Change le nom du club (directeur ou administrateur).
  Future<void> rename(ClubId id, String name);
}
