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

  String get seasons => '$root/seasons';

  String season(SeasonId id) => '$seasons/${id.value}';

  /// Séances planifiées (identifiant texte libre : UUID).
  String get sessions => '$root/sessions';

  String session(String id) => '$sessions/$id';

  /// Séances données (`SessionRecord`) : collection `records` des règles.
  String get records => '$root/records';

  String record(SessionId id) => '$records/${id.value}';

  /// Archives agrégées de fin de saison (un document de synthèse par saison et
  /// public, un par exercice).
  String get archives => '$root/archives';

  String archive(String id) => '$archives/$id';

  /// Passages : **un document par passage** (ADR 0024, décision 17).
  String get attempts => '$root/attempts';

  String attempt(AttemptId id) => '$attempts/${id.value}';

  /// Blocs acquis au positionnement.
  String get acquisitions => '$root/acquisitions';

  String acquisition(AcquisitionId id) => '$acquisitions/${id.value}';

  /// Bilans de maturité (réservés aux animateurs).
  String get assessments => '$root/assessments';

  String assessment(AssessmentId id) => '$assessments/${id.value}';

  /// Acquittements d'alertes (« Vu »), partagés par club (réservés aux
  /// animateurs).
  String get acknowledgements => '$root/acknowledgements';

  String acknowledgement(AcknowledgementId id) =>
      '$acknowledgements/${id.value}';
}
