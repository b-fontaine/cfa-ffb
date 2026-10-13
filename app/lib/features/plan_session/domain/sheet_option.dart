import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_option.freezed.dart';

/// Une séance du catalogue proposée au planificateur : juste de quoi la
/// choisir, la libeller et la grouper par technique (lecture seule).
@freezed
abstract class SheetOption with _$SheetOption {
  const factory SheetOption({
    required SheetId id,

    /// Identifiant de la technique (`demi-bille`) : clé de regroupement.
    required String technique,

    /// Rang de la technique dans l'ordre d'enseignement (à partir de 1).
    required int techniqueRank,

    /// Titre de la technique (« Quantité demi-bille »).
    required String title,

    /// Partie (`k`) et nombre de parties (`n`) de la technique.
    required int part,
    required int partCount,
  }) = _SheetOption;
}
