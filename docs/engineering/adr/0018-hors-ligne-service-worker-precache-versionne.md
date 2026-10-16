# ADR 0018 — Hors ligne : service worker maison, précache versionné, mise à jour à la demande

- Statut : **accepté et implémenté** (2026-10-16). Plan : `../hors-ligne-plan.md`.
  Lot **15** de la [roadmap](../roadmap.md). Complète l'[ADR 0001](0001-persistance-locale-drift.md)
  (drift web : `sqlite3.wasm`, `drift_worker.js`) et l'[ADR 0017](0017-plein-ecran-port-controleur-partage.md)
  (plein écran en PWA). Ne modifie pas la décision Firebase de l'horizon H5.

## Contexte

L'animateur utilise l'application en salle, souvent sans réseau fiable. Le
build web de Flutter 3.47.7 ne le permettait pas : son service worker est un
résidu qui se désinscrit lui-même, CanvasKit est chargé depuis le CDN de
Google, la police de repli aussi, et `Firebase.initializeApp` (attendu dans
`main()`) charge le SDK web depuis `gstatic.com`. Le manifeste était celui du
modèle Flutter (nom, couleur, icône, orientation bloquée en portrait).

## Décision

1. **Service worker maison** (`app/web/offline_sw.js`) enregistré par
   `app/web/offline.js`. `flutter_bootstrap.js` est fourni par le dépôt et
   n'enregistre pas le service worker de Flutter.
2. **Précache versionné, « cache d'abord »**, produit après le build par
   `scripts/pwa.dart stamp` : liste des fichiers du build et empreinte
   (FNV-1a 64 bits, détection de changement) écrites dans `offline_sw.js` ; un
   cache `cfa-<empreinte>` par version ; installation atomique. L'application
   entière est précachée (catalogue, schémas et séances compris : lus à la
   demande, ils manqueraient sinon).
3. **CanvasKit local** : `flutter build web --no-web-resources-cdn`. Une seule
   recette de build, `scripts/build_web.sh` (build, `stamp`, `verify`), pour la
   CI et les deux déploiements ; `scripts/pwa.dart check` (sources) est dans
   `scripts/check.sh --fast`.
4. **Une nouvelle version n'est jamais activée d'office** : elle reste en
   attente ; la page ouverte garde ses fichiers. L'activation est demandée par
   l'utilisateur (bannière sobre, port `AppUpdateSource`) ou a lieu quand les
   onglets sont fermés. La bannière est absente du guide et de la présentation.
5. **Firebase non bloquant** : `main()` lance `Firebase.initializeApp` sans
   l'attendre (`startFirebase`) ; son échec est absorbé. Aucune autre
   conséquence tant que rien ne l'utilise ; FB1 et FB5 reprendront la question
   du SDK servi localement et de l'état de synchronisation.
6. **Manifeste et icônes** : nom, couleurs du thème, `display: standalone`,
   `orientation: any`, `lang: fr`, icônes `any` et `maskable` générées par un
   script déterministe (`scripts/generate_pwa_icons.dart`).

## Alternatives rejetées

- **Service worker de Flutter** : obsolète (retiré dans une version à venir),
  sans cache aujourd'hui.
- **Workbox ou paquet npm** : Node dans la chaîne de build pour un cache
  d'une centaine de fichiers ; le générateur Dart tient en quelques dizaines de
  lignes et se teste dans la machine virtuelle Dart.
- **Cache à l'usage seulement** : une séance jamais ouverte avant la coupure
  serait absente hors ligne.
- **`skipWaiting` automatique** : remplacerait les fichiers sous une page
  ouverte (saisie en cours, état de séance en mémoire perdu).
- **Servir le SDK Firebase en local dès maintenant** : fichier épinglé à
  maintenir pour un SDK que rien n'utilise encore.

## Conséquences

- Premier chargement : 21 Mo non compressés, une fois par version. Un build
  non stampé (`flutter run`, `flutter build web` seul) n'a pas de cache : le
  worker se désinscrit.
- Mettre à jour Flutter peut changer les noms de fichiers du moteur :
  `scripts/pwa.dart verify` échoue alors en CI plutôt qu'en salle.
- Le service worker n'a pas de test unitaire (JavaScript) : il est couvert par
  `verify` et par le parcours Playwright documenté dans le plan. Non vérifié :
  iPhone Safari, Android avec PWA installée.
- Tout fichier ajouté à `web/` est précaché automatiquement ; tout fichier
  généré par le build l'est aussi.
