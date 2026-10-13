import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_initiation.freezed.dart';

/// Élément d'initiation (fiche d'initiation fédérale), noté localement.
@freezed
abstract class SheetInitiation with _$SheetInitiation {
  const factory SheetInitiation({
    required String id,
    required int initiationSheet,
    required String title,
    required AudienceWeight weight,
    required String setup,
    required String goal,
    required String expected,
    required Scoring scoring,
    required Provenance src,
    String? illustrationId,
  }) = _SheetInitiation;
}
