import 'package:billard_cfa/app/auth/auth_state.dart';
import 'package:billard_cfa/app/router.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/invitation_code.dart';
import 'package:billard_cfa/shared/lib/role_policy.dart';

/// Les écrans réservés à l'ouverture de session (aucun n'est une route
/// protégée).
const Set<String> authPaths = {
  AppRoutes.splash,
  AppRoutes.signIn,
  AppRoutes.forgotPassword,
  AppRoutes.register,
  AppRoutes.selectClub,
  AppRoutes.unavailable,
  AppRoutes.accessDenied,
};

/// Vrai pour `/join` et `/join/<code>` (rejoindre un club avec un code).
bool isJoinPath(String path) =>
    path == AppRoutes.join || path.startsWith('${AppRoutes.join}/');

/// Le code d'invitation porté par [location] : le lien `/join/<code>`, ou le
/// paramètre `code` de l'écran de démarrage et de l'inscription. `null` si
/// l'adresse n'en porte pas, ou si sa forme n'est pas celle d'un code.
String? invitationCodeOf(Uri location) {
  final path = location.path;
  final String? raw;
  if (isJoinPath(path)) {
    final segments = location.pathSegments;
    raw = segments.length == 2 ? segments[1] : null;
  } else if (path == AppRoutes.splash || path == AppRoutes.register) {
    raw = location.queryParameters['code'];
  } else {
    raw = null;
  }
  return raw == null ? null : InvitationCode.tryParse(raw)?.value;
}

/// Redirection du routeur selon la session (ADR 0024, décisions 24 et 31) :
/// fonction pure, testable sans widget.
///
/// - `unknown` : écran de démarrage ;
/// - `signedOut` : connexion (ou inscription, ou mot de passe oublié) ; un lien
///   `/join/<code>` au code valide ouvre l'inscription avec le code déjà saisi,
///   tout autre `/join…` (sans code, code mal formé) mène à la connexion, à
///   froid comme session connue ;
/// - `noClub` : choix du club, « Rejoindre un club » (`/join…`) et, pour un
///   administrateur, « Administration » ; un code gardé à l'inscription mène
///   directement à `/join/<code>` quand le compte n'a aucun club ;
/// - `indisponible` : écran dédié ;
/// - `ready` : un écran de session mène à l'adresse d'origine (`from`) ou à
///   l'accueil ; le reste est filtré par le rôle ([roleRedirect]).
///
/// L'adresse demandée est gardée dans `from` pour y revenir après la
/// connexion ; seule une adresse **intérieure** et hors des écrans de session
/// est reprise. Le code d'un lien d'invitation n'y est jamais recopié : il
/// voyage dans `code` (écran de démarrage, inscription) ou dans `/join/<code>`,
/// de sorte que le lien ouvert à froid, quand la session est encore inconnue,
/// aboutit au même écran que s'il était ouvert session connue.
String? authRedirect(AuthState state, Uri location) {
  final path = location.path;
  final code = invitationCodeOf(location);
  final carriedOnSplash = path == AppRoutes.splash && code != null;
  final isSessionPath = authPaths.contains(path);
  final origin = isSessionPath
      ? safeReturnAddress(location.queryParameters['from'])
      : safeReturnAddress(location.toString());
  String? to(String target) =>
      path == target ? null : AppRoutes.withFrom(target, origin);
  return switch (state) {
    AuthUnknown() =>
      code == null
          ? to(AppRoutes.splash)
          : (path == AppRoutes.splash ? null : AppRoutes.splashWith(code)),
    AuthSignedOut() => _signedOut(location, origin, code),
    AuthNoClub(:final choices, :final isAdmin, :final pendingInvitation) =>
      carriedOnSplash
          ? AppRoutes.joinWith(code)
          : isJoinPath(path) || (isAdmin && path == AppRoutes.administration)
          ? null
          : pendingInvitation != null && choices.isEmpty
          ? AppRoutes.joinWith(pendingInvitation.value)
          : to(AppRoutes.selectClub),
    AuthAccessDenied() => to(AppRoutes.accessDenied),
    AuthIndisponible() => to(AppRoutes.unavailable),
    AuthReady() =>
      carriedOnSplash
          ? AppRoutes.joinWith(code)
          : isSessionPath
          ? (origin ?? AppRoutes.home)
          : roleRedirect(state, location),
  };
}

String? _signedOut(Uri location, String? origin, String? code) {
  final path = location.path;
  if (path == AppRoutes.splash && code != null) {
    return AppRoutes.registerWith(code);
  }
  if (path == AppRoutes.signIn ||
      path == AppRoutes.forgotPassword ||
      path == AppRoutes.register) {
    return null;
  }
  // Un lien `/join/<code>` ne vaut que par son code **validé** ; sans code
  // exploitable (`/join`, segments en trop, forme invalide) on tombe, comme à
  // froid via l'écran de démarrage, sur la connexion.
  if (isJoinPath(path) && code != null) {
    return AppRoutes.registerWith(code);
  }
  return AppRoutes.withFrom(AppRoutes.signIn, origin);
}

/// Le garde de route par rôle (ADR 0024, décision 14) : `null` si le rôle de
/// [state] peut ouvrir [location], sinon l'adresse où l'envoyer. Ce que le menu
/// ne montre pas, la route le refuse aussi (un lien tapé à la main ne contourne
/// rien) ; les règles Firestore sont le garde de fond côté serveur.
///
/// - tout rôle : « Rejoindre un club » ;
/// - **administrateur** (le compte, quel que soit son rôle de club) :
///   `/administration` ;
/// - **enseignant, directeur, administrateur** : tout l'animateur, sauf les
///   réglages et la clôture d'une saison (directeur et administrateur) ;
/// - **élève et parent** : « Mes enfants », « Plus » et la fiche en parcours de
///   leurs seuls élèves liés ; le reste ramène à « Mes enfants ».
String? roleRedirect(AuthReady state, Uri location) {
  final role = state.club.role;
  final path = location.path;
  final segments = location.pathSegments;
  if (isJoinPath(path)) return null;
  if (path == AppRoutes.administration) {
    return state.isAdmin ? null : AppRoutes.home;
  }
  if (role.animates) {
    final closing =
        segments.length == 3 &&
        '/${segments[0]}' == AppRoutes.seasons &&
        segments[2] == AppRoutes.closeSegment;
    final forbidden =
        path == AppRoutes.myChildren ||
        (path == AppRoutes.settings && !role.can(Capability.manageSettings)) ||
        (closing && !role.can(Capability.closeSeason));
    return forbidden ? AppRoutes.home : null;
  }
  final ownShowcase =
      segments.length == 3 &&
      '/${segments[0]}' == AppRoutes.students &&
      segments[2] == AppRoutes.showcaseSegment &&
      state.club.studentIds.contains(StudentId(segments[1]));
  final allowed =
      path == AppRoutes.myChildren ||
      path == AppRoutes.more ||
      path == AppRoutes.switchClub ||
      ownShowcase;
  return allowed ? null : AppRoutes.myChildren;
}

/// L'adresse de retour, si c'est une adresse intérieure qui n'est pas un écran
/// de session, un lien d'invitation (le code ne se recopie pas) ni l'accueil ;
/// `null` sinon (jamais une adresse extérieure).
String? safeReturnAddress(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !raw.startsWith('/') ||
      raw.startsWith('//') ||
      authPaths.contains(uri.path) ||
      isJoinPath(uri.path) ||
      uri.path == AppRoutes.home) {
    return null;
  }
  return uri.toString();
}
