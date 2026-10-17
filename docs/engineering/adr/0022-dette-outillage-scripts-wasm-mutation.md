# ADR 0022 — Dette d'outillage (lot 23) : `scripts/` devient un paquet analysé comme l'application ; `--wasm` évalué et non adopté ; mutation testing toujours hors périmètre

- Statut : **accepté et livré** (2026-10-17), lot 23 de la [feuille de route](../roadmap.md). Aucune décision de produit n'est en jeu : tout ce qui suit se défait sans toucher aux données ni à l'application livrée.
- Contexte : trois dettes d'outillage étaient listées sans arbitrage : `scripts/` sans `pubspec.yaml`, build web `--wasm`, mutation testing retiré le 2026-10-12.

## Décision

### 1. `scripts/` est un paquet Dart (fait)

- `scripts/pubspec.yaml` (paquet `billard_cfa_scripts`, `publish_to: none`, SDK `^3.13.5` comme l'application) et `scripts/analysis_options.yaml` qui inclut `package:very_good_analysis` avec les mêmes options strictes que `app/`. **Aucune dépendance de production** ; la seule dépendance de développement est `very_good_analysis ^11.0.0`, **déjà verrouillée et utilisée par `app/`** (même version, aucun paquet nouveau dans le dépôt). `scripts/pubspec.lock` est versionné comme `app/pubspec.lock`.
- Avant : `dart analyze scripts` tournait avec les règles par défaut, donc sans les règles du reste du dépôt (accolades obligatoires, 80 colonnes, guillemets simples, une déclaration par ligne…). Après : 21 écarts relevés puis **corrigés dans le code** (aucun `// ignore`).
- Une seule règle est désactivée, avec sa raison dans le fichier : `avoid_js_rounded_ints`, car l'empreinte FNV-1a 64 bits de `pwa.dart` exige des entiers 64 bits exacts et les scripts ne tournent que sur la VM Dart (jamais compilés en JavaScript). `public_member_api_docs` est désactivée comme dans `app/` (documentation publique en français).
- `scripts/check.sh` exécute `dart pub get` (avec `--enforce-lockfile` en CI) puis `dart analyze --fatal-infos .` dans `scripts/` ; l'étape reste en lecture seule sur les sources (seuls `.dart_tool/`, ignoré, et un `pubspec.lock` inchangé sont touchés). Les scripts restent lancés depuis la racine (`dart run scripts/pwa.dart …`) : leur déduction de la racine du dépôt (`Platform.script`) ne change pas, et les tests de `app/test/tool/` qui les rejouent dans une copie du dépôt restent verts.
- Écartée : **espace de travail pub** (`workspace:` à la racine). Il déplacerait `app/pubspec.lock` à la racine et toucherait à la résolution de l'application, du Widgetbook et du cache CI, pour un gain nul ici.

### 2. Build `--wasm` : évalué, **non adopté** (2026-10-17)

Mesures (`flutter build web --wasm --release --no-pub --no-web-resources-cdn`, Flutter 3.47.7) :

| Point | Résultat |
|---|---|
| Compilation | **réussit**, sans avertissement d'incompatibilité (`dart:js_interop` de l'impression PDF, drift, `file_picker`, `pdf` compatibles), 71 s contre 47 s en JavaScript |
| Contenu | le build embarque **les deux** variantes : `main.dart.js` (5,0 Mo, repli) **et** `main.dart.wasm` (4,7 Mo) + `main.dart.mjs` + `canvaskit/skwasm.wasm` (3,4 Mo) + `skwasm.js` |
| Exécution (Chromium, Playwright) | l'application démarre en WebAssembly (rendu `skwasm`), drift et l'export de sauvegarde fonctionnent |
| Multithreading | **absent** : Flutter avertit que Skwasm ne passe en multi-fil que si la page est « cross-origin isolated » (en-têtes COOP/COEP) ; sans eux, `crossOriginIsolated` vaut `false` et Skwasm tourne **mono-fil** |

Raisons de ne pas l'adopter maintenant :

1. **Aucun gain démontré** : sans COOP/COEP le rendu est mono-fil ; aucune mesure ne montre un problème de performance du build actuel.
2. **COOP/COEP ne sont pas gratuits** : ils peuvent casser les fenêtres contextuelles de Firebase Auth (voir [recherche drift](../research/persistance-locale.md), lignes web et point d'attention) alors que l'horizon H5 introduit l'authentification. Ils concernent aussi le service worker maison et toute ressource tierce (il n'y en a aucune aujourd'hui, garanti par `pwa.dart check`).
3. **Le précache hors ligne devrait changer** ([ADR 0018](0018-hors-ligne-service-worker-precache-versionne.md)) : `scripts/pwa.dart` exclut aujourd'hui `skwasm*` et `wimp*` ; adopter `--wasm` impose de précacher `main.dart.wasm`, `main.dart.mjs` et `skwasm.*` (≈ +8 Mo au précache) **en gardant** `main.dart.js` (navigateurs sans WasmGC), de réécrire `_required` et ses tests, et de revérifier le hors-ligne sans réseau sur les deux chemins. Le faire à moitié casserait l'usage hors ligne.
4. Les dépendances Firebase de H5 ne sont pas encore choisies : leur compatibilité WebAssembly est à revalider à ce moment-là.

**Condition de réexamen** : après l'ADR de l'horizon H5 (choix de l'authentification, donc des en-têtes) **et** si une mesure de performance (démarrage ou rendu sur un appareil modeste) le justifie. Le travail alors nécessaire est celui du point 3 ci-dessus.

### 3. Mutation testing : décision **maintenue**, réévaluée (2026-10-17)

- État mesuré : 580 fichiers de production (≈ 56 900 lignes hors code généré), 431 fichiers de test. Au retrait (2026-10-12) l'exécution dépassait plusieurs heures pour ≈ 1 250 mutants avec la suite complète par mutant ; la base a grossi depuis (lots 9 à 14), donc l'estimation ne s'améliore pas.
- **Pas de réintroduction en garde-fou** : un outil exécuté par la CI ou par `check.sh` ajouterait des heures ou un seuil arbitraire, ce qu'interdit la politique des garde-fous (déterministes, rapides, jamais contournés).
- **Ce qui remplace le garde-fou, et qui est appliqué lot après lot** : la mutation **ciblée à la main** sur les fichiers touchés (un mutant à la fois, suite du fichier seulement, mutation restaurée, rouge constaté), tracée dans chaque plan ([séance en cours](../seance-en-cours-plan.md), [export PDF](../export-pdf-plan.md), correctif de ce lot). C'est la pratique exigée par `AGENTS.md` (« rouge constaté ou mutation restaurée »).
- **Condition de réexamen** : un outil capable de ne muter que les fichiers modifiés et de ne lancer que les tests qui les couvrent, avec un temps total mesuré inférieur à quelques minutes, en tâche manuelle ou nocturne et **non bloquante**. Rien n'est ajouté à `pubspec.yaml` tant que ce critère n'est pas rempli.

## Conséquences

- `quality-gates.md` : étape « Analyse des scripts Dart » mise à jour ; section « Hors périmètre actuel » complétée.
- `roadmap.md` : lot 23 soldé (reste : réexamen conditionnel de `--wasm` et de la mutation, ci-dessus).
- Risque : `dart pub get` dans `scripts/` suppose un accès à pub.dev au premier lancement ; le paquet est déjà dans le cache pub après `scripts/generate.sh`/`flutter pub get` de l'application (même version), et la CI l'a déjà.
