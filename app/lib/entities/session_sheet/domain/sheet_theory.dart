import 'package:billard_cfa/entities/session_sheet/domain/audience_weight.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_theory.freezed.dart';

/// Section de théorie illustrée (phase notion).
@freezed
abstract class SheetTheorySection with _$SheetTheorySection {
  const factory SheetTheorySection({
    required String id,
    required String title,
    required AudienceWeight weight,
    required List<String> body,
    required String keyPoint,
    required Provenance src,
    @Default(<String>[]) List<String> adultExtra,
    String? demo,
    @Default(<String>[]) List<String> illustrationIds,
  }) = _SheetTheorySection;
}
