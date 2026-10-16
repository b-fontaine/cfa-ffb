/// Port du plein écran (ADR 0017) : l'écran de la plate-forme, hors de
/// l'application. Dart pur ; les implémentations (navigateur, mobile) sont
/// dans la couche `app`.
///
/// [enter] et [exit] ne lèvent pas : en cas de refus, [isActive] reste
/// inchangé et [changes] rapporte l'état réel.
abstract interface class FullscreenController {
  /// Vrai quand la plate-forme sait passer en plein écran (faux sur iPhone
  /// Safari et sur le bureau natif : l'entrée est alors masquée).
  bool get isSupported;

  /// Vrai quand l'application est en plein écran.
  bool get isActive;

  /// Vrai/faux à chaque bascule, y compris celles qui ne viennent pas de
  /// l'application (touche Échap du navigateur).
  Stream<bool> get changes;

  /// Passe en plein écran. Sur le web, doit être appelé dans le geste de
  /// l'utilisateur, avant tout `await`.
  Future<void> enter();

  /// Quitte le plein écran.
  Future<void> exit();
}
