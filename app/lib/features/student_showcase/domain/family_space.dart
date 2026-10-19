import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'family_space.freezed.dart';

/// Un élève lié au compte : son prénom et son parcours (la vue « à montrer à
/// l'élève », ADR 0014). Rien d'autre : ni alerte, ni bilan, ni assiduité, ni
/// saisie (ADR 0024, décision 26 ; ADR 0025).
@freezed
abstract class FamilyChild with _$FamilyChild {
  const factory FamilyChild({
    required StudentId id,
    required String firstName,
    required StudentShowcase showcase,
  }) = _FamilyChild;
}

/// Une séance planifiée d'un groupe du compte : son titre, son jour, son
/// public et le nom du groupe. Aucune liste de présents ni de camarades.
@freezed
abstract class FamilySession with _$FamilySession {
  const factory FamilySession({
    required String id,
    required String title,
    required DateTime date,
    required Audience audience,

    /// Le nom du groupe ; `null` si le groupe n'est plus lisible.
    String? groupName,
  }) = _FamilySession;
}

/// Tout ce que voit un parent ou un élève : ses élèves liés (dans l'ordre du
/// lien) et les prochaines séances planifiées de ses groupes.
@freezed
abstract class FamilySpace with _$FamilySpace {
  const factory FamilySpace({
    required List<FamilyChild> children,
    required List<FamilySession> upcoming,
  }) = _FamilySpace;
}

/// Le rang de chaque élève parmi ceux du **même prénom**, dans l'ordre du lien
/// (1, 2, …) ; `null` si son prénom est unique. Le domaine ne fabrique aucun
/// texte : la vue compose « Léa (2) » avec sa clé de traduction.
Map<StudentId, int?> homonymRanks(List<FamilyChild> children) {
  final counts = <String, int>{};
  for (final child in children) {
    counts.update(child.firstName, (n) => n + 1, ifAbsent: () => 1);
  }
  final seen = <String, int>{};
  int? rankOf(FamilyChild child) {
    final name = child.firstName;
    if (counts[name] == 1) return null;
    return seen.update(name, (n) => n + 1, ifAbsent: () => 1);
  }

  return {for (final child in children) child.id: rankOf(child)};
}
