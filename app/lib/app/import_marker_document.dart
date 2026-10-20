import 'package:billard_cfa/features/backup_data/domain/club_import/import_models.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance marqueur d'import <-> document `clubs/{c}/imports/{fileId}_{uid}`
/// (un marqueur par fichier et par auteur : l'identifiant porte l'uid)
/// (liste blanche de `importMarkerShape`). **Aucune donnée personnelle** :
/// l'empreinte du fichier (SHA-256), celle du plan, des compteurs, le rôle qui
/// a lancé l'import, l'identifiant (pseudonyme) de son auteur et deux dates du
/// serveur. Aucun identifiant d'élève.
abstract final class ImportMarkerDocument {
  /// Création, dans le premier lot : `done` vaut 1 (règle `done == 1`).
  /// [createdBy] est l'identifiant (pseudonyme) de l'auteur : seul lui fait
  /// ensuite avancer le marqueur (règles : l'identifiant porte son `uid`).
  static Fields create(ImportMarker marker, {required UserId createdBy}) => {
    'fileId': marker.fileId,
    'planId': marker.planId,
    'lots': marker.lots,
    'done': marker.done,
    'writes': marker.writes,
    'restored': marker.restored,
    'role': marker.role.name,
    'createdBy': createdBy.value,
    'state': marker.state.name,
    'startedAt': serverTimestamp,
    'updatedAt': serverTimestamp,
  };

  /// Avancement, dans chaque lot suivant : seuls `done`, `state` et
  /// `updatedAt` changent, et `done` n'avance que d'un (règle du marqueur).
  static Fields advance(ImportMarker marker) => {
    'done': marker.done,
    'state': marker.state.name,
    'updatedAt': serverTimestamp,
  };

  static ImportMarker decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    final role = Role.tryParse(values.string('role'));
    if (role == null) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: unknown role',
      );
    }
    return ImportMarker(
      fileId: values.string('fileId'),
      planId: values.string('planId'),
      lots: values.integer('lots', fallback: 0),
      done: values.integer('done', fallback: 0),
      writes: values.integer('writes', fallback: 0),
      restored: values.integer('restored', fallback: 0),
      role: role,
      updatedAt: values.optDate('updatedAt'),
    );
  }
}
