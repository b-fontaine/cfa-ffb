import 'package:billard_cfa/shared/lib/rules_config.dart';

/// Valeur courante des règles (ADR 0012).
///
/// Chargée au lancement depuis les réglages persistés, remplacée quand les
/// réglages changent. `RulesConfig` est une fabrique qui lit [current] : un
/// cas d'usage créé après un changement voit la nouvelle valeur.
class RulesStore {
  RulesStore(this.current);

  /// Valeur courante, déjà validée par la construction de `RulesConfig`.
  RulesConfig current;
}
