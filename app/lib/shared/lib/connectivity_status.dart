import 'dart:async';

import 'package:injectable/injectable.dart';

/// Le navigateur ou l'appareil dit-il avoir du réseau ? (pastille de
/// synchronisation, ADR 0024, C4 ; ADR 0010.)
///
/// Un **indice**, pas une preuve : « en ligne » ne garantit pas que le serveur
/// répond. L'état des envois (`SendStatus`) dit, lui, ce qui est réellement
/// parti. Sans moyen fiable de le savoir (mobile natif tant qu'aucun plugin de
/// réseau n'est retenu), l'implémentation répond « en ligne » : la pastille ne
/// dit jamais « Hors ligne » à tort.
abstract interface class ConnectivityStatus {
  bool get online;

  /// Émet à chaque changement de [online].
  Stream<bool> get changes;
}

/// Double des tests et scénarios BDD : le réseau se coupe et revient à la
/// demande.
@LazySingleton(as: ConnectivityStatus, env: [Environment.test])
class InMemoryConnectivityStatus implements ConnectivityStatus {
  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  bool get online => _online;

  @override
  Stream<bool> get changes => _changes.stream;

  /// Coupe ou rétablit le réseau.
  void setOnline({required bool value}) {
    if (_online == value) return;
    _online = value;
    _changes.add(value);
  }
}

/// Sans information sur le réseau : toujours « en ligne » (voir
/// [ConnectivityStatus]).
class AlwaysOnline implements ConnectivityStatus {
  const AlwaysOnline();

  @override
  bool get online => true;

  @override
  Stream<bool> get changes => const Stream<bool>.empty();
}
