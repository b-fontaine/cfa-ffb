import 'package:billard_cfa/shared/lib/rules_config.dart';

/// Valeur courante des règles (ADR 0012).
///
/// Chargée au lancement depuis les réglages persistés, rechargée à
/// l'activation d'un club (`ReloadRules`, ADR 0024 FB4c), remplacée quand les
/// réglages changent. `RulesConfig` est une fabrique qui lit [current] : un
/// cas d'usage créé après un changement voit la nouvelle valeur.
class RulesStore {
  /// [base] est ce que les règles valent **hors réglages du club** (par
  /// défaut, la valeur de départ) : le club activé s'y applique, le club
  /// précédent n'y laisse rien.
  RulesStore(this.current, {RulesConfig? base}) : base = base ?? current;

  /// Valeur courante, déjà validée par la construction de `RulesConfig`.
  RulesConfig current;

  /// Les règles sans les réglages d'aucun club : point de départ de
  /// `ReloadRules`, valeur remise à la déconnexion.
  RulesConfig base;
}
