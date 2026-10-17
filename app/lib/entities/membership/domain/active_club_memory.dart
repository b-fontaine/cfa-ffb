import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Mémoire locale du club actif, **par compte** (ADR 0024, décisions 22 et
/// 23) : préférence de l'appareil, jamais envoyée au serveur ; effacée à la
/// déconnexion. Un autre utilisateur du même appareil ne lit rien de celui
/// d'avant. Le nom et le rôle sont gardés avec l'identifiant pour que
/// l'application rouvre hors ligne dans le bon club (ADR 0024 décision 31).
///
/// Le domaine ne porte que ce contrat ; le format de persistance vit dans
/// `data` (`KeyValueActiveClubMemory`).
abstract interface class ActiveClubMemory {
  /// Le club retenu pour [user], `null` s'il n'y en a pas ou si la valeur
  /// stockée est illisible (elle est alors ignorée, jamais fatale).
  Future<ClubMembership?> read(UserId user);

  Future<void> write(UserId user, ClubMembership club);

  Future<void> clear(UserId user);
}
