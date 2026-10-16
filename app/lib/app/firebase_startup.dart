import 'package:flutter/foundation.dart';

/// Lance l'initialisation de Firebase sans qu'un échec puisse empêcher
/// l'application de démarrer (lot 15). Hors ligne, le SDK web de Firebase
/// (chargé depuis le CDN de Google) est injoignable : l'application doit
/// quand même s'ouvrir et fonctionner avec ses données locales.
///
/// Retourne `true` si l'initialisation a réussi. Rien n'utilise encore
/// Firebase (lots FB1 et suivants) : l'appelant ne l'attend pas.
Future<bool> startFirebase(
  Future<void> Function() initialize, {
  void Function(Object error)? onError,
}) async {
  try {
    await initialize();
    return true;
  } on Object catch (error) {
    (onError ?? (e) => debugPrint('Firebase indisponible : $e'))(error);
    return false;
  }
}
