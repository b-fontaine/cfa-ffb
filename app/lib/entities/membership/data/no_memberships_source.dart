import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/membership/domain/memberships_source.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Appartenances de production **avant le lot FB3** : aucun club n'existe
/// encore côté serveur (les règles refusent tout, ADR 0024 décision 21), donc
/// aucun compte n'a d'appartenance ; l'état « sans club » est alors la vérité,
/// pas un simulacre. FB3 remplace cette classe par la lecture Firestore des
/// documents `members`.
@LazySingleton(as: MembershipsSource, env: [Environment.prod])
class NoMembershipsSource implements MembershipsSource {
  @override
  Future<List<ClubMembership>> membershipsOf(UserId user) async =>
      const <ClubMembership>[];
}
