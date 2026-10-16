import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/ui/path_cell.dart';

/// Nom accessible d'une case du parcours : « exercice : état », complété de
/// « alerte en cours » et « exercice en cours » (séparés par des virgules).
/// L'état ne se lit jamais dans la couleur.
String pathCellLabel(
  AppLocalizations l10n, {
  required String exercise,
  required PathCellState state,
  required int passed,
  required int required,
  bool alerted = false,
  bool current = false,
}) {
  final base = switch (state) {
    PathCellState.todo => l10n.pathCellTodo(exercise),
    PathCellState.started => l10n.pathCellStarted(exercise, passed, required),
    PathCellState.validated => l10n.pathCellValidated(exercise),
    PathCellState.acquired => l10n.pathCellAcquired(exercise),
  };
  return [
    base,
    if (alerted) l10n.pathCellAlerted,
    if (current) l10n.pathCellCurrent,
  ].join(', ');
}
