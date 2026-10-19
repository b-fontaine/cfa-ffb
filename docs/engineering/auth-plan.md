# Plan : authentification (lot FB2)

Statut : **livré** (2026-10-17). Le code Dart d'authentification est exercé contre le **vrai SDK `firebase_auth`** dans le **build web compilé** (dart2js, `scripts/build_web.sh`) sous l'émulateur Auth (`scripts/web_smoke.sh` : démarrage, échec générique, connexion, session conservée au rechargement, déconnexion) ; les tests Dart restent sur des doubles (le plugin natif est absent de `flutter test`). Le parcours **application + émulateurs Auth et Firestore + graine** a son garde-fou (`scripts/emulator_e2e.sh`, application en mode debug). **Aucune base de production touchée**, rien de déployé, `flutterfire configure` non exécuté. Android et iOS réels non exercés.
Décisions : [ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) (décisions 22, 23, 24 et 31 ; A9 à A12, B8, B9 de la roadmap), conformité : [ADR 0025](adr/0025-comptes-et-donnees-de-mineurs-conformite.md).
Aucune décision nouvelle : les précisions de réalisation sont en note dans l'ADR 0024.

## Ce que le lot fait

Aucune route n'est ouverte sans compte, sur Android, iOS et web (aucun mode « sans compte »). Connexion par **adresse e-mail et mot de passe**, **adresse vérifiée exigée**, « mot de passe oublié », déconnexion, choix du **club actif** si le compte en a plusieurs, état « indisponible » et démarrage hors ligne avec une session persistée. L'inscription est **fermée** : elle exige un code d'invitation, mais ce lot ne crée que le compte d'authentification.

## Où est quoi (FSD)

