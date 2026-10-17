import 'package:billard_cfa/shared/lib/identifiers.dart';

/// Le compte connecté (port minuscule, sans dépendance au SDK
/// d'authentification).
///
/// Les dépôts et les cas d'usage qui ont besoin de savoir « qui » lisent
/// [id] à chaque appel : ils ne le figent jamais dans un singleton (ADR 0024,
/// décision 22). `null` : personne n'est connecté.
abstract interface class CurrentUser {
  UserId? get id;

  /// Vrai si le compte est administrateur de l'application (document
  /// `admins/{uid}`) : un fait du compte, indépendant du club actif.
  bool get isAdmin;
}
