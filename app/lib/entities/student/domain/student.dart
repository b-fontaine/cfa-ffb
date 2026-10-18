import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/field_limits.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'student.freezed.dart';

/// Entrée de l'historique de public : à partir de [effectiveFrom], l'élève
/// suit les cours du public [audience].
@freezed
abstract class AudienceChange with _$AudienceChange {
  const factory AudienceChange({
    required Audience audience,
    required DateTime effectiveFrom,
  }) = _AudienceChange;
}

/// Un élève. Données minimales (mineurs) : prénom et public `[U]`.
///
/// Le public courant est dérivé de l'historique : celui-ci n'est jamais
/// réécrit, seulement prolongé (`changeAudience`), et le changement est
/// toujours une décision manuelle de l'animateur `[U]`.
@freezed
abstract class Student with _$Student {
  factory Student({
    required StudentId id,
    required String firstName,
    required List<AudienceChange> audienceHistory,
  }) = _Student;

  Student._() {
    if (firstName.trim().isEmpty) {
      throw const InvariantViolation(InvariantCode.blankName);
    }
    // Les règles comptent des caractères (points de code), pas des unités
    // UTF-16.
    if (firstName.runes.length > maxFirstNameLength) {
      throw const InvariantViolation(InvariantCode.nameTooLong);
    }
    if (audienceHistory.length > maxAudienceHistory) {
      throw const InvariantViolation(InvariantCode.audienceHistoryTooLong);
    }
    if (audienceHistory.isEmpty) {
      throw const InvariantViolation(InvariantCode.emptyAudienceHistory);
    }
    final chronological = List.generate(
      audienceHistory.length - 1,
      (index) => audienceHistory[index].effectiveFrom.isBefore(
        audienceHistory[index + 1].effectiveFrom,
      ),
    ).every((ok) => ok);
    if (!chronological) {
      throw const InvariantViolation(
        InvariantCode.audienceChangeNotChronological,
      );
    }
  }

  /// Inscrit un élève dans le public [audience] à partir de [since].
  factory Student.enroll({
    required StudentId id,
    required String firstName,
    required Audience audience,
    required DateTime since,
  }) => Student(
    id: id,
    firstName: firstName,
    audienceHistory: [AudienceChange(audience: audience, effectiveFrom: since)],
  );

  Audience get currentAudience => audienceHistory.last.audience;

  /// Public suivi à la date [date] ; `null` avant la première inscription.
  Audience? audienceAt(DateTime date) {
    Audience? found;
    for (final change in audienceHistory) {
      if (!change.effectiveFrom.isAfter(date)) found = change.audience;
    }
    return found;
  }

  /// R7 : ajoute un changement de public, sans toucher au passé.
  ///
  /// Refusé si le public ne change pas ou si [effectiveFrom] n'est pas
  /// strictement postérieure au dernier changement.
  Student changeAudience(Audience audience, DateTime effectiveFrom) {
    if (audience == currentAudience) {
      throw const InvariantViolation(InvariantCode.audienceUnchanged);
    }
    if (!effectiveFrom.isAfter(audienceHistory.last.effectiveFrom)) {
      throw const InvariantViolation(
        InvariantCode.audienceChangeNotChronological,
      );
    }
    return Student(
      id: id,
      firstName: firstName,
      audienceHistory: [
        ...audienceHistory,
        AudienceChange(audience: audience, effectiveFrom: effectiveFrom),
      ],
    );
  }
}