| Couche | Contenu |
|---|---|
| `shared/lib` | ports minuscules sans dépendance Firebase : `CurrentUser` (`UserId`), `ActiveClubScope` (`ClubId`, `Role`), `ClubSwitchGuard`, `KeyValueStore` (+ double en mémoire) |
| `entities/account` | `Account` (id, e-mail, `emailVerified`), `AuthRepository` (port), `AuthFailure` / `AuthFailureCode` (**distincts d'`InvariantCode`**), `SessionScope` (porteur des deux ports) ; `data` : `AuthSdk` (frontière du SDK), `FirebaseAuthRepository` (traduit les codes du SDK), `InMemoryAuthRepository` (BDD) |
| `entities/membership` | `ClubMembership`, `MembershipsSource` (port : clubs d'un compte, et `isAdmin`), `ActiveClubMemory` (club actif retenu **par compte**, avec ses groupes et fiches) ; `data` : `StoreMembershipsSource` (production et BDD, lot FB3, [clubs-roles-plan.md](clubs-roles-plan.md)) |
| `features/sign_in` | cas d'usage `SignIn`, `ResendVerification`, `RequestPasswordReset`, `RegisterWithInvitation`, `InvitationCode`, port `PendingInvitations` (point d'extension de FB3) ; `SignInCubit`, `RegisterCubit`, `ForgotPasswordCubit` ; `SignInForm`, `RegisterForm`, `ForgotPasswordForm`, `AuthFormFeedback`, `AccountSection` |
| `features/select_club` | `resolveActiveClub` (fonction pure), `ChooseClub` ; `ClubChoiceList` |
| `pages` | `splash`, `sign_in`, `forgot_password`, `register`, `select_club`, `unavailable` ; `more` reçoit le compte et « Changer de club » |
| `app` | `AuthCubit` (orchestre : il compose les slices qui ne peuvent pas s'importer), `AuthState`, `authRedirect` (pure), `AuthRefresh`, `RunningSessionsClubSwitchGuard`, `SessionStartup` (`FirebaseStartup` en production), `platform/firebase_auth_sdk.dart` et `platform/firebase_sdk_gateway.dart` (les deux seuls importeurs de `firebase_auth`, règle 9 vérifiée par `check_architecture.dart`), `platform/shared_preferences_key_value_store.dart` |

## États et redirection

`AuthCubit` : `unknown` (écran de démarrage localisé) → `signedOut`, `noClub` (aucun club, ou plusieurs à choisir), `ready` (club et rôle), `indisponible`. L'initialisation de Firebase (`FirebaseStartup.ready`, via le port `SessionStartup`) est **attendue** par l'`AuthCubit`, qui lit ensuite la session persistée par `AuthRepository.watchAccount()` ; un nouveau compte rend caduque la résolution en cours (compteur de génération).

`authRedirect(état, adresse)` (fonction pure, testée sans widget) :

| État | Adresse demandée | Résultat |
|---|---|---|
| `unknown` | toute | `/splash` |
| `signedOut` | hors `/sign-in`, `/forgot-password`, `/register` | `/sign-in?from=<adresse>` |
| `noClub` | hors `/select-club` | `/select-club?from=<adresse>` |
| `indisponible` | hors `/unavailable` | `/unavailable` |
| `ready` | un écran de session | `from` si c'est une adresse **intérieure** sûre, sinon `/` |

`from` n'est jamais suivi s'il est extérieur (`https:`, `//`), s'il n'est pas absolu ou s'il désigne un écran de session. Le club actif **reconstruit l'interface** par un `KeyedSubtree(clubId)` autour du routeur.

## Club actif

Mémorisé **par compte** sur l'appareil (`active_club.<uid>`, valeur : club, nom, rôle) via `shared_preferences` derrière `KeyValueStore`, **effacé à la déconnexion**. Au démarrage : club retenu et toujours valable, sinon seul club, sinon choix. **Hors ligne** (`MembershipsUnavailable`) : le club retenu ouvre l'application ; sans club retenu, état « indisponible ». Le rôle courant du serveur l'emporte sur celui qui avait été retenu.

**Bascule interdite** pendant une séance guidée commencée : `RunningSessionsClubSwitchGuard` lit `RunSheetSessions.snapshot()` (ADR 0020 : le cubit du guide, avec sa saisie ouverte depuis le guide, y vit). La page « Changer de club » le dit, grise la liste, et `ChooseClub` refuse aussi si la garde bloque (le premier choix, sans club actif, n'a rien à perdre). **Limite assumée** : une saisie ouverte seule (`/record/:id`) est un écran de route, déjà enregistré à chaque passage ; la bascule se fait depuis « Plus », donc quitter l'écran est un préalable et rien n'y est perdu.

## Anti-énumération (décision 31)

- Connexion : compte inconnu, mauvais mot de passe, compte désactivé et adresse refusée par le SDK donnent le **même** message (`invalidCredentials`). L'émulateur, comme un projet sans « protection contre l'énumération d'adresses », **distingue** `wrong-password` et `user-not-found` : le regroupement est fait par `FirebaseAuthRepository`, pas par le service (prouvé par `scripts/rules_test/auth_emulator.test.mjs`).
- `emailNotVerified` n'est rendu qu'après des **identifiants justes** ; le compte est aussitôt déconnecté par `SignIn`. « Renvoyer l'e-mail de vérification » exige les mêmes identifiants.
- « Mot de passe oublié » : même confirmation que l'adresse existe ou non ; `user-not-found` est avalé ; seuls réseau et trop de tentatives sont rapportés.
- Inscription : une adresse déjà utilisée donne `registrationFailed` (aucune cause).

## Inscription fermée : ce que le lot fait et ne fait pas

`RegisterWithInvitation` : forme du code (au moins 10 caractères A à Z et 2 à 7, normalisé), mot de passe d'**au moins 10 caractères**, création du compte, courriel de vérification (envoyé par Firebase Auth, jamais par l'application), code gardé sur l'appareil sous le compte par `PendingInvitations` (**point d'extension de FB3**), session fermée. **Rien d'autre** : l'existence du code, son expiration, sa consommation (lot d'écritures contrôlé par `getAfter`) et la création du `member` sont FB3. Après vérification et connexion, un compte sans `member` arrive en « Aucun club ». Le serveur n'impose que 6 caractères : **la règle des 10 est celle de l'application seule** (mesuré à l'émulateur).

## Tests

| Niveau | Où |
|---|---|
| BDD (`test/bdd/authentication.feature`, 24 scénarios) | connexion réussie, identifiants invalides (mauvais mot de passe, adresse inconnue : même message), adresse mal formée, e-mail non vérifié et renvoi, mot de passe oublié (connue, inconnue), déconnexion, redirection (`/backup`, `/exercises/…`), retour à l'adresse demandée, français, session persistée et relance, plusieurs clubs (choix, club retenu, bascule depuis « Plus », bascule refusée en séance guidée), sans club, état indisponible et « Réessayer », hors ligne avec club retenu, hors ligne sans club retenu, inscription (réussie, mot de passe court, code mal formé) |
| Unitaires | cas d'usage, cubits (`bloc_test`), `AuthCubit` (états, génération, hors ligne, bascule), `authRedirect`, dépôts (`FirebaseAuthRepository` sur un SDK scripté, `InMemoryAuthRepository`), `ActiveClubMemory`, `FirebaseAuthSdk` (mocktail sur `FirebaseAuth`), `SharedPreferencesKeyValueStore`, graphe de production et de test, widgets (cibles de 48 dp, régions vives, états désactivés) |
| Contrat `AuthRepository` | `auth_repository_contract_test.dart` : la **même** suite de connexion sur `InMemoryAuthRepository` (celui des BDD) et sur `FirebaseAuthRepository` (trois variantes de codes du service) ; garde que les BDD « mauvais mot de passe » et « adresse inconnue » ne reposent pas sur un double plus indulgent que la production |
| Émulateur Auth | `scripts/rules_test/auth_emulator.test.mjs`, dans `scripts/rules_test.sh` (donc `check.sh --full` et la CI) : prouve les codes d'erreur et les courriels que le code Dart suppose (voir ci-dessus). Le code Dart lui-même **ne peut pas** tourner contre l'émulateur sous `flutter test` (plugin natif absent) : c'est le rôle de la ligne suivante |
| Fumée du build compilé | `scripts/web_smoke.sh` (`scripts/web_smoke/web_smoke.test.mjs`, dans `check.sh --full` et la CI) : le build de production dans Chrome, le vrai SDK, appels d'authentification renvoyés à l'émulateur, tout autre hôte refusé. Voir [testing.md](testing.md) |

Les BDD existants s'exécutent **connectés** : `UiWorld.prepare` crée le compte de l'animateur (adresse vérifiée, session persistée, un seul club) ; un `Given` d'authentification peut le déconnecter (`nobody is signed in on the device`). `relaunchApp` et `the app restarts` réinitialisent l'`AuthCubit` (un lancement relit la session persistée).

## Reste (par l'utilisateur ou par un autre lot)

- **Console Firebase** (rien n'a été fait) : vérifier que l'e-mail et mot de passe est le seul fournisseur actif ; **activer la protection contre l'énumération d'adresses e-mail** (elle fait renvoyer `invalid-credential`, le code l'attend déjà) ; contrôler les modèles de courriel de vérification et de réinitialisation (langue, expéditeur, lien) ; domaines autorisés pour le web ; `flutterfire configure` (reste de FB1).
- ~~**FB3**~~ : livré (`StoreMembershipsSource`, consommation du code gardé, règles et leurs tests) ; voir [clubs-roles-plan.md](clubs-roles-plan.md).
- **FB5** : SDK web servi localement (**fait en FB5a, 2026-10-19**) (hors ligne sur le web : tant qu'il venait de `gstatic.com`, le web hors ligne s'ouvre en « indisponible » même avec une session persistée ; les plateformes natives s'ouvrent avec la session persistée et le club retenu).
- **Libellés fr/en** des écrans de session : projets `[Prop]`, à relire par l'animateur.
- Appareil réel Android et iOS non exercés (aucun build natif n'a été lancé dans ce lot).
