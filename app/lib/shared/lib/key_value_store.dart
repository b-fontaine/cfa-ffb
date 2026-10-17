import 'package:injectable/injectable.dart';

/// Stockage local clé/valeur de ce qui reste propre à l'appareil (ADR 0024,
/// décision 23) : club actif mémorisé, et plus tard la séance en cours.
///
/// Les clés portent l'identifiant du compte pour qu'un autre utilisateur du
/// même appareil ne retrouve rien de celui d'avant. Port sans dépendance au
/// plugin : l'implémentation de production est
/// `app/platform/shared_preferences_key_value_store.dart`.
abstract interface class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

/// Stockage en mémoire des tests et scénarios BDD.
@LazySingleton(as: KeyValueStore, env: [Environment.test])
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  /// Copie des entrées (assertions des tests).
  Map<String, String> get entries => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
