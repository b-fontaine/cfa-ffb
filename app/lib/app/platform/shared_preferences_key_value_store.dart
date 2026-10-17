import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stockage local clé/valeur par `shared_preferences` (API asynchrone : aucune
/// initialisation à attendre au démarrage). Sur le web, `localStorage` ; sur
/// mobile, les préférences du système, exclues des sauvegardes de l'appareil
/// (ADR 0025).
class SharedPreferencesKeyValueStore implements KeyValueStore {
  SharedPreferencesKeyValueStore({SharedPreferencesAsync? preferences})
    : _given = preferences;

  final SharedPreferencesAsync? _given;

  /// Créé au premier usage : le plugin n'est sollicité qu'à ce moment.
  late final SharedPreferencesAsync _preferences =
      _given ?? SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> remove(String key) => _preferences.remove(key);
}
