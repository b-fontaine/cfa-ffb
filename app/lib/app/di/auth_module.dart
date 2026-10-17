import 'package:billard_cfa/app/platform/shared_preferences_key_value_store.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:injectable/injectable.dart';

/// Câblage de la session (lot FB2, ADR 0024 décision 22) : un seul porteur,
/// exposé par les deux ports minuscules que lisent les dépôts.
@module
abstract class AuthModule {
  @singleton
  SessionScope sessionScope() => SessionScope();

  @singleton
  CurrentUser currentUser(SessionScope scope) => scope;

  @singleton
  ActiveClubScope activeClubScope(SessionScope scope) => scope;

  /// Stockage local de l'appareil (les tests ont leur double en mémoire).
  @Environment(Environment.prod)
  @singleton
  KeyValueStore keyValueStore() => SharedPreferencesKeyValueStore();
}
