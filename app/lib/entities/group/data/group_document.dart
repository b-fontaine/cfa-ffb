import 'package:billard_cfa/entities/group/domain/group.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance groupe <-> documents `clubs/{c}/groups/{g}` (nom, saison,
/// public) et `clubs/{c}/memberships/{studentId_from}` (une appartenance
/// datée par document, ADR 0024 décisions 14 et 15).
///
/// `teacherUids` appartient au directeur (FB3, affectation des enseignants) :
/// un groupe qui existe n'est **mis à jour** que sur ses champs propres, jamais
/// remplacé ; `teacherUids` n'est écrit (vide) qu'à la création, car les règles
/// l'exigent.
abstract final class GroupDocument {
  static Fields encode(Group group) => {
    'seasonId': group.seasonId.value,
    'name': group.name,
    'audience': group.audience.name,
  };

  static Fields creationOnly() => {'teacherUids': <String>[]};

  /// Les champs d'une appartenance : le groupe, la saison et l'élève sont
  /// dénormalisés (une règle ne parcourt pas de liste), `to` absent tant
  /// qu'elle est ouverte.
  static Fields encodeMembership(Group group, Membership membership) =>
      encodeMembershipOf(group.id, group.seasonId, membership);

  /// Comme [encodeMembership], sans le groupe entier (l'import, FB7).
  static Fields encodeMembershipOf(
    GroupId group,
    SeasonId season,
    Membership membership,
  ) => {
    'groupId': group.value,
    'seasonId': season.value,
    'studentId': membership.studentId.value,
    'from': DocumentValues.encodeDate(membership.from),
    'to': membership.to == null
        ? null
        : DocumentValues.encodeDate(membership.to!),
  };

  /// Le groupe d'un document et de ses appartenances (déjà lues).
  static Group decode(
    StoredDocument document,
    List<StoredDocument> memberships,
  ) {
    final values = DocumentValues(document.path, document.fields);
    final audienceName = values.optString('audience');
    final audience = Audience.values.where((a) => a.name == audienceName);
    if (audience.isEmpty) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: audience',
      );
    }
    try {
      return Group(
        id: GroupId(document.id),
        seasonId: SeasonId(values.string('seasonId')),
        name: values.string('name'),
        audience: audience.first,
        memberships: [
          for (final doc in [...memberships]..sort(_byId))
            _decodeMembership(doc),
        ],
      );
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: ${violation.code.name}',
      );
    }
  }

  /// Ordre canonique des appartenances : par identifiant (élève, puis début).
  static int _byId(StoredDocument a, StoredDocument b) => a.id.compareTo(b.id);

  static Membership _decodeMembership(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    return Membership(
      studentId: StudentId(values.string('studentId')),
      from: values.date('from'),
      to: values.optDate('to'),
    );
  }
}
