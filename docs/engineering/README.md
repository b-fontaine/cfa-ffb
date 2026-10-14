# Ingénierie — index

Documentation technique du projet Flutter `app/` (assistant de préparation de
séances de billard). Toute modification de code doit respecter ces pages ; les
règles sont **vérifiées automatiquement** (voir [quality-gates.md](quality-gates.md)).

| Page | Contenu |
|---|---|
| [architecture.md](architecture.md) | Clean Architecture + Feature-Sliced Design : couches, règles d'import, arbre de dossiers, ajouter une feature pas à pas |
| [testing.md](testing.md) | Cycle BDD (bdd_widget_test) puis TDD (bloc_test, mocktail), conventions de nommage |
| [quality-gates.md](quality-gates.md) | Garde-fous déterministes : commande, où ils tournent (hook git, hook agent, CI) |
| [i18n.md](i18n.md) | Localisation fr/en (gen-l10n, ARB), ajout d'une langue ou d'une clé |
| [design-system.md](design-system.md) | Thème FFB/Blackball, jetons, composants `shared/ui`, Widgetbook, ajouter un composant + use case |
| [roadmap.md](roadmap.md) | Lots restants par horizon (clôture, boucle de saison, usage en salle, contenu, distribution) et ordre recommandé |

## Démarrage rapide

```bash
scripts/setup.sh          # hooks git + dépendances + code généré
scripts/check.sh --fast   # format, analyse, architecture, séances (~5 s)
scripts/check.sh --full   # + l10n, tests, couverture, Widgetbook
cd app && flutter run     # lancer l'application
cd widgetbook && flutter run -d chrome   # catalogue du design system
```

Pile : Flutter 3.47.7 (Dart 3.13), flutter_bloc, get_it + injectable, freezed,
go_router, gen-l10n, drift (SQLite, [ADR 0001](adr/0001-persistance-locale-drift.md)),
bdd_widget_test, bloc_test, mocktail ; design system
validé dans Widgetbook 3.x (projet séparé `widgetbook/`).
Plateformes cibles : Android et iOS (priorité), tablettes, macOS/Windows/Linux, web.
