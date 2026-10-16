import 'dart:async';

import 'package:billard_cfa/shared/lib/app_update_source.dart';

/// Double de la mise à jour : compte les activations et simule l'arrivée
/// d'une version (le service worker du navigateur).
class FakeAppUpdateSource implements AppUpdateSource {
  FakeAppUpdateSource({this.available = false});

  /// L'état courant, comme le rapporterait le navigateur.
  bool available;
  int applyCalls = 0;
  final _changes = StreamController<bool>.broadcast(sync: true);

  @override
  bool get isAvailable => available;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Future<void> apply() async => applyCalls++;

  /// Une version est installée (ou retirée) par le navigateur.
  void emit({required bool available}) {
    this.available = available;
    _changes.add(available);
  }

  Future<void> close() => _changes.close();
}
