import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/operations/operation_marker.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance marqueur d'opération <-> document
/// `clubs/{c}/operations/{key}_{uid}` (liste blanche de `operationMarkerShape`
/// dans `firestore.rules`). **Aucune donnée personnelle** : l'empreinte de
/// l'opération, sa nature, l'avancement, le rôle et l'identifiant
/// (pseudonyme) de l'auteur, deux dates du serveur ; pour une clôture, la
/// saison, le jour et deux choix. Aucun identifiant d'élève.
abstract final class OperationMarkerDocument {
  /// Création, dans le premier lot : `done` vaut 1 (règle `done == 1`).
  static Fields create(OperationMarker marker, {required UserId createdBy}) => {
    'operationId': marker.key,
    'kind': marker.kind.name,
    'done': marker.done,
    'stage': marker.stage,
    'role': marker.role.name,
    'createdBy': createdBy.value,
    if (marker.terms case final terms?) ...{
      'seasonId': terms.seasonId.value,
      'closedOn': DocumentValues.encodeDate(terms.closedOn),
      'prepareNext': terms.prepareNext,
      'dropPlanned': terms.dropPlanned,
    },
    'startedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  /// Avancement, dans chaque lot suivant : seuls `done`, `stage` et
  /// `updatedAt` changent, et `done` n'avance que d'un (règle du marqueur).
  static Fields advance(OperationMarker marker) => {
    'done': marker.done,
    'stage': marker.stage,
    'updatedAt': serverTimestamp,
  };

  static OperationMarker decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    final role = Role.tryParse(values.string('role'));
    final kind = OperationKind.tryParse(values.string('kind'));
    if (role == null || kind == null) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: unknown role or kind',
      );
    }
    final seasonId = values.optString('seasonId');
    return OperationMarker(
      key: values.string('operationId'),
      kind: kind,
      done: values.integer('done', fallback: 0),
      stage: values.integer('stage', fallback: 0),
      role: role,
      terms: seasonId == null
          ? null
          : ClosureTerms(
              seasonId: SeasonId(seasonId),
              closedOn: values.date('closedOn'),
              prepareNext: document.fields['prepareNext'] == true,
              dropPlanned: document.fields['dropPlanned'] == true,
            ),
      updatedAt: values.optDate('updatedAt'),
    );
  }
}
