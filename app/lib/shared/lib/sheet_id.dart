import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

final _slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

/// Identifiant d'une séance du catalogue : `<technique>-<k>` (`demi-bille-2`).
///
/// Slug stable à vie (a-z, 0-9, tirets) : une séance planifiée le référence.
/// Value object de `shared/lib` pour que `entities/session` puisse le porter
/// sans importer `entities/session_sheet`.
@immutable
final class SheetId {
  SheetId(this.value) {
    if (!_slug.hasMatch(value)) {
      throw const InvariantViolation(InvariantCode.invalidSheet);
    }
  }

  /// Identifiant issu d'une saisie ou d'une adresse, ou `null` s'il est mal
  /// formé (jamais d'exception).
  static SheetId? tryParse(String? raw) =>
      raw != null && _slug.hasMatch(raw) ? SheetId(raw) : null;

  final String value;

  @override
  bool operator ==(Object other) => other is SheetId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
