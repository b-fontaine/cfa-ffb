import 'package:billard_cfa/entities/season/domain/season.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/document_values.dart';

/// Correspondance saison <-> document `clubs/{c}/seasons/{id}` (liste blanche
/// de `seasonShape` : libellé, début, fin, clôture, date de création).
abstract final class SeasonDocument {
  /// Champs écrits à chaque sauvegarde ; `closedOn` est écrit même vide (la
  /// réouverture d'une saison remplace la date de clôture par `null`).
  static Fields encode(Season season) => {
    'label': season.label,
    'startDate': DocumentValues.encodeDate(season.startDate),
    'endDate': DocumentValues.encodeDate(season.endDate),
    'closedOn': season.closedOn == null
        ? null
        : DocumentValues.encodeDate(season.closedOn!),
  };

  /// Champ ajouté à la création seulement : la date du serveur.
  static Fields creationOnly() => {'createdAt': serverTimestamp};

  static Season decode(StoredDocument document) {
    final values = DocumentValues(document.path, document.fields);
    try {
      return Season(
        id: SeasonId(document.id),
        label: values.string('label'),
        startDate: values.date('startDate'),
        endDate: values.date('endDate'),
        closedOn: values.optDate('closedOn'),
      );
    } on InvariantViolation catch (violation) {
      throw ServiceFailure(
        ServiceFailureCode.other,
        'malformed document ${document.path}: ${violation.code.name}',
      );
    }
  }

  /// Ordre canonique d'une liste : début de saison, puis identifiant.
  static int compare(Season a, Season b) {
    final byStart = a.startDate.compareTo(b.startDate);
    return byStart != 0 ? byStart : a.id.value.compareTo(b.id.value);
  }
}
