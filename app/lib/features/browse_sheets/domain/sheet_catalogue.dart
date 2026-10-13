import 'package:billard_cfa/entities/session_sheet/domain/needs_review.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_catalogue.freezed.dart';

/// Filtre du catalogue par contenu à valider.
enum SheetReviewFilter {
  /// Toutes les séances.
  none,

  /// Les séances ayant du contenu `[Prop]` à valider (voir `reviewReasonsOf`).
  toReview,

  /// Les séances dont le jeu est à valider (adapté, sans source, ou règle de
  /// lien ajoutée à un jeu sourcé).
  games,
}

/// Une technique et ses séances (ses « parties »), dans l'ordre du catalogue.
@freezed
abstract class TechniqueGroup with _$TechniqueGroup {
  const factory TechniqueGroup({
    /// Rang de la technique dans l'ordre d'enseignement (à partir de 1) ;
    /// un filtre ne le change pas.
    required int rank,

    /// Identifiant de la technique (`demi-bille`).
    required String technique,

    /// Titre de la technique, identique pour toutes ses séances.
    required String title,

    /// Nombre total de séances de la technique (un filtre ne le change pas).
    required int partCount,

    /// Séances listées, par partie croissante.
    required List<SessionSheet> sheets,
  }) = _TechniqueGroup;
}

/// Le catalogue de séances regroupé par technique, dans l'ordre
/// d'enseignement. Lecture seule.
@freezed
abstract class SheetCatalogue with _$SheetCatalogue {
  const factory SheetCatalogue({required List<TechniqueGroup> groups}) =
      _SheetCatalogue;

  const SheetCatalogue._();

  int get techniqueCount => groups.length;

  /// Nombre de séances listées.
  int get sheetCount => groups.fold(0, (sum, g) => sum + g.sheets.length);

  /// Le même catalogue réduit selon [filter] ; les techniques sans séance
  /// retenue disparaissent. `partCount` reste celui de la technique entière.
  SheetCatalogue filtered(SheetReviewFilter filter) {
    final keep = switch (filter) {
      SheetReviewFilter.none => null,
      SheetReviewFilter.toReview => needsReview,
      SheetReviewFilter.games => gameNeedsReview,
    };
    if (keep == null) return this;
    return SheetCatalogue(
      groups: [
        for (final group in groups)
          if (group.sheets.any(keep))
            group.copyWith(sheets: group.sheets.where(keep).toList()),
      ],
    );
  }
}
