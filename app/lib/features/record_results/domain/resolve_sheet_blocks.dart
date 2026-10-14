import 'package:billard_cfa/entities/session_sheet/domain/results_recall_block.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'resolve_sheet_blocks.freezed.dart';

/// Notion principale et bloc du rappel de résultats dérivés d'une séance du
/// catalogue (ADR 0007) ; [none] sans séance.
@freezed
abstract class SheetBlocks with _$SheetBlocks {
  const factory SheetBlocks({String? main, String? recall}) = _SheetBlocks;

  const SheetBlocks._();

  /// Aucun bloc dérivé (saisie sans séance du catalogue).
  static const none = SheetBlocks();

  /// Blocs à retenir pour une saisie : ceux donnés ([main], [recall]), sinon
  /// ceux dérivés ; un rappel dérivé égal au bloc principal retenu est ignoré
  /// (la séance refuse `recall == main`). Règle unique de l'ouverture et de la
  /// reprise d'une séance.
  ({String? main, String? recall}) resolve({String? main, String? recall}) {
    final chosenMain = main ?? this.main;
    return (
      main: chosenMain,
      recall: recall ?? (this.recall == chosenMain ? null : this.recall),
    );
  }
}

/// Cas d'usage : les blocs d'entraînement qu'une saisie note quand elle suit
/// une séance du catalogue : le bloc de la séance et celui de la plus récente
/// séance précédente d'un autre bloc (`resultsRecallBlock`).
///
/// Sans séance, aucun bloc ; une séance inconnue du catalogue est refusée
/// (`unknownSheet`).
@injectable
class ResolveSheetBlocks {
  ResolveSheetBlocks(this._sheets);

  final SessionSheetRepository _sheets;

  Future<SheetBlocks> call(SheetId? sheetId) async {
    if (sheetId == null) return SheetBlocks.none;
    final sheet = await _sheets.getById(sheetId);
    if (sheet == null) {
      throw InvariantViolation(InvariantCode.unknownSheet, sheetId.value);
    }
    return SheetBlocks(
      main: sheet.catalogueBlock,
      recall: resultsRecallBlock(sheet, await _sheets.getAll()),
    );
  }
}
