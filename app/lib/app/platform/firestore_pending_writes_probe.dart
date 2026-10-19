import 'dart:async';

import 'package:billard_cfa/shared/persistence/pending_writes_probe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// La file d'écritures du SDK Firestore, lue par `waitForPendingWrites` : elle
/// se termine tout de suite quand la file est vide, et attend le serveur
/// sinon (hors ligne : indéfiniment). Le SDK recharge la file de son cache
/// persistant : les écritures d'avant un redémarrage y sont.
///
/// L'attente est injectable : les tests n'atteignent jamais le SDK.
class FirestorePendingWritesProbe implements PendingWritesProbe {
  FirestorePendingWritesProbe({
    Future<void> Function()? waitForPendingWrites,
    this.timeout = const Duration(milliseconds: 800),
  }) : _wait =
           waitForPendingWrites ??
           (() => FirebaseFirestore.instance.waitForPendingWrites());

  final Future<void> Function() _wait;

  /// Délai au-delà duquel la file compte comme non vide.
  final Duration timeout;

  @override
  Future<bool> hasPending() async {
    try {
      await _wait().timeout(timeout);
      return false;
    } on TimeoutException {
      return true;
    } on Object {
      // SDK pas initialisé ou instance terminée : rien à perdre, rien à dire.
      return false;
    }
  }

  @override
  Future<void> untilSent() async {
    try {
      await _wait();
    } on Object {
      // Instance terminée (déconnexion) : la file n'existe plus.
    }
  }
}
