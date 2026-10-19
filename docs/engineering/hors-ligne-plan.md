# Plan : web hors ligne et installable (lot 15)

Objectif : l'application web **s'ouvre et fonctionne sans réseau après une
première visite** (élèves, résultats, catalogue, schémas, guide, présentation
plein écran) et **s'installe** sur l'écran d'accueil. Décision structurante :
[ADR 0018](adr/0018-hors-ligne-service-worker-precache-versionne.md). Ne
contredit pas le plan Firebase (horizon H5, [roadmap](roadmap.md)) : la source
de vérité reste drift tant que FB7 n'est pas livré ; voir « Firebase » plus
bas pour ce que FB1 et FB5 devront reprendre.

## 1. État avant le lot (audit du 2026-10-16)

Constats faits sur un build `flutter build web --release` de `main`, servi par
`http.server`, observé avec Playwright (requêtes réseau, cache, registre des
service workers).

| Élément | État | Conséquence hors ligne |
|---|---|---|
| Service worker | `flutter_service_worker.js` généré par Flutter 3.47.7 : un **résidu qui se désinscrit lui-même** (« Flutter's service worker is deprecated »), aucun cache | **Aucun usage hors ligne** : au rechargement sans réseau, la page ne se charge pas |
| CanvasKit | `useLocalCanvasKit` absent de `flutter_bootstrap.js` : le moteur est chargé depuis `www.gstatic.com/flutter-canvaskit/<révision>/` | Dépendance CDN à l'exécution : l'application ne démarre pas sans réseau, même avec un cache de fichiers locaux |
| Polices | Exo2 (OFL) et MaterialIcons locales (`assets/assets/fonts`, `assets/fonts`) ; Roboto de repli **absente** du build par défaut (récupérée sur `fonts.gstatic.com`) | Texte de repli manquant hors ligne |
| SDK Firebase web | `Firebase.initializeApp` est **attendu dans `main()`** (commit « Initialiser Firebase au démarrage ») ; `firebase_core_web` injecte `https://www.gstatic.com/firebasejs/12.19.0/firebase-app.js` | **Peut empêcher le démarrage hors ligne** (échec du chargement du script ; comportement exact non mesuré avant la correction) alors que rien n'utilise encore Firebase. **Corrigé en FB5a** : voir « SDK Firebase web servi en local (FB5a) » |
| drift web | `sqlite3.wasm` (3.5.2) et `drift_worker.js` servis par l'application (`web/`), ouverture paresseuse, `DriftStorageStatus` (durable ou mémoire) | Fonctionne hors ligne **si** ces deux fichiers sont en cache ; stockage OPFS ou IndexedDB selon le navigateur, non effacé par la coupure du réseau |
| Catalogue, diagrammes, fiches | assets Flutter (`assets/assets/catalogue`, `diagrammes`, `fiches`), lus **à la demande** par l'application | Un cache « à l'usage » ne suffirait pas : une séance jamais ouverte avant la coupure serait absente |
| `manifest.json` | Modèle Flutter : nom « billard_cfa », couleur `#0175C2` (bleu Flutter), `portrait-primary`, icônes **par défaut de Flutter** | Installable mais au mauvais nom, mauvaise couleur, **orientation bloquée en portrait** (incompatible avec le plein écran d'U3 en paysage), mauvaise icône |
| `index.html` | `lang` absent, pas de `viewport`, nom `billard_cfa` | Accessibilité et installation iOS dégradées |
| Déploiement | `firebase-hosting-merge.yml` / `-pull-request.yml` : `flutter build web --release --no-pub` ; `firebase.json` sans en-têtes | Aucun contrôle du résultat ; le service worker serait mis en cache HTTP 1 h par défaut |

## 2. Risques et décisions

**Décisions** (justifiées dans l'ADR 0018) :

1. **Service worker maison** (`app/web/offline_sw.js`), enregistré par
   `app/web/offline.js`. Celui de Flutter est écarté : obsolète et sans cache.
   `flutter_bootstrap.js` est fourni par le dépôt et **ne passe aucun réglage
   de service worker** (sinon Flutter enregistrerait le sien, qui désinscrit le
   nôtre).
2. **Précache versionné, « cache d'abord »**. `scripts/pwa.dart stamp` (après
   le build) liste les fichiers du build, calcule une empreinte et l'écrit
   dans `offline_sw.js` : le fichier change à chaque version, ce qui déclenche
   la mise à jour par le navigateur. Cache par version
   (`cfa-<empreinte>`) ; installation atomique (un fichier manquant fait
   échouer l'installation, l'ancienne version reste). 129 fichiers, 21,1 Mo
   non compressés, dont 12,3 Mo de CanvasKit (variantes complète et Chromium ;
   les moteurs WebAssembly et la variante `webparagraph` sont exclus : le build
   est en JavaScript et l'application n'active pas `preferWebParagraph`). Tout
   fichier non précaché demandé ensuite est gardé après un premier chargement
   réussi.
3. **CanvasKit servi par l'application** : `--no-web-resources-cdn` (inclut
   aussi Roboto de repli). Recette unique : `scripts/build_web.sh` (CI,
   déploiement, local), qui enchaîne build, `stamp` et `verify`.
4. **Mise à jour sans casser la saisie** : une nouvelle version s'installe en
   arrière-plan et **reste en attente** ; la page ouverte garde les fichiers
   avec lesquels elle a démarré. Elle n'est activée que sur demande de
   l'utilisateur (message `SKIP_WAITING` puis rechargement) ou quand plus aucun
   onglet n'utilise l'ancienne. Vérification toutes les heures et au retour au
   premier plan (`registration.update()`).
5. **Bannière « nouvelle version disponible »** (livrée) : port
   `AppUpdateSource` (`shared/lib`), implémentation web par le pont
   `window.cfaOffline` de `offline.js`, aucune implémentation sur mobile
   (boutiques), `AppUpdateCubit`, `AppUpdateBanner` (`shared/ui`) insérée par
   `AppShell`. Elle ne s'affiche **pas dans le guide « Mener »** et la
   présentation (routes hors cadre, U4) : on ne propose pas un rechargement au
   milieu d'une séance. Elle ne déplace pas l'écran (même position dans
   l'arbre, que la bannière soit là ou non : la saisie en cours est
   conservée, scénario BDD).
6. **Manifeste** : nom « Séances de billard » (celui de l'application, fr),
   nom court « Billard », `lang: fr`, `display: standalone`,
   `orientation: any`, couleurs du thème (`theme_color` = `primary` clair
   `#1964AF`, `background_color` = `surface` clair `#F7F9FC`, contrôlé par
   `scripts/pwa.dart check`), icônes `any` et `maskable` 192 et 512 générées
   par `scripts/generate_pwa_icons.dart` (bille noire sur tapis bleu ; zone
   de sécurité des icônes maskable respectée ; le logo FFB reste retiré, décision
   UX Q2). `index.html` : `lang="fr"`, `viewport`, `theme-color`, balises
   iOS.
7. **Hébergement** : `firebase.json` envoie `Cache-Control: no-cache` pour
   `offline_sw.js`, `offline.js`, `index.html`, `manifest.json`,
   `flutter_bootstrap.js` et `/`. Les autres fichiers sont invalidés par la
   version du précache (installation avec `cache: 'reload'`).
8. **Stockage durable** : `offline.js` demande `navigator.storage.persist()`
   (sans effet là où l'API est absente). Le `DriftStorageStatus` existant
   continue d'avertir quand la base n'est qu'en mémoire.

**Firebase (ne pas contredire H5).** `main()` lance `Firebase.initializeApp`
**sans l'attendre** et absorbe son échec (`startFirebase`, testé) ; depuis FB2
c'est l'`AuthCubit` qui attend `FirebaseStartup.ready`. Le SDK web n'est plus
chargé depuis `gstatic.com` depuis FB5a (section suivante). Le garde-fou
`pwa.dart check` interdit toute URL externe dans `index.html` (hors les clés de
la carte d'import), `offline.js`, `offline_sw.js` et `flutter_bootstrap.js`, pas
dans le code Dart.

### SDK Firebase web servi en local (FB5a, 2026-10-19, B7 levé)

- **Mécanisme** : `firebase_core_web` charge le SDK par
  `import(<URL absolue gstatic>)` ; l'URL est écrite en dur dans le plugin
  (seule la version est réglable) et les bundles s'importent entre eux par
  cette même URL. Une **carte d'import** (`<script type="importmap">` de
  `web/index.html`, avant tout autre script) redirige les trois URL
  (`firebase-app.js`, `firebase-auth.js`, `firebase-firestore-pipelines.js`)
  vers `web/firebasejs/<version>/`. Aucun fork ni modification du plugin.
- **Copies épinglées** : octet pour octet celles de gstatic (paquet npm
  `firebase@<version>`), `web/firebasejs/manifest.json` (version, SHA-256).
  Précachées par le service worker comme tout fichier de `web/` (le build
  ajoute environ 1 Mo non compressé).
- **Garde-fous** : `dart run scripts/sync_firebase_sdk.dart --check` (dans
  `check.sh --fast`, hors ligne) : version = celle de `supportedFirebaseJsSdkVersion`
  du plugin résolu, empreintes, carte exacte, aucun import interne non couvert ;
  `dart run scripts/sync_firebase_sdk.dart` met à jour (a besoin de `npm`).
  `pwa.dart check` (clés de la carte = URL du SDK, valeurs locales) et `verify`
  (fichiers au build et au précache). La fumée du build compilé
  (`scripts/web_smoke.sh`) et le parcours navigateur refusent `gstatic.com` et
  exigent que les trois fichiers soient servis par l'application.
- **Liste blanche réseau** (hôtes du navigateur hors l'application) :
  `identitytoolkit.googleapis.com`, `securetoken.googleapis.com` (Auth),
  `firestore.googleapis.com`, `www.google.com/images/cleardot.gif` (Firestore).
- **Limites** : navigateur sans cartes d'import (Safari avant 16.4) : retombe sur
  gstatic.com en ligne ; non exercé ici. Une mise à jour de `firebase_core_web`
  change la version attendue : `--check` échoue jusqu'à la synchronisation.

### Persistance hors ligne de Firestore, cache et pastille (FB5a)

- Persistance **activée explicitement** (`Settings(persistenceEnabled: true,
  webPersistentTabManager: WebPersistentMultipleTabManager())`, après
  l'initialisation et avant `useEmulators`) : le web ne la fournit pas par défaut.
- **Cache vidé** à la déconnexion voulue et quand un autre compte se connecte
  (`LocalDataGuard`, `LocalDataCache`) ; la page se recharge ensuite (web).
  Déconnexion refusée tant que des envois sont en attente, sauf confirmation.
  Session perdue autrement : cache conservé (écritures hors ligne possibles).
- **Déconnexion et envois non envoyés** : la garde interroge le **SDK** (`waitForPendingWrites` borné), pas un compteur en mémoire : une écriture
  hors ligne survit à la fermeture de l'application, et la pastille la montre à la réouverture.
- **Effacement raté** (autre onglet qui tient IndexedDB, disque) : la déconnexion aboutit mais le repère « effacement en attente » reste sur
  l'appareil ; l'écran de connexion le dit avec « Réessayer l'effacement », le démarrage suivant et toute connexion (même compte compris)
  retentent avant de lire quoi que ce soit.
- **Plusieurs onglets** : la suppression du cache est bornée (5 s) ; l'onglet qui perd sa session quand un autre a vidé le cache se recharge.
- **Natif non prouvé** : `terminate` puis `clearPersistence` puis lecture n'est exercé par aucun test (pas d'appareil dans les garde-fous) ;
  `reopen` réapplique les réglages. À éprouver à la main sur Android et iOS avant la bascule.
- **Pastille** « À jour / Envoi en attente (n) / Hors ligne » (`SyncStatusCubit`
  sur `SendStatus` et `ConnectivityStatus`). Le réseau n'est connu que sur le web
  (`navigator.onLine`) ; natif : toujours « en ligne ».
- **Écritures hors ligne** : cache d'abord, serveur ensuite (`cachedOrGet`) ; seul « hors ligne » vaut « absent du cache » ; pour
  les blocs acquis, bilans et « Vu » ; saisie **libre** créée hors ligne ; saisie
  **liée** à une séance du catalogue : impossible hors ligne (transaction), reste
  de FB5b. Détail : ADR 0024, notes FB5a.

**Risques résiduels.**

| Risque | Gravité | Traitement |
|---|---|---|
| Glyphes absents d'Exo2 (symboles, émojis) : Flutter les demande à `fonts.gstatic.com` | faible | Non déclenché sur les écrans parcourus ; hors ligne ils s'affichent en carré. Les pictogrammes de l'interface sont dessinés (`NavIcon`, `PassDots`) ou en MaterialIcons local. À surveiller si du texte avec émoji est ajouté |
| Effacement du stockage par le navigateur (iOS Safari non installé : 7 jours sans visite ; Android : espace faible) | élevée si non traité | `persist()`, avertissement de stockage non durable existant, rappel de sauvegarde (U7), installation sur l'écran d'accueil recommandée (guide). **Non vérifié sur iOS** |
| Premier chargement : 21 Mo (≈ 6 à 7 Mo compressés) | moyenne | Une seule fois par version ; le texte du guide demande de charger en Wi-Fi. Pas de précache partiel : une séance manquante hors ligne est pire |
| Deux versions en circulation (onglet ancien, cache neuf) | moyenne | Cache par version supprimé seulement à l'activation de la suivante ; activation à la demande suivie d'un rechargement immédiat |
| Mise à jour pendant une séance guidée (état en mémoire perdu au rechargement) | moyenne | Bannière absente du guide ; activation toujours à la demande ; consigne dans le guide de l'animateur |
| Service worker en développement (`flutter run`) | faible | Non stampé : le worker se désinscrit et ne met rien en cache |
| Mise à jour du SDK Flutter : moteurs ou noms de fichiers différents | faible | `pwa.dart verify` exige les fichiers indispensables, `useLocalCanvasKit` et un chargeur sans réglage ; il échoue en CI sinon |

## 3. Tests et garde-fous

| Niveau | Quoi | Où |
|---|---|---|
| Sources | manifeste (champs, couleurs, icônes présentes, de la bonne taille, `any` et `maskable`, couleur de thème = thème), `index.html`, `flutter_bootstrap.js` sans réglage de service worker, marqueurs du worker, aucune URL externe | `dart run scripts/pwa.dart check` (dans `scripts/check.sh --fast`) ; `app/test/tool/pwa_test.dart` (29 cas, dans un faux dépôt) |
| Icônes | PNG régénérés à l'identique | `dart run scripts/generate_pwa_icons.dart --check` (idem) |
| Build | liste de précache = contenu du build, empreinte à jour, fichiers indispensables (moteur, wasm, worker drift, polices, catalogue, schémas, séances), CanvasKit local, chargeur sans réglage | `dart run scripts/pwa.dart verify` (dans `scripts/build_web.sh`, donc CI `build-web`, déploiement live et prévisualisation) |
| Logique Dart | `AppUpdateCubit` (visible, « Plus tard », version retirée puis remplacée), `WebAppUpdateSource` (pont), `startFirebase` | `test/unit/features/app_update`, `test/unit/app` |
| Comportement | `test/bdd/app_update.feature` (9 scénarios : bannière absente, déjà en attente, installée en cours d'usage, fr, « Plus tard », « Mettre à jour », saisie conservée, 390 et 320 dp) | BDD |
| Navigateur réel | voir § 4 | Playwright, à la main (non automatisé) |

Non automatisé : le service worker (JavaScript) n'a pas de test unitaire ; il
est couvert par le parcours Playwright et par `verify`. Automatiser ce parcours
en CI demanderait Playwright (Node) dans le dépôt : non décidé.

## 4. Parcours navigateur (Playwright, Chromium)

Fait le 2026-10-16 sur le build de l'arbre de travail, servi par `http.server`.

1. Première visite, réseau actif : service worker `activated`, contrôle de la
   page, cache `cfa-<empreinte>` de 129 entrées.
2. Création d'un élève « Léa » (public enfants) ; `navigator.storage.persisted()`
   = vrai.
3. Réseau coupé (`setOffline`) puis **serveur arrêté** (preuve : une requête
   hors cache échoue en « erreur réseau ») : rechargement de la racine, de
   `#/students` : l'application s'ouvre, « Léa » est listé, la fiche de Léa
   s'ouvre (données drift relues).
4. Présentation plein écran d'U3 hors ligne
   (`#/catalogue/demi-bille-1/presentation?audience=children&step=5`, 1280 ×
   800) : schéma affiché, `document.fullscreenElement` non nul après le clic
   sur « Plein écran ».
5. Installabilité : `Page.getAppManifest` sans erreur, `Page.getInstallabilityErrors`
   vide, scope et script du service worker attendus.
6. Mise à jour : version A active, saisie « Zoé » en cours dans le formulaire
   d'élève ; version B déployée (fichier modifié, nouvelle empreinte) ;
   `registration.update()` → B installée **en attente**, A toujours servie, deux
   caches, bannière affichée, champ intact ; « Mettre à jour » → rechargement,
   B servie, ancien cache supprimé, bannière disparue.

Captures : hors dépôt (dossier temporaire de session).

## 5. Non vérifié

- **iPhone / iPad Safari** : service worker, `persist()`, installation par
  « Sur l'écran d'accueil », durée de vie du stockage. Pas d'appareil
  disponible. Le plein écran n'existe pas sur iPhone (entrée masquée, U3).
- **Android, PWA installée** : installation réelle (invite Chrome),
  lancement hors ligne depuis l'icône, orientation libre, sortie du plein écran
  décidée par le système.
- **Firefox, Safari bureau** : variante CanvasKit « complète » (précachée mais
  jamais chargée en test), OPFS partiel.
- Mise à jour réelle sur Firebase Hosting (ETag, en-têtes `no-cache`) : testée
  avec `http.server` seulement.
- Robustesse sur très gros volumes de données hors ligne.

## 6. Restes

- Décision FB1 / FB5 sur le SDK Firebase servi localement (voir plus haut).
- Automatiser le parcours hors ligne (Playwright en CI) si le besoin se
  confirme.
- Sortie du mode immersif décidée par le système sur Android natif
  (`SystemChrome.setSystemUIChangeCallback`, reste d'U3) : hors périmètre web.
