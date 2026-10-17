import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tentatives de connexion réseau du scénario en cours.
final List<String> networkAttempts = [];

class _ForbiddenNetwork extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    networkAttempts.add('createHttpClient');
    throw StateError('accès réseau interdit pendant le scénario');
  }
}

/// Usage: network access is forbidden
///
/// Toute création de client HTTP pendant le scénario est enregistrée puis
/// refusée ; l'état d'origine est rétabli à la fin du test.
Future<void> networkAccessIsForbidden(WidgetTester tester) async {
  final previous = HttpOverrides.current;
  networkAttempts.clear();
  HttpOverrides.global = _ForbiddenNetwork();
  addTearDown(() => HttpOverrides.global = previous);
}
