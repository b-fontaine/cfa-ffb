# AGENTS.md

Instructions pour tout agent de code (Claude Code, Codex, Cursor, Gemini CLI, Copilot…). Ce fichier est la **source de vérité** ; `CLAUDE.md` l'importe. Langue du projet : **français** (documentation, messages, séances) ; identifiants de code en anglais.

## Le projet en deux volets

1. **Base de connaissances et conception de séances de billard** (Blackball, niveau technique 1) pour animateurs FFB — `docs/knowledge/`, `seances/`.
2. **Application Flutter** d'aide à la préparation de séances — `app/` (Clean Architecture + Feature-Sliced Design, BLoC, BDD/TDD).

## Décisions de cadrage `[U]`

- **Discipline : Blackball uniquement.**
- **Suivi des élèves** sur la saison (mêmes élèves) pour adapter les cours : résultats d'exercices, courbes, recommandations déterministes.
- Passage enfants → cours adultes dès 16–17 ans selon maturité (décision manuelle) : `docs/knowledge/05-seances/passage-enfants-adultes.md`.
- Validation d'un exercice : plusieurs passages réussis (5 le plus souvent, réglable). Ordre : rebond sur bande avant rejet naturel.
- Persistance : **Firestore est la source de vérité** (comptes, clubs, rôles, synchronisation ; plan Spark, base en `europe-west9`), derrière les interfaces de repository ; drift est retiré une fois la migration (FB7) livrée ; reste local à l'appareil : séance en cours, club actif, préférences (port clé/valeur local `KeyValueStore`, `shared_preferences`, lot FB2). Décision : [ADR 0024](docs/engineering/adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), qui amende l'ADR 0001 ; **aucune base de production avec de vrais élèves avant AIPD et textes juridiques validés** (« à valider » par la fédération ou un DPO).
- Design system : Widgetbook, thème évoquant la FFB et le Blackball.

## Cartographie

| Chemin | Contenu |
|--------|---------|
| `docs/sources/` | PDF fournis. **Rang 1. Ne jamais modifier.** |
| `docs/knowledge/` | Connaissances billard indexées (`README.md` = entrée) |
| `docs/knowledge/03-exercices/diagrammes/` | Positions des billes des PDF transcrites en YAML (`FORMAT.md`, `README.md` = index) ; outil : `app/tool/diagrammes.dart` |
| `docs/engineering/` | Architecture, tests, garde-fous (`README.md` = entrée) |
| `seances/` | Séances générées (modèle : `docs/knowledge/05-seances/modele-seance.md`) |
| `app/` | Application Flutter |
| `scripts/` | Garde-fous déterministes (`check.sh`, couverture, validations) |
| `.agents/skills/`, `.agents/agents/` | Skills et sous-agents (source canonique, outil-agnostique) |
| `.github/workflows/` | CI |

## Volet connaissances / séances

### Hiérarchie des sources (impérative)

1. `docs/sources/*.pdf` `[S]` — font foi.
2. ffbillard.com `[FFB]`.
3. Autres sites `[Web]`.
4. `[Prop]` : proposition non sourcée, à signaler explicitement.

En cas de conflit, la source de rang le plus élevé gagne. Lire `docs/knowledge/00-provenance-et-fiabilite.md` avant de produire du contenu.

### Contraintes de séance

| Public | Durée | Notes |
|--------|-------|-------|
| Enfants | **90 min** | 1 notion, explications courtes, jeu important |
| Adultes | **120 min** | 1 notion + rappel, analyse plus fine |

Invariants : une notion principale ; ordre notion/initiation → entraînement → jeu ; exercices variés, chacun ≤ 2 passages ; somme des blocs = durée ; chaque exercice cite sa fiche ; taux de réussite repris de la source ; toute durée interne est `[Prop]`.

Interdits : inventer un exercice « officiel », présenter une adaptation non sourcée comme règle fédérale, modifier `docs/sources/`, transposer du carambole/américain au Blackball sans le dire.

### Skills disponibles (`.agents/skills/`)

| Skill | Usage |
|-------|-------|
| `seance-planifier` | Produire une séance enfants (90) ou adultes (120) |
| `seance-adapter` | Adapter un exercice / une séance à un public |
| `seance-cycle` | Planifier une progression sur plusieurs séances |
| `seance-verifier` | Contrôler une séance (checklist + validateur) |
| `connaissances-enrichir` | Ajouter une source à la base avec provenance (index des diagrammes à jour) |

## Volet application Flutter

### Règles non négociables

