import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_range.freezed.dart';

/// Nombre de séances conseillé pour un bloc (valeurs approximatives `[S]`).
@freezed
abstract class SessionRange with _$SessionRange {
  factory SessionRange({required int min, required int max}) = _SessionRange;

  SessionRange._() {
    if (min < 1 || min > max) {
      throw const InvariantViolation(InvariantCode.invalidRange);
    }
  }
}
