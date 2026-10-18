import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance fiche élève <-> document `clubs/{c}/students/{id}`.
///
/// C'est **le même document** que `StoreStudentDirectory` publie à la première
/// invitation (prénom, public, groupes courants, `createdAt`) : FB4 le complète
/// (historique du public) sans le recréer, et n'écrit jamais `groupIds` ni
/// `createdAt` sur une fiche qui existe (ils sont tenus par les groupes).
/// Champs : liste blanche de `firestore.rules` (`studentShape`) ; pas de nom de
/// famille, pas d'âge, pas de texte libre.
abstract final class StudentDocument {
  /// Champs écrits à chaque sauvegarde (création ou mise à jour).
  static Fields encode(Student student) => {
    'firstName': student.firstName,
    'audience': student.currentAudience.name,
    'audienceHistory': [
      for (final change in student.audienceHistory)
        {
          'audience': change.audience.name,
          'effectiveFrom': DocumentValues.encodeDate(change.effectiveFrom),
        },
    ],
  };

  /// Champs ajoutés à la **création** seulement : la date du serveur. Les
  /// groupes courants ne sont jamais écrits ici (les appartenances les posent ;
  /// la fiche part avec `ArrayUnion([])`, qui crée la liste vide sans jamais
  /// remplacer une liste existante).
  static Fields creationOnly() => {'createdAt': serverTimestamp};

  /// La fiche d'un document. Une fiche publiée par FB3 n'a pas d'historique :
  /// il vaut alors une inscription au public courant à la date de création.
  static Student decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    final history = [
      for (final raw in values.list('audienceHistory'))
        _change(raw, document.path),
    ];
    final firstName = values.string('firstName');
    final fallback = history.isNotEmpty
        ? history
        : [
            AudienceChange(
              audience: _audience(values.optString('audience'), document.path),
              effectiveFrom:
                  values.optDate('createdAt') ??
                  DateTime.fromMillisecondsSinceEpoch(0),
            ),
          ];
    try {
      return Student(
        id: StudentId(document.id),
        firstName: firstName,
        audienceHistory: fallback,
      );
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: ${violation.code.name}',
      );
    }
  }

  /// Ordre canonique d'une liste : inscription, puis identifiant (Firestore ne
  /// garde pas l'ordre de première sauvegarde que donne la mémoire).
  static int compare(Student a, Student b) {
    final byDate = a.audienceHistory.first.effectiveFrom.compareTo(
      b.audienceHistory.first.effectiveFrom,
    );
    return byDate != 0 ? byDate : a.id.value.compareTo(b.id.value);
  }

  static AudienceChange _change(Object? raw, String path) {
    if (raw is! Map<String, Object?>) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document $path: audienceHistory item is not a map',
      );
    }
    final values = DocumentValues(path, raw);
    return AudienceChange(
      audience: _audience(values.string('audience'), path),
      effectiveFrom: values.date('effectiveFrom'),
    );
  }

  static Audience _audience(String? name, String path) {
    if (name == null) return Audience.children;
    for (final audience in Audience.values) {
      if (audience.name == name) return audience;
    }
    throw ServiceFailure(
      ServiceFailureCode.other,
      'malformed document $path: unknown audience',
    );
  }
}
