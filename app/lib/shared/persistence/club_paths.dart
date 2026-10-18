import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Chemins des documents d'**un** club (ADR 0024, décision 14) : `clubId` se
/// lit dans le chemin, `seasonId` n'est jamais un ancêtre. Les noms de
/// collections sont ceux de `firestore.rules` (figés par les tests de règles) ;
/// aucun dépôt ne compose un chemin à la main.
final class ClubPaths {
  const ClubPaths(this.club);

  final ClubId club;

  String get root => 'clubs/${club.value}';

  /// Réglages du club : document unique.
  String get settings => '$root/settings/main';

  String get students => '$root/students';

  String student(StudentId id) => '$students/${id.value}';

  String get groups => '$root/groups';

  String group(GroupId id) => '$groups/${id.value}';

  /// Appartenances datées de **tous** les groupes du club (champ `groupId`).
  String get memberships => '$root/memberships';

  /// Identifiant déterministe d'une appartenance : `groupId_studentId_from`.
  /// Deux appareils qui écrivent la même appartenance écrivent le même
  /// document. Le **groupe** s'ajoute à `studentId_from` de l'ADR 0024 : les
  /// appartenances de tous les groupes partagent une collection du club, et un
  /// élève peut débuter le même jour dans deux groupes. [from] est lu en ISO
  /// 8601 (fuseau conservé, microsecondes comprises).
  String membership(GroupId group, StudentId student, DateTime from) =>
      '$memberships/${group.value}_${student.value}_${from.toIso8601String()}';
}
