import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sheet_source.freezed.dart';

/// Source citée par une séance (`sources` du fichier) : une source de rang
/// `S`, `FFB` ou `Web`, jamais une proposition.
@freezed
abstract class SheetSourceRef with _$SheetSourceRef {
  const factory SheetSourceRef({
    required Provenance rank,
    required String file,
    required String note,
    int? page,
  }) = _SheetSourceRef;
}
