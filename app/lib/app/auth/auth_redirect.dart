import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/app/router.dart';

/// Les écrans réservés à l'ouverture de session (aucun n'est une route
/// protégée).
const Set<String> authPaths = {
  AppRoutes.splash,
  AppRoutes.signIn,
  AppRoutes.forgotPassword,
  AppRoutes.register,
  AppRoutes.selectClub,
  AppRoutes.unavailable,
};

/// Redirection du routeur selon la session (ADR 0024, décision 31) : fonction
/// pure, testable sans widget.
///
/// - `unknown` : écran de démarrage ;
/// - `signedOut` : connexion (ou inscription, ou mot de passe oublié) ;
/// - `noClub` : choix du club ; `indisponible` : écran dédié ;
/// - `ready` : toute route protégée est ouverte ; un écran de session mène
///   à l'adresse d'origine (`from`) ou à l'accueil.
///
/// L'adresse demandée est gardée dans `from` pour y revenir après la
/// connexion ; seule une adresse **intérieure** et hors des écrans de session
/// est reprise.
String? authRedirect(AuthState state, Uri location) {
  final path = location.path;
  final isSessionPath = authPaths.contains(path);
  final origin = isSessionPath
      ? safeReturnAddress(location.queryParameters['from'])
      : safeReturnAddress(location.toString());
  String? to(String target) =>
      path == target ? null : AppRoutes.withFrom(target, origin);
  return switch (state) {
    AuthUnknown() => to(AppRoutes.splash),
    AuthSignedOut() =>
      path == AppRoutes.signIn ||
              path == AppRoutes.forgotPassword ||
              path == AppRoutes.register
          ? null
          : AppRoutes.withFrom(AppRoutes.signIn, origin),
    AuthNoClub() => to(AppRoutes.selectClub),
    AuthIndisponible() => to(AppRoutes.unavailable),
    AuthReady() => isSessionPath ? (origin ?? AppRoutes.home) : null,
  };
}

/// L'adresse de retour, si c'est une adresse intérieure qui n'est pas un écran
/// de session ni l'accueil ; `null` sinon (jamais une adresse extérieure).
String? safeReturnAddress(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !raw.startsWith('/') ||
      raw.startsWith('//') ||
      authPaths.contains(uri.path) ||
      uri.path == AppRoutes.home) {
    return null;
  }
  return uri.toString();
}
