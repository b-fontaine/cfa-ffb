import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_grouping.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_option.freezed.dart';

/// Une séance du catalogue réduite à de quoi la choisir, la libeller et la
/// grouper par technique (lecture seule) : planification, saisie et
/// historique la nomment ainsi (« Quantité demi-bille, séance 2/2 »).
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

/// Les séances [sheets] dans l'ordre d'enseignement (techniques puis parties
/// croissantes, voir [groupByTechnique]).
List<SheetOption> sheetOptionsOf(Iterable<SessionSheet> sheets) =>
    List.unmodifiable([
      for (final group in groupByTechnique(sheets))
        for (final sheet in group.sheets)
          SheetOption(
            id: sheet.id,
            technique: group.technique,
            techniqueRank: group.rank,
            title: sheet.title,
            part: sheet.part,
            partCount: group.partCount,
          ),
    ]);

/// L'option de la séance [id] parmi [sheets], `null` si le catalogue ne la
/// connaît pas (l'affichage ne lève jamais pour un identifiant inconnu).
SheetOption? sheetOptionOf(Iterable<SessionSheet> sheets, SheetId? id) =>
    id == null
    ? null
    : sheetOptionsOf(sheets).where((option) => option.id == id).firstOrNull;