1. **BDD puis TDD, toujours** : écrire d'abord un scénario `.feature` (bdd_widget_test), le voir échouer, puis cycles TDD unitaires rouge → vert → refactor. Aucun code de production sans test qui l'a exigé.
2. **Architecture FSD + Clean** : couches `app > pages > widgets > features > entities > shared`, imports uniquement vers le bas ; jamais entre slices d'une même couche ; `domain` en Dart pur. Détails : `docs/engineering/architecture.md`.
3. **Pile imposée** : flutter_bloc, get_it + injectable, freezed, go_router, bdd_widget_test, gen-l10n (fr + en), firebase_core, firebase_auth, cloud_firestore (ADR 0024) ; `shared_preferences` (état local d'appareil, ADR 0024 décision 23 ; introduite au lot FB2 derrière le port `KeyValueStore`) ; outillage des émulateurs : Node LTS, Java 21, `firebase-tools` épinglé (`package.json` + verrou). Ne pas introduire d'alternative sans décision écrite.
4. **i18n** : aucune chaîne utilisateur en dur ; clés identiques en `fr` et `en` (fr par défaut).
5. **Garde-fous** : ne jamais contourner (`--no-verify`, `// ignore`, abaisser un seuil, supprimer un test). Un garde-fou qui échoue se corrige à la racine. Les tests des règles Firestore contre l'émulateur en font partie : un prérequis manquant (Node, Java) est un échec explicite, jamais un skip ; `firestore.rules` reste en refus par défaut tant que les règles par rôle (FB3) n'ont pas leurs tests.
6. **Fichiers générés** (`*.g.dart`, `*.freezed.dart`, `*.config.dart`) : ne jamais éditer à la main ; régénérer avec build_runner.

### Commandes (depuis la racine du dépôt)

| Besoin | Commande |
|--------|----------|
| Installer les hooks git | `scripts/setup.sh` |
| Vérification rapide (format, analyse, architecture) | `scripts/check.sh --fast` |
| Vérification complète (tests, couverture, l10n, Widgetbook) | `scripts/check.sh --full` |
| Règles Firestore contre l'émulateur (Node >= 24.12, Java >= 21, `npm ci` ; échec explicite sinon) | `scripts/rules_test.sh` (aussi dans `scripts/check.sh --full`) |
| Parcours navigateur : application (debug) + émulateurs Auth et Firestore + graine (Chrome, Flutter en plus) | `scripts/emulator_e2e.sh` (aussi dans `scripts/check.sh --full`) |
| Graine des émulateurs (comptes et club « Démo » ; refuse tout hôte non local et tout projet hors `demo-…`) | `task emulators` puis `scripts/seed_emulator.mjs` |
| Build web de production (CanvasKit local, service worker hors ligne, contrôle du résultat) | `scripts/build_web.sh` |
| Copier / vérifier le SDK web Firebase servi en local (copies épinglées, carte d'import) | `dart run scripts/sync_firebase_sdk.dart [--check]` |
| Valider les séances | `dart run scripts/validate_seances.dart` |
| Copier / vérifier le catalogue (asset = `docs/knowledge`) | `scripts/sync_catalogue.sh [--check]` |
| Copier / vérifier les diagrammes à table (asset = `docs/knowledge`) | `scripts/sync_diagrammes.sh [--check]` |
| Copier / vérifier les séances du catalogue (asset = `docs/knowledge/05-seances/catalogue`) | `scripts/sync_fiches.sh [--check]` |
| Valider les séances du catalogue (FORMAT.md § 7) | `cd app && dart run tool/fiches.dart [--complete]` |

La CI exécute **les mêmes scripts** : voir `docs/engineering/quality-gates.md`.

### Skills et agents de développement

| Nom | Type | Rôle |
|-----|------|------|
| `dev-feature` | skill | Créer une feature de bout en bout (BDD → TDD → FSD) |
| `dev-bdd` | skill | Écrire un scénario Gherkin + steps bdd_widget_test |
| `dev-tdd` | skill | Cycle rouge/vert/refactor unitaire |
| `dev-quality-gates` | skill | Exécuter et interpréter les garde-fous |
| `architecte-fsd` | agent (lecture seule) | Revue d'architecture indépendante |
| `testeur-bdd` | agent (lecture seule) | Revue de la qualité des tests |
| `concepteur-seance` | agent | Rédige une séance |
| `relecteur-pedagogique` | agent (lecture seule) | Relit une séance, séparé de l'auteur |

### Séparation des rôles

Ne pas relire ce que l'on vient d'écrire dans le même contexte : la relecture d'une séance ou d'une feature se fait par l'agent de revue dédié.

## Définition de « terminé »

- Code : `scripts/check.sh --full` vert, scénario BDD couvrant le comportement, tests unitaires, aucune chaîne en dur, documentation à jour.
- Séance : `dart run scripts/validate_seances.dart` vert, checklist `modele-seance.md` cochée, sources citées.
- Aucun `TODO`, test ignoré (`skip`, `solo`), stub ou branche non implémentée laissé en place.

## Commits

Messages en français, impératifs, courts ; un commit = une intention. Ne pas committer sans demande explicite de l'utilisateur.
