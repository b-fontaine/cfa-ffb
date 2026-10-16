import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Un groupe proposé au sélecteur du catalogue : type sans logique, passé par
/// la page pour que `browse_sheets` ne dépende pas d'un autre slice.
@immutable
final class GroupChoice {
  const GroupChoice(this.id, this.name);

  final GroupId id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is GroupChoice && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
