import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/sheet_id.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_recall.freezed.dart';

/// Illustration d'une autre séance réutilisée par le rappel.
@freezed
abstract class SheetReuse with _$SheetReuse {
  const factory SheetReuse({
    required SheetId sheet,
    required String illustration,
  }) = _SheetReuse;
}

/// Phase d'accueil : rappel de la séance précédente (ou accueil pour la
/// première séance) et question flash.
@freezed
abstract class SheetRecall with _$SheetRecall {
  const factory SheetRecall({
    required List<String> points,
    required String ask,
    required String answer,
    required Provenance src,
    SheetReuse? reuse,
  }) = _SheetRecall;
}
