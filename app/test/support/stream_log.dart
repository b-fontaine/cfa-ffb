import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Écoute un flux et garde tout ce qu'il rend : valeurs, erreurs, fin.
///
/// Les flux des dépôts sont asynchrones (le faux Firestore livre en quelques
/// tours de la file d'événements) : [settle] laisse ces tours se jouer avant
/// qu'un test regarde [values].
class StreamLog<T> {
  StreamLog(Stream<T> stream) {
    _subscription = stream.listen(
      values.add,
      onError: errors.add,
      onDone: () => done = true,
    );
  }

  final List<T> values = [];
  final List<Object> errors = [];
  bool done = false;
  late final StreamSubscription<T> _subscription;

  /// Laisse la file d'événements livrer ce qui est en route.
  Future<void> settle() => pumpEventQueue(times: 50);

  /// Le dernier état reçu.
  T get last => values.last;

  Future<void> cancel() => _subscription.cancel();
}
