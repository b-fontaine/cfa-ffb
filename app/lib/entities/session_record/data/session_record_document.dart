import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance séance donnée <-> document `clubs/{c}/records/{id}` (liste
/// blanche de `recordShape` + `groupOwned`) : groupe, saison, jour, public,
/// blocs, séance du catalogue, **étiquettes** (liste fermée de codes, ADR
/// 0023, jamais de texte libre), élèves présents (`presentStudentIds`), date de
/// création. Aucun nom d'élève, aucune note : un parent ne lit jamais ce
/// document (il exposerait les camarades présents).
abstract final class SessionRecordDocument {
  /// Champs écrits à chaque sauvegarde. Les listes sont triées : deux
  /// appareils qui écrivent le même contenu écrivent le même document.
  static Fields encode(SessionRecord record) => {
    'groupId': record.groupId.value,
    'seasonId': record.seasonId.value,
    'date': DocumentValues.encodeDate(record.date),
    'audience': record.audience.name,
    'mainBlockId': record.mainBlockId,
    'recallBlockId': record.recallBlockId,
    'sheetId': record.sheetId?.value,
    'tags': encodeTags(record.tags),
    'presentStudentIds': encodePresent(record.present),
  };

  /// Les champs d'une **reprise** : tout sauf les étiquettes (que seul
  /// `setTags` change) ; les présents remplacent ceux enregistrés.
  static Fields encodeResumed(SessionRecord record) =>
      encode(record)..remove('tags');

  static List<String> encodePresent(Set<StudentId> present) =>
      [for (final id in present) id.value]..sort();

  static List<String> encodeTags(Set<SessionTag> tags) =>
      [for (final tag in tags) tag.name]..sort();

  static Fields creationOnly() => {'createdAt': serverTimestamp};

  static SessionRecord decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    final audienceName = values.string('audience');
    final audience = Audience.values.where((a) => a.name == audienceName);
    if (audience.isEmpty) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: unknown audience',
      );
    }
    try {
      return SessionRecord(
        id: SessionId(document.id),
        groupId: GroupId(values.string('groupId')),
        seasonId: SeasonId(values.string('seasonId')),
        date: values.date('date'),
        audience: audience.first,
        present: {
          for (final id in values.list('presentStudentIds'))
            if (id is String) StudentId(id),
        },
        mainBlockId: values.optString('mainBlockId'),
        recallBlockId: values.optString('recallBlockId'),
        sheetId: SheetId.tryParse(values.optString('sheetId')),
        // Donnée durable : un code inconnu est ignoré, jamais bloquant.
        tags: {
          for (final code in values.list('tags'))
            if (code is String) ?SessionTag.tryParse(code),
        },
      );
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: ${violation.code.name}',
      );
    }
  }

  /// Ordre canonique d'une liste : jour, puis identifiant.
  static int compare(SessionRecord a, SessionRecord b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.id.value.compareTo(b.id.value);
  }

  /// Les identifiants d'élèves présents d'un document.
  static List<String> presentOf(StoredDocument document) => [
    for (final id in DocumentValues(
      document.path,
      document.fields,
    ).list('presentStudentIds'))
      if (id is String) id,
  ];
}
