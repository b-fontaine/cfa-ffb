import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_game.freezed.dart';

/// Règle qui rejoue la notion de la séance précédente `[Prop]`.
@freezed
abstract class SheetLink with _$SheetLink {
  const factory SheetLink({
    required SheetId notionOf,
    required String rule,
    required String note,
  }) = _SheetLink;
}

/// Adaptations du jeu par public `[Prop]` (absente = aucune).
@freezed
abstract class SheetAdaptation with _$SheetAdaptation {
  const factory SheetAdaptation({String? children, String? adults}) =
      _SheetAdaptation;
}

/// Jeu de la séance : repris de `jeux.md`, adapté ou sans source.
///
/// `src` ne couvre que `title`, `rules`, `scoring` et `end` ; la variante
/// ludique, le lien et les adaptations sont `[Prop]` par définition.
@freezed
abstract class SheetGame with _$SheetGame {
  const factory SheetGame({
    required String title,
    required bool adapted,
    required String players,
    required List<String> rules,
    required String scoring,
    required String end,
    required String playfulVariant,
    required AudienceWeight weight,
    required SheetAdaptation adaptation,
    required Provenance src,

    /// Numéro du jeu dans `jeux.md` ; `null` pour un jeu sans source.
    int? sourceGame,
    String? materials,
    String? setupIllustrationId,
    SheetLink? link,
  }) = _SheetGame;
}
