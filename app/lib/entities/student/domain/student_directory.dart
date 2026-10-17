import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';

/// La fiche minimale d'un élève côté serveur : prénom, public et groupes
/// courants (ADR 0024, décisions 13 et 14 : minimisation, aucun nom de famille,
/// âge ni texte libre).
class PublishedStudent {
  const PublishedStudent({
    required this.id,
    required this.firstName,
    required this.audience,
    required this.groupIds,
  });

  final StudentId id;
  final String firstName;
  final Audience audience;
  final List<GroupId> groupIds;
}

/// L'annuaire des fiches d'élèves d'un club côté serveur (`clubs/{c}/students`).
///
/// Une invitation d'élève ou de parent se lie à une fiche **qui existe côté
/// serveur** (les règles le vérifient). Tant que les dépôts de données sont
/// locaux (FB4), `publish` y crée la fiche minimale de l'élève invité, avec
/// l'identifiant local : FB4 et l'import (FB7) retrouvent donc le même
/// document. Une fiche déjà publiée n'est jamais réécrite. Les échecs du
/// service lèvent `ServiceFailure`.
abstract interface class StudentDirectory {
  Future<void> publish(ClubId club, List<PublishedStudent> students);
}
