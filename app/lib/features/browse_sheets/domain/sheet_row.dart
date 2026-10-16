import 'package:billard_cfa/entities/session_sheet/domain/needs_review.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_row.freezed.dart';

/// Ce que montre une ligne du catalogue : le nom évocateur en titre, la partie
/// et la technique en sous-titre, un badge « n points à valider » et un badge
/// neutre par motif mineur.
@freezed
abstract class SheetRow with _$SheetRow {
  const factory SheetRow({
    required SheetId id,

    /// Nom évocateur (`theme.name`, `[Prop]`) ; vide si la séance n'en a pas
    /// (la ligne retombe alors sur la partie, jamais sur un titre vide).
    required String name,

    /// Titre de la technique (« Quantité demi-bille »).
    required String technique,
    required int part,
    required int partCount,

    /// Motifs qui comptent (jeu, exercices, initiation, rappel), dans l'ordre
    /// de `ReviewReason` : leur nombre est le « n » du badge.
    required List<ReviewReason> reviewReasons,

    /// Propositions seulement signalées (règle de lien, théorie) : jamais dans
    /// « n » ni dans l'infobulle du badge « à valider » : un badge neutre
    /// chacune.
    required List<ReviewReason> minorReasons,
  }) = _SheetRow;

  const SheetRow._();

  bool get hasName => name.isNotEmpty;

  /// Le « n » du badge ; `reviewPoints > 0` ⇔ la séance est « à valider ».
  int get reviewPoints => reviewReasons.length;
}

/// La ligne de [sheet], dont la technique compte [partCount] parties.
SheetRow sheetRowOf(SessionSheet sheet, {required int partCount}) {
  final reasons = reviewReasonsOf(sheet).toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  return SheetRow(
    id: sheet.id,
    name: sheet.theme.name.trim(),
    technique: sheet.title,
    part: sheet.part,
    partCount: partCount,
    reviewReasons: [
      for (final reason in reasons)
        if (reason.counts) reason,
    ],
    minorReasons: [
      for (final reason in reasons)
        if (!reason.counts) reason,
    ],
  );
}
