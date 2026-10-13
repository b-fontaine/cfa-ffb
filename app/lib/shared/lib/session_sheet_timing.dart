import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';

/// Répartit [budget] minutes entre des éléments pondérés, par la méthode du
/// **plus fort reste** (FORMAT des séances § 4).
///
/// Un poids `null` ou inférieur à 1 désigne un élément non affiché : il reçoit
/// 0 minute. Minutes d'un élément = `budget × poids / Σ poids`, arrondies au
/// plus fort reste ; à égalité, l'élément le plus haut dans la liste reçoit la
/// minute. La somme vaut exactement [budget] ; la liste rendue a la longueur de
/// [weights].
///
/// Un budget positif sans aucun élément affiché lève `invalidSheet` : la
/// somme ne pourrait pas être exacte.
List<int> distributeMinutes({
  required int budget,
  required List<int?> weights,
}) {
  final shown = [
    for (final w in weights)
      if (w != null && w >= 1) w else 0,
  ];
  final total = shown.fold(0, (sum, w) => sum + w);
  if (total == 0) {
    if (budget > 0) {
      throw const InvariantViolation(
        InvariantCode.invalidSheet,
        'phase sans élément affiché',
      );
    }
    return List.filled(weights.length, 0);
  }
  final minutes = [for (final w in shown) budget * w ~/ total];
  final remainders = [for (final w in shown) budget * w % total];
  var leftover = budget - minutes.fold(0, (sum, m) => sum + m);
  final byRemainder =
      [
        for (var i = 0; i < shown.length; i++)
          if (shown[i] > 0) i,
      ]..sort((a, b) {
        final byValue = remainders[b].compareTo(remainders[a]);
        return byValue != 0 ? byValue : a.compareTo(b);
      });
  for (final index in byRemainder) {
    if (leftover == 0) break;
    minutes[index]++;
    leftover--;
  }
  return minutes;
}

/// Minutes de chaque élément affiché, par phase, pour [audience].
///
/// [shapes] est la configuration injectée (`RulesConfig.shapes`) : les budgets
/// de phase en viennent, jamais d'une constante. [weights] donne, pour chaque
/// phase, le poids de ses éléments dans l'ordre du fichier ; une phase de la
/// forme sans entrée est une séance mal formée.
Map<SessionPhase, List<int>> sessionSheetTiming({
  required Audience audience,
  required Map<Audience, SessionShape> shapes,
  required Map<SessionPhase, List<int?>> weights,
}) {
  final shape = shapes[audience];
  if (shape == null) {
    throw const InvariantViolation(InvariantCode.invalidRules);
  }
  return {
    for (final slot in shape.phases)
      slot.phase: distributeMinutes(
        budget: slot.minutes,
        weights:
            weights[slot.phase] ??
            (throw InvariantViolation(
              InvariantCode.invalidSheet,
              'phase sans poids : ${slot.phase.name}',
            )),
      ),
  };
}
