import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance séance planifiée <-> document `clubs/{c}/sessions/{id}`
/// (liste blanche de `sessionShape` + `groupOwned` : groupe et saison
/// dénormalisés, titre, jour, public, séance du catalogue, date de création).
abstract final class SessionDocument {
  /// Champs écrits à chaque sauvegarde. [season] est la saison du groupe : les
  /// règles la lisent (`groupOwned`), une séance ne la change jamais.
  static Fields encode(Session session, SeasonId season) => {
    'groupId': session.groupId!.value,
    'seasonId': season.value,
    'title': session.title,
    'date': DocumentValues.encodeDate(session.date),
    'audience': session.audience.name,
    'sheetId': session.sheetId?.value,
  };

  static Fields creationOnly() => {'createdAt': serverTimestamp};

  static Session decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    final audienceName = values.string('audience');
    final audience = Audience.values.where((a) => a.name == audienceName);
    if (audience.isEmpty) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: unknown audience',
      );
    }
    return Session(
      id: document.id,
      title: values.string('title'),
      date: values.date('date'),
      audience: audience.first,
      groupId: GroupId(values.string('groupId')),
      // Donnée durable : un identifiant mal formé est ignoré, jamais bloquant.
      sheetId: SheetId.tryParse(values.optString('sheetId')),
    );
  }

  /// Ordre canonique d'une liste : jour, puis identifiant.
  static int compare(Session a, Session b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }
}
