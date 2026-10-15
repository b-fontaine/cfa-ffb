# Tailles du matériel et illustrations « où se placer, où viser, doser » : plan de conception

Statut : **lots A, B et C réalisés, D2 (ligne de départ à 1,6 `[FFB]`) réalisée, D5 réalisé (`contact_height`, 2026-10-15)** (T1 à T7 : module de dimensions, blanche plus petite partout, géométrie de la bille fantôme et des quantités, validateurs, FORMAT, recalcul des positions dérivées ; `CueBallTarget`, `PlayerFigure`, `PowerRatio`, ADR 0005 et migration des séances). **Restent** : la revue séparée du lot T8 (`architecte-fsd`, `testeur-bdd`, `relecteur-pedagogique`), la validation visuelle par l'animateur dans Widgetbook,. D5 est tranché `[U]` (« ajouter », 2026-10-14) et réalisé : type `contact_height` (`ContactHeightView`), `CueSideView.showContact` supprimé, séance `07-bille-pleine-1` ; l'exagération porte sur l'**inclinaison** (×10 = 16,24°, décalage vertical des centres ≈ 18,6 mm à l'échelle de la blanche), pas sur l'écart de rayon (ancien rendu : 13,05°). Écarts à la conception : pas de `FigureColors` (couleurs lues dans `ColorScheme`, `BallColors`, `TableColors`), pas de paramètre `compact` ni d'axe « Centre » sur la cible, `lead_eye` facultatif (déduit de `head_case`), `CueSideView` conservé. Rédigé le 2026-10-13 à la suite de quatre retours de l'utilisateur. Contexte : application V1 non livrée, aucune compatibilité de données à préserver (schéma, assets, YAML se modifient directement). Dimensions de référence : `../knowledge/02-techniques/06-dimensions-du-materiel.md` (non modifié par ce plan). Règles de développement : `AGENTS.md`, skills `dev-feature`, `dev-bdd`, `dev-tdd`, et `architecture.md`, `testing.md`, `quality-gates.md`, `design-system.md`, `i18n.md`.

## 0. Retours de l'utilisateur et réponse

| # | Retour (verbatim abrégé) | Réponse de ce plan | Section |
|---|---|---|---|
| R1 | « Au Blackball, la blanche est plus petite que les autres. Fais bien attention avec toutes les tailles. » | Un module Dart pur, source unique des cotes en mm et en cases ; deux rayons (blanche 24,0 mm, bille de but 25,4 mm) ; bille fantôme, contacts, poches, ligne de départ, procédé dérivés des mm | 1, 2 |
| R2 | « Ton schéma pour se placer n'est pas clair, dessine un personnage » | `PlayerFigure` : personnage schématique de profil (et de dessus), 6 repères numérotés légendés ; remplace `stance_top` | 3.1 |
| R3 | « Pour expliquer où viser, dessine la blanche avec une cible et le point d'impact du procédé » | `CueBallTarget` : blanche de face, cible, marqueur du procédé à l'échelle ; remplace `cue_side` et la moitié droite de `BallContactDiagram` | 3.2 |
| R4 | « Tes 5 niveaux ne sont pas clairs, représente un rapport entre l'amplitude et la vitesse » | `PowerRatio` : plan amplitude × vitesse avec trois zones (doux, moyen, puissant) et exemples placés ; remplace `power_scale`, plus aucun « cran » | 3.3 |

### Décisions proposées (à confirmer par l'utilisateur ou l'animateur)

| Réf. | Décision proposée | Alternative écartée | Pourquoi |
|---|---|---|---|
| D1 | Dessiner **à l'échelle réelle** : 1 case = 925 / 4 = 231,25 mm ; bille de but r = 0,1098 case, blanche r = 0,1038 case ; la convention « r = 0,1 » disparaît | Garder r_o = 0,1 et ne corriger que le rapport (r_c = 0,0945) | L'utilisateur demande de la rigueur « avec toutes les tailles » ; une seule source en mm évite deux conventions ; coût mesuré (revérifié le 2026-10-13 sur les 191 diagrammes transcrits) : 2 paires de billes de but à 0,2195 case passent sous le nouveau seuil 2 r_o = 0,2197 (tangentes à 0,0001 case = 0,03 mm près, précision de transcription 0,01) et 3 billes dépassent la bande de 0,01 case ; le validateur de placement doit donc tolérer 0,01 case (voir 1.3 et 1.4) |
| D2 | **Tranchée le 2026-10-14 : ligne de départ à x = 1,6 `[FFB]`** (réalisée ; constante unique `headString`) | La laisser à 2,0 `[Prop]` | 46 (bornes exclues) à 60 (bornes incluses) des 191 diagrammes transcrits `[S]` ont au moins une bille ou un cercle entre x = 1,6 et x = 2,0 : le changement modifie leur lecture visuelle, mais les positions YAML sont absolues et inchangées. Arbitrage de l'animateur (doc de dimensions § 4) |
| D3 | Le **quart de bille** se mesure par rapport à la blanche : d = r_o + r_c / 2 (fiche n° 7) ; `thin` = 0,95 · s `[Prop]` | « Demi-rayon de la bille de but » | Lecture de la source ; écart de 0,7 mm seulement mais la source le dit explicitement |
| D4 | **Marqueur du procédé** à l'échelle réelle (8,5 mm, soit 0,177 r_c), avec **anneau de visibilité** ajouté pour la projection ; position « haut / bas / côté » à mi-rayon `[Prop]` | Point bleu agrandi sans échelle | Le procédé est 12 fois plus grand que le décalage de contact : à l'échelle il reste lisible, l'anneau le rend visible de loin |
| D5 | Ajouter **en option** une 4e illustration `contact_height` (deux billes inégales au contact, vue de côté, inclinaison exagérée et signalée) | Rien | La fiche n° 4 `[S]` dit « légèrement au-dessus de l'axe horizontal ». **Tranchée le 2026-10-14 `[U]` : ajouter** (réalisée le 2026-10-15, type `contact_height`, § 3.4) |
| D8 | Le personnage de `PlayerFigure` **renverse** la décision de l'ADR 0004 (« Silhouette humaine pour la posture » rejetée, sans risque de représentation d'enfant) : consigner par un **ADR 0005** (ou une mise à jour de l'ADR 0004, section « Alternatives rejetées », et de sa limite « schémas non à l'échelle », ligne 42) avant le lot T5. Garde-fou de conception : pictogramme neutre (pas de visage, de sexe ni d'âge, trait épais, une seule couleur de figure) | Figure réaliste ou différenciée enfant / adulte | La demande de l'utilisateur prime sur l'ADR, mais l'ADR doit rester la trace de la décision et de la raison initiale |
| D6 | **Poches dessinées à 0,33 case d'ouverture** (rayon 0,165) au lieu de 0,28 de rayon actuel | Garder le disque de 0,28 | Les poches sont aujourd'hui 1,7 fois trop grandes ; à contrôler visuellement dans Widgetbook (lisibilité) avant de figer |
| D7 | Échelle de puissance : zones calculées par `amplitude × vitesse` `[Prop]`, niveaux `short / medium / long` et `slow / medium / fast` | Deux curseurs continus | Les séances sont rédigées en mots ; les trois niveaux suffisent pour les deux exemples de la fiche n° 2 et restent écrits au YAML |

---

## 1. Modèle de dimensions (A)

### 1.1 Module `shared/lib/blackball_dimensions.dart`

Dart pur (seul import : aucun, ou `dart:math`), donc compatible avec la règle « `domain` / `shared/lib` sans Flutter ». C'est la **seule** déclaration de cote du dépôt.

```dart
/// Cotes du matériel de Blackball (docs/knowledge/02-techniques/06-dimensions-du-materiel.md).
abstract final class BlackballDimensions {
  // --- millimètres [FFB] ; rang et confiance : voir le doc de dimensions ---
  static const double objectBallDiameterMm = 50.8;   // 7 rouges, 7 jaunes, noire
  static const double cueBallDiameterMm    = 48.0;   // variante WEPF 47,6 : testée, non retenue
  static const double playAreaLengthMm     = 1850;
  static const double playAreaWidthMm      = 925;
  static const double pocketOpeningMm      = 76.2;   // 6 poches identiques
  static const double tipDiameterMm        = 8.5;    // 8 à 9 mm
  static const double headStringFraction   = 0.2;    // 1/5 de la longueur [FFB]
  static const double cushionHeightMm      = 36;

  // --- repère des schémas : une case = un quart de la largeur ---
  static const double cellMm = playAreaWidthMm / 4;  // 231,25 mm
  static const double columns = 8;
  static const double rows = 4;

  // --- en cases (dérivés, jamais retapés) ---
  static const double objectBallRadius = objectBallDiameterMm / 2 / cellMm; // 0,10984
  static const double cueBallRadius    = cueBallDiameterMm / 2 / cellMm;    // 0,10378
  static const double ghostDistance    = objectBallRadius + cueBallRadius;  // 0,21362 = s
  static const double pocketOpening    = pocketOpeningMm / cellMm;          // 0,32951
  static const double headString       = columns * headStringFraction;      // 1,6 [FFB], D2 tranchée
  static const double tipRadiusOnCueBall = tipDiameterMm / cueBallDiameterMm; // 0,177 (en rayons de blanche)
  static const double centerHeightGap  = objectBallRadius - cueBallRadius;  // 0,00605 case = 1,4 mm
}
```

Contrat complémentaire (même fichier ou `ball_geometry.dart` voisin, toujours en `shared/lib`) :

- `BallSizes({cueDiameterMm = 48.0, objectDiameterMm = 50.8})` : valeur immuable portant `cueRadius`, `objectRadius`, `ghostDistance`, `ratio`. Les fonctions de géométrie (section 2) prennent un `BallSizes` facultatif (défaut : cotes retenues) pour tester la variante 47,6 mm et le cas « billes égales » sans dupliquer de constantes.
- `ContactFraction.aimOffset(BallSizes)` : distance d (cases) entre la ligne de visée et le centre de la bille de but (tableau 2.3). **Remplace** `overlap` et `centerOffset`, qui n'ont que deux lecteurs (`ghost_ball_geometry.dart`, `ball_contact_diagram.dart`).
- Garde-fou : règle ajoutée à `app/tool/architecture/architecture_rules.dart` (testée par `architecture_rules_test.dart`) : l'identifiant `ballRadius` et les littéraux `0.1`/`2 * …Radius` près d'un rayon sont interdits hors du module. Évite le retour d'un rayon unique.

### 1.2 Valeurs et rapports à tester (calculées à la main)

| Grandeur | Calcul | Valeur |
|---|---|---|
| case | 925 / 4 | 231,25 mm |
| r_o | 25,4 / 231,25 | 0,109838 case |
| r_c | 24,0 / 231,25 | 0,103784 case |
| s = r_c + r_o | 49,4 / 231,25 | 0,213622 case (= 0,972 × 0,2197) |
| r_c / r_o | 24,0 / 25,4 | 0,944882 |
| variante WEPF | 23,8 / 25,4 ; s = 49,2 / 231,25 | 0,937008 ; 0,212757 case |
| ouverture de poche | 76,2 / 231,25 ; 76,2 / 50,8 | 0,329514 case ; 1,5 exactement |
| ligne de départ | 1850 / 5 = 370 mm ; 8 × 0,2 | 1,6 case |
| surface | 1850 / 925 | 2 (rapport 2:1, 8 × 4 cases) |
| procédé sur la blanche | 8,5 / 48,0 ; 8 / 48 ; 9 / 48 | 0,177 ; 0,167 ; 0,188 |
| écart de hauteur des centres | 25,4 − 24,0 | 1,4 mm = 0,006054 case |

### 1.3 Inventaire exhaustif des endroits qui supposent un rayon unique

Constats par grep sur `ballRadius`, `0.1`, `2 *`, `DiagramLayout`, `TableGeometry`, `BilliardBall`, `BilliardCue`, `BallContactDiagram`, `CueSideView`, `ContactStrip`, `ghost`, YAML.

#### Code de production (`app/lib`)

| Fichier | Supposition actuelle | Changement |
|---|---|---|
| `shared/lib/ghost_ball_geometry.dart` | `const ballRadius = 0.1` ; bille fantôme `O - 2r·u` ; quantité `1 - sin θ` ; tolérance sur `overlap` | Supprimer `ballRadius` ; `G = O - s·u` avec `s = r_c + r_o` ; `contactQuantity` = `1 - (s·sin θ) / s` conservée comme indice ; V17 compare `d = s·sin θ` à `aimOffset` du label (section 2.4) |
| `shared/lib/contact_fraction.dart` | `centerOffset = 2·(1 - overlap)` en rayons communs | `overlap` et `centerOffset` supprimés ; `aimOffset(BallSizes)` ; doc : « distance ligne de visée – centre de la bille de but » |
| `shared/lib/cue_side_geometry.dart` | `tipHeightFactor` (0,55 r) et `cueElevation` | Renommé `cue_ball_target_geometry.dart` ; facteur 0,5 r ; voir 3.2 |
| `shared/lib/illustration.dart` | types `contactStrip`, `cueSide`, `stanceTop`, `powerScale` | Section 3.4 |
| `shared/ui/table_diagram/table_diagram_spec.dart` | `DiagramLayout.ballRadius = 0.1`, `headStringX = 2` | `DiagramLayout` délègue au module (colonnes, lignes, ligne de départ) ; `ballRadius` supprimé |
| `shared/ui/table_geometry.dart` | `TableGeometry.ballRadius`, `ballRadiusPx`, `ballRect(Offset)` | `radiusOf(BallKind)`, `radiusPxOf(BallKind)`, `ballRect(Offset, BallKind)`, `ghostRadiusPx` (= rayon de blanche) ; `railWidth` inchangé |
| `shared/ui/billiard_table.dart` | poche `_pocketRadius = 0.28` ; ligne de départ `TableGeometry.headStringX` | rayon de poche = `pocketOpening / 2` (D6) ; ligne de départ via le module |
| `shared/ui/billiard_ball.dart` | `geometry!.ballRadiusPx * 2` | `geometry.radiusPxOf(kind) * 2` |
| `shared/ui/billiard_cue.dart` | `positionedAgainst` : pointe à `ballRadiusPx` du centre | rayon de la bille touchée (blanche) : `radiusPxOf(BallKind.white)` |
| `shared/ui/table_diagram/table_diagram.dart` | `diameter = ballRadiusPx * 2` pour toutes les billes ; cercles creux de rayon `ballRadiusPx` ; étiquettes décalées de `diameter * 0.6` | diamètre par couleur ; cercles creux (rôles `cue_start`, `impact`) au rayon de blanche ; décalage des étiquettes calculé sur la bille de but |
| `shared/ui/table_diagram/diagram_timeline.dart` (l. 403-404) | point d'impact `target - 2·ballRadius·u` | `target - (r_c + r_target)·u` avec `r_target = objectBallRadius` ; test de cohérence ci-dessous |
| `shared/ui/ghost_aim_diagram.dart` | utilise `ghostBallPosition` | inchangé côté appel ; ajoute le point de contact `O - r_o·u` et la cible sur la blanche (3.2) |
| `shared/ui/ball_contact_diagram.dart` | `r` commun, `dx = √(4r² - offset²)` | `dx = √(s² - d²)` en unités de r_o ; blanche dessinée à `r_c` ; moitié droite = `CueBallTarget` compact |
| `shared/ui/contact_strip.dart` | rangée de `BallContactDiagram` | éléments sans la blanche de face (procédé toujours au centre) ; légende de taille |
| `shared/ui/cue_side_view.dart` | blanche `diameter = h * 0.42` | **supprimé** (remplacé par `CueBallTarget`) |
| `shared/ui/stance_diagram.dart` | blanche `0.14 h`, schéma sans silhouette | **supprimé** (remplacé par `PlayerFigure`) |
| `shared/ui/power_scale.dart` | 1 à 5 barres | **supprimé** (remplacé par `PowerRatio`) |
| `shared/ui/ball_chip.dart`, `shared/ui/ball_kind.dart` | pastille de groupe (taille d'icône libre) | inchangés ; vérifier que la blanche n'y est pas présentée plus grosse que les autres à taille égale |
| `entities/session_sheet/presentation/illustration_mapper.dart` | 10 cas de l'union | cas des nouveaux types, suppression des 3 anciens (3.4) |
| `entities/session_sheet/data/session_sheet_yaml_parser.dart` | clés `levels`, `highlight`, `view`, `annotations`, `cue_height`… | clés des nouveaux types (3.4) |
| `entities/exercise_diagram/presentation/table_diagram_mapper.dart` | convertit `ContactFraction` | vérifier l'absence d'`overlap` ; sinon inchangé |
| `features/suggest_session/presentation/ui/exercise_diagram_view.dart` | affiche `BallContactDiagram` / `TableDiagram` | aucun rayon propre ; recompiler et tester |
| `shared/l10n/app_fr.arb`, `app_en.arb` | clés `stancePart*`, `stanceLabel*`, `powerScale*`, `cueSide*`, `cueBridge*`, `cueHeight*` | suppression / remplacement (3.5) |

#### Outils (`app/tool`) et assets

| Fichier | Supposition | Changement |
|---|---|---|
| `tool/diagrammes/model.dart` | `ballRadius = 0.1` ; état actuel : `startLineX = BlackballDimensions.headString` (1,6) | importer `blackball_dimensions.dart` (fichier pur Dart, `dart run tool/diagrammes.dart` doit rester vert) ; sinon dupliquer **avec un test d'égalité** au module |
| `tool/diagrammes/placement.dart` | chevauchement si distance < `2·ballRadius` | seuil selon les couleurs : blanche–bille de but `s`, bille de but–bille de but `2·r_o`, **moins une tolérance de 0,01 case** (précision de transcription : 2 paires `[S]` à 0,2195 pour un seuil de 0,2197 ; 3 billes à 0,01 case de la bande, à tolérer aussi dans le contrôle « dans la surface ») ; message avec la valeur |
| `tool/diagrammes/ascii_renderer.dart` | utilise `startLineX` (l. 78 et 240) ; pas de rayon | suivre la ligne de départ du module (D2) : faite, `startLineX` = `headString` |
| `tool/diagrammes/validator.dart`, `summary.dart` | pas de rayon de bille (le `radius` du validateur est celui des zones `circle`) | aucun |
| `tool/fiches/session_rules.dart` | liste fermée des 10 types (l. 20-24), clés par type (l. 159-165), `_ghostAim` (bornes seulement) | 3.4 et 4 |

#### Widgetbook et tests existants (oubliés de la première version de l'inventaire)

Grep du 2026-10-13 sur `ballRadius`, `headStringX`, `centerOffset`, `StanceDiagram`, `PowerScale`, `CueSide*`, `ContactFraction`, `ContactStrip`, `BallContactDiagram`, `ghost*`.

| Fichier | Concerné par | Action |
|---|---|---|
| `widgetbook/lib/use_cases/billiard_ball_use_cases.dart`, `billiard_table_use_cases.dart`, `billiard_cue_use_cases.dart`, `table_diagram_use_cases.dart`, `ball_contact_diagram_use_cases.dart`, `illustration_use_cases.dart`, `illustration_gallery_use_case.dart`, `session_sheet_use_cases.dart` ; `widgetbook/lib/support/diagram_examples.dart`, `illustration_gallery.dart` | rayon unique, poche, `cue_side` / `stance_top` / `power_scale` | mise à jour ; `billiard_ball_use_cases` montre une blanche et une bille de but à la même taille d'icône : y ajouter la **comparaison de tailles** (voir 1.4) |
| `app/test/unit/shared/ui/table_geometry_test.dart`, `billiard_cue_test.dart`, `table_diagram/table_diagram_painting_test.dart`, `table_diagram/diagram_timeline_test.dart` | `ballRadius`, `ballRadiusPx`, `headStringX` | réécrits au lot T3 (valeurs 5.3) |
| `app/test/unit/shared/lib/ghost_ball_geometry_test.dart`, `tip_point_test.dart` (`centerOffset`), `illustration_test.dart` | `ballRadius`, `overlap`, `centerOffset`, types supprimés | réécrits aux lots T2, T4 à T6 |
| `app/test/unit/shared/ui/ball_contact_diagram_test.dart`, `contact_strip_test.dart`, `ghost_aim_diagram_test.dart`, `tip_point_direction_test.dart` | `centerOffset`, rayon commun | réécrits au lot T3 |
| `app/test/unit/shared/ui/stance_diagram_test.dart`, `power_scale_test.dart`, `cue_side_view_test.dart`, `app/test/unit/shared/lib/cue_side_geometry_test.dart` | composants supprimés | **supprimés** avec leur composant, remplacés par les tests du § 5 |
| `app/test/unit/entities/session_sheet/presentation/illustration_mapper_test.dart`, `sheet_illustration_view_test.dart`, `data/session_sheet_yaml_parser_test.dart`, `app/test/support/session_sheet_fixtures.dart`, `app/test/unit/features/browse_sheets/presentation/sheet_detail_view_test.dart` | types anciens dans les fixtures | mis à jour (fixtures d'abord) |
| `app/test/bdd/ball_contact_diagram.feature` et `ball_contact_diagram_test.dart`, `app/test/step/i_look_at_the_quantity_of_ball_diagram_with_the_tip.dart` | moitié droite de `BallContactDiagram` | scénario conservé, assertions déplacées sur `CueBallTarget(compact: true)` |
| `app/test/contract/session_sheets_contract_test.dart`, `app/test/tool/fiches_test.dart`, `app/test/tool/validate_seances_test.dart` | V17 par `overlap`, types | V17 par `aimOffset`, V25 à V27 |

#### Documents de format et d'ingénierie

| Fichier | Passage | Changement |
|---|---|---|
| `docs/knowledge/03-exercices/diagrammes/FORMAT.md` | l. 14-21 (rayon 0.1, ligne de départ), l. 98-100 (rayons « `[Prop]` documentés », `G = O - 2r·u`) | rayon de bille de but 0.1098 et de blanche 0.1038 en cases (réels), ligne de départ inchangée mais rappel de la règle `[FFB]`, formule `G = O - (r_c + r_o)·u` |
| `docs/knowledge/05-seances/catalogue/FORMAT.md` | § 6 : l. 244 (« rayon de bille 0.1 »), 252-255 (tableau des types), 263-268 (géométrie de `ghost_aim` : `G = O - 2r·u`, `f = 1 - sin θ` « identique à `centerOffset` », `overlap`, `thin` = 0.05) ; § 7 : V7 (l. 285), V17 (l. 295), V24 (l. 302) ; l. 5 et 275 (V12 et V17 vérifiées par le test de contrat seul) | tableau des types, géométrie corrigée, nouvelles règles V25 à V27 (V24 est la dernière règle existante) (4) |
| `docs/engineering/design-system.md` | l. 48 (« bille = 0,1 case de rayon »), 67, 82-86, 127 (« rayon d'une bille (0,1 case) »), 168 (`DiagramLayout`), 223 (« deux rayons derrière la bille »), 329-333, 342 et 354 (`PowerScale`), 379, 393 | arborescence, tableau des types, notes d'accessibilité, dimensions |
| `docs/engineering/adr/0004-catalogue-fiches-seances.md` | l. 42 (« schémas non à l'échelle »), l. 56 (« Silhouette humaine » rejetée) | voir D8 : ADR 0005 ou mise à jour |
| `docs/engineering/catalogue-seances-plan.md` | l. 141 et 239 (lot L3, `CueSideView`, `StanceDiagram`, `PowerScale`) | renvoi vers ce plan (une ligne) |
| `docs/engineering/quality-gates.md` | mention des types | à relire |
| `docs/knowledge/05-seances/README.md` | l. 43-44 (thème « Le curseur de puissance ») | cohérent avec le thème conservé des séances 03 et 04 (V23) |
| `docs/knowledge/02-techniques/06-dimensions-du-materiel.md` | § 3.5, § 4 | note « réalisé dans le dépôt » ; ne pas changer les valeurs |

#### Diagrammes et séances (contenu)

| Contenu | Quantité mesurée | Action |
|---|---|---|
| `docs/knowledge/03-exercices/diagrammes/{entrainement,initiation,jeux}/*.yaml` | 579 billes, 257 cercles creux, transcrits `[S]` | **positions inchangées** (mesures sur le PDF) ; seul le rendu change. Recontrôle de placement (script du 2026-10-13, 191 diagrammes, rayons réels) : 2 paires à 0,2195 (jeux p12 `r2`–`r3`, jeux p14 `b8`–`y3`) pour un seuil 2 r_o = 0,2197, donc tangentes à 0,0001 case près : tolérance de 0,01 case (précision de transcription) ; 3 billes à moins de r_o d'une bande (initiation p05 `r1` à x = 0,10 ; jeux p01 `r5` et proposition p01 `r5` à y = 3,90), dépassement de 0,01 case, à tolérer et à dessiner contre la bande |
| `docs/knowledge/03-exercices/diagrammes/proposition/p01.yaml`, `p02.yaml` | 20 cercles `impact` de p02 et ceux de p01 sont **calculés** (`G = O - 0,2·u`) | recalculer avec `s` (décalage de 0,0136 case, 3,1 mm), arrondi à 0,01 ; script de recalcul dans `tool/diagrammes` (option `--ghosts`) |
| Séances : 13 `ghost_aim` (16 illustrations) | cue calculé pour le label | recalcul des deux cas marginaux (2.5) |
| Séances : 26 fichiers avec `table` inline (35 tables), 22 fichiers portant 40 cercles `impact` / `cue_start` | cercles `impact` / `cue_start` | contrôle de placement, aucune coordonnée à changer a priori |

### 1.4 Effet du passage à l'échelle réelle

| Mesure | Avant | Après (D1) |
|---|---|---|
| rayon bille de but | 0,1000 | 0,1098 (+ 9,8 %) |
| rayon blanche | 0,1000 | 0,1038 (+ 3,8 %), **toujours plus petit** que la bille de but |
| distance de contact blanche–bille de but | 0,2000 | 0,2136 (+ 6,8 %) |
| ouverture de poche | 0,56 (disque de rayon 0,28) | 0,33 |
| billes initiales se chevauchant (diagrammes) | 0 | 0 (2 paires tangentes à 0,0001 case, tolérance 0,01) |
| écart de diamètre blanche / bille de but à l'écran (table de 9 cases avec bandes) | 0 | 0,0121 case : **≈ 0,5 px à 360 px, ≈ 1,7 px à 1280 px** |

**Conséquence.** La différence réelle (5,5 %) est fidèle mais à peine perceptible dans un schéma de table : le critère « visiblement plus petite » ne peut pas reposer sur les schémas d'exercices. Prévoir (a) une **comparaison de tailles** dédiée (deux billes côte à côte, grande échelle, légende « blanche 48,0 mm, bille de but 50,8 mm », `[FFB]`) dans le cas Widgetbook des billes et dans la séance « bille fantôme » ; (b) aucune exagération silencieuse des tailles dans les schémas de table ; (c) un test mesurable (écart de diamètre en px, voir 5.3) et non un test « visuel ».

---

## 2. Géométrie corrigée (B)

Notations : `O` centre de la bille de but, `P` centre de la poche, `C` centre de la blanche au départ, `G` centre de la blanche à l'impact, `u = unit(P - O)`, `s = r_c + r_o`, `θ` angle de coupe.

### 2.1 Bille fantôme

`G = O - s·u`, avec `s = r_c + r_o` (0,213622 case ; 49,4 mm). Rayon de la bille fantôme (cercle creux) : `r_c`. Cas limite inchangé : `P = O` donne `G = O`.

### 2.2 Angle de déviation et lien avec la distance d

Au contact, le triangle (centre de la blanche, centre de la bille de but, pied de la perpendiculaire) est rectangle d'hypoténuse `s` :

- `d = s·sin θ`, où `d` est la distance entre la ligne de visée `C → G` et `O`.
- `θ` est l'angle entre la ligne de visée et la ligne des centres, donc la direction prise par la bille de but (`u`).
- Fonctions pures (`shared/lib`) : `ghostBallPosition`, `cutAngle`, `aimDistance = s·sin θ`, `contactQuantity = 1 - sin θ` (indice continu : 1 plein, 0 rasant).

### 2.3 Quantité de bille avec rayons différents (définitions `[S]`)

| `ContactFraction` | Définition | `d` (mm) | `d` (cases) | `θ` = asin(d / s) | `1 - sin θ` | Même angle, billes égales |
|---|---|---|---|---|---|---|
| `full` | visée au centre | 0 | 0 | 0° | 1,000 | 0° |
| `threeQuarter` | à mi-chemin du centre et de la tangente : `r_o / 2` | 12,7 | 0,054919 | 14,90° | 0,743 | 14,48° |
| `half` | trajectoire de la blanche par la tangente : `r_o` | 25,4 | 0,109838 | 30,94° | 0,486 | 30,00° |
| `quarter` | `r_o + r_c / 2`, mesuré par rapport à la blanche (n° 7) | 37,4 | 0,161730 | 49,21° | 0,243 | 48,59° |
| `thin` | `0,95·s` `[Prop]` (contact rasant) | 46,93 | 0,202941 | 71,81° | 0,050 | 71,81° |

Les valeurs `[S]` « ≈ 30° » et « ≈ 15° » sont retrouvées à moins de 1°. Le quart de bille est la seule cote qui fait intervenir le rayon de la blanche, conformément à la fiche n° 7.

### 2.4 Contact au-dessus de l'équateur de la blanche (hauteur)

Les billes reposent sur le tapis : le centre d'une bille de but est à `r_o`, celui de la blanche à `r_c`. La ligne des centres est inclinée de `φ = asin((r_o - r_c) / s) = asin(1,4 / 49,4) = 1,62°`. Hauteur du contact au-dessus de l'équateur de la blanche : `r_c · sin φ = 24,0 × 1,4 / 49,4 = 0,68 mm` (2,8 % de `r_c`) ; au-dessous de l'équateur de la bille de but : 0,72 mm.

Conséquences pour le dessin :

- Vue de dessus (toutes les illustrations `table`, `ghost_aim`, `contact`) : **aucun effet visible** (0,68 mm = 0,003 case) ; le contact se dessine sur la ligne des centres horizontale.
- Vue de côté : le décalage n'est visible qu'**exagéré**. D5 réalisé : l'inclinaison de la ligne des centres est exagérée ×10 (16,24°), billes posées sur le tapis (r_o' = 42,6 mm, contact dessiné à 6,71 mm) ; mention obligatoire dans la légende et la description parlée (§ 3.4).
- Le procédé (8,5 mm) est 12,5 fois plus grand que ce décalage : le marqueur de `CueBallTarget` n'est **pas** à l'échelle du contact, mais de la blanche.

### 2.5 Conséquences pour `ghost_aim` et la tolérance V17

**Tolérance.** Comparer `d = s·sin θ` à `aimOffset(label)` avec une tolérance de `0,07·s` (= 3,5 mm, 0,015 case). C'est exactement l'ancienne tolérance 0,07 sur `1 - sin θ` ; les labels voisins restent séparés (écart minimal entre deux `d` nominaux : 0,19·s, donc > 2 × 0,07·s). V17 vérifie donc la cohérence géométrique par `aimOffset`, plus par `overlap`.

**Mesure sur les 16 `ghost_aim` des 13 séances** (calcul du 2026-10-13, ancien modèle `2r = 0,2` contre nouveau `s`, `d/s` nominal nouveau) :

| Séance / id | label | θ ancien | θ nouveau | θ nominal | écart `d/s` nouveau |
|---|---|---|---|---|---|
| 06 `visee-demi`, 09 `visee-demi` | half | 29,9° | 30,0° | 30,9° | − 0,014 |
| 10 `visee-autre-cote` | half | 30,0° | 30,2° | 30,9° | − 0,011 |
| 11, 19, 20 `visee-trois-quarts` | three_quarter | 14,5° à 14,7° | 14,6° à 14,8° | 14,9° | − 0,006 à − 0,001 |
| 12 `visee-poche-bas`, `visee-poche-haut` | three_quarter | 16,2° | 16,3° | 14,9° | + 0,023 |
| 13 `visee-quart` | quarter | 44,7° | 45,0° | 49,2° | **− 0,050** |
| 14 `visee-finesse` | thin | 62,8° | 63,1° | 71,8° | **− 0,058** |
| 05, 06, 07, 08, 19, 26 (pleins) | full | 0° | 0° | 0° | 0 |

Aucune illustration ne dépasse 0,07, mais `quart` et `finesse` sont à 0,020 et 0,012 de la limite (valeurs recalculées le 2026-10-13, identiques au tableau) : **recalculer leur position de blanche** (`cue`) pour retrouver 49,2° et 71,8° (avec l'objet et la poche inchangés), et ajouter un test qui impose une marge de 0,02 sur toutes les illustrations. Les 14 autres ne bougent pas.

**Recalcul des positions dérivées.**

1. `proposition/p01.yaml`, `p02.yaml` : tous les cercles `impact` qui sont des `G` calculés (l'annotation `[Prop]` du fichier le dit) sont recalculés par `tool/diagrammes` avec le module.
2. Illustrations inline des séances : recalcul seulement si le test de marge échoue (liste ci-dessus).
3. Diagrammes `[S]` transcrits : jamais recalculés (rang 1).

**Rendu de `ghost_aim`.** Billes à leurs rayons réels ; cercle creux de la bille fantôme au rayon `r_c` ; point de contact `O - r_o·u` marqué ; petite cible de la blanche (3.2) en légende avec le point d'impact du procédé fixé par la séance (centre par défaut).

---

## 3. Trois illustrations qui remplacent les anciennes (C)

Règles communes (toutes) : dessin généré (jamais de photo) ; couleurs lues dans le thème (`FigureColors` à ajouter à côté de `BallColors` et `TableColors`, clair et sombre, contraste ≥ 4,5 : 1 testé) ; **traits ≥ 3 px à 360 px de large** (épaisseur proportionnelle à la largeur, plancher 3 px) ; **textes ≥ 14** (ajouter `AppTypography.projectionTextSize = 14` ; `minTextSize = 12` actuel reste pour les puces) ; la couleur n'est jamais le seul indice (forme, numéro, coche) ; `Semantics` localisé en `excludeSemantics: true`, `container: true` ; mise en page responsive (`AspectRatio` + `LayoutBuilder`), la légende passe sous le dessin et à la ligne ; fr et en.

### 3.1 `PlayerFigure` : le personnage (remplace `stance_top` / `StanceDiagram`)

Source : fiche technique n° 1 (`02-techniques/01-visee-posture-coup-de-queue.md`), étape 2, pages 3, 6 et 7.

**Vue de côté** (par défaut), personnage de trait épais : tête ronde, buste, deux bras, deux jambes, deux pieds, queue, chevalet, table et blanche. Joueur **droitier** (comme la fiche n° 1) ; un joueur gaucher se lit en miroir, à signaler dans la légende (point ouvert, 6). Proportions `[Prop]` en fraction de la taille du joueur `H` : plateau à 0,48 H (820 à 850 mm), pointe de la queue à 0,50 H (au niveau du centre de la blanche), **talon relevé de 10°** (`CueHeight.level`, valeur déjà utilisée par `cueElevation`, jamais une queue strictement horizontale : la source ne dit pas « horizontale »), tête à 0,60 H juste au-dessus de la queue, queue de 0,83 H (≈ 145 cm). La fiche n° 1 précise qu'il ne faut pas imposer une attitude très précise : légende au mode « repères », pas « règles ». Les billes sont **agrandies et non à l'échelle** (mention localisée dans la description parlée et la légende) ; la blanche reste plus petite que la bille de but si les deux sont dessinées.

| N° | Repère (`PlayerMark`) | Ce que le dessin montre (fiche n° 1) | Texte de légende fr |
|---|---|---|---|
| 1 | `feet` | pieds ni trop serrés ni trop espacés ; pied droit sous la main droite (verticale commune pied–main) | « Pieds : ni trop serrés, ni trop espacés ; le pied droit sous la main qui tient la queue » |
| 2 | `legsAndHips` | jambe droite tendue, jambe gauche fléchie, bassin pivoté à gauche (première option de la source) ; la seconde option (jambe gauche plus en avant, deux jambes fléchies) est donnée en texte de légende, pas dessinée | « Jambes et bassin : bassin légèrement pivoté à gauche ; jambe droite tendue et gauche fléchie, ou jambe gauche en avant, les deux fléchies » |
| 3 | `head` | tête dans l'axe de la queue, œil directeur au-dessus de la queue | « Tête : dans l'axe de la queue, l'œil directeur au-dessus » |
| 4 | `backForearm` | avant-bras arrière **à la verticale**, coude à l'aplomb de la main ; balancier du coude seul | « Avant-bras : vertical, seul le coude bouge » |
| 5 | `bridgeHand` | main de chevalet sur le cadre ou sur le tapis (paramètre `bridge`) | « Main de chevalet : sur le cadre ou sur le tapis » |
| 6 | `cue` | queue dans l'axe de la visée, passant par le centre de la blanche (étape 1 : « la queue est placée sur la trajectoire … passant par son centre ») | « Queue : dans l'axe de la visée, vers le centre de la blanche » |

Pastilles numérotées (disque + chiffre, ≥ 28 px de diamètre) posées sur le dessin avec un trait de renvoi ; la **légende est une liste hors du dessin** (numéro + texte), donc lisible à la projection. Un repère hors `focus` est estompé, sa ligne de légende est omise. **Charge pour des débutants** : six repères d'un coup sont trop pour une première séance (la fiche n° 1 demande de ne pas surcharger) ; règle de contenu : séances enfants, `focus` de 3 repères au plus par illustration (une illustration par étape : pieds et jambes, puis tête et queue, puis avant-bras et chevalet) ; le jeu complet de six reste pour les adultes et pour le rappel.

**Vue de dessus** (`view: top`, ou `both`) : conserve les informations du `StanceDiagram` actuel mais avec le même style de personnage (tête ronde, ligne d'épaules, deux bras, pieds en ovales), pour l'écartement des pieds, le pivot du bassin et les trois places de la tête (`headCase`) : œil droit au-dessus de la queue, queue entre les deux yeux, œil gauche au-dessus. L'œil directeur est marqué d'une cible fixe et nommé.

**Paramètres** (Dart, modèle `Illustration.playerFigure` et widget) :

| Paramètre | Type | Défaut | Rôle |
|---|---|---|---|
| `view` | `PlayerView { side, top, both }` | `side` | profil, dessus, ou les deux côte à côte (une colonne si l'écran est étroit) |
| `focus` | `Set<PlayerMark>` | les 6 | repères présentés ; les autres sont estompés et sans légende |
| `leadEye` | `StanceLeadEye { left, right }` | `right` | œil directeur (vue de dessus) |
| `headCase` | `HeadCase { rightEyeOverCue, cueBetweenEyes, leftEyeOverCue }?` | `null` | place de la tête (vue de dessus) |
| `bridge` | `CueBridge { frame, surface }` (existant, déplacé) | `frame` | appui de la main de chevalet |

**Sémantique** : `playerFigureLabel(view, marks)` énumère les repères dans l'ordre numérique avec leur texte, mentionne « figure schématique, billes non à l'échelle » ; chaque pastille n'est pas annoncée séparément.

**Correspondance YAML** : `type: player_figure`, clés `view` (`side|top|both`), `focus[]` (liste de `feet legs_and_hips head back_forearm bridge_hand cue`), `lead_eye`, `head_case`, `bridge`. Ancien `stance_top` : `view: top` devient `view: top` ; `annotations[]` (texte libre) est **supprimé** : leur contenu passe en `focus` + `head_case` + `caption`.

**Géométrie pure** (`shared/lib/player_figure_layout.dart`, Dart pur) : positions normalisées des articulations dans le repère `[0,1]²` du profil (pied, genou, hanche, épaule, coude, main, tête, œil), calculées depuis `H`. Elle porte les invariants testés en 5.

### 3.2 `CueBallTarget` : la cible sur la blanche (remplace `cue_side`, `CueSideView` et la moitié droite de `BallContactDiagram`)

Source : fiche technique n° 3 à 8 (p. 14, « point bleu à l'intersection des axes »), fiche n° 2 et fiches rétro/coulé (attaque haute / basse), `03-exercices/diagrammes/initiation/p19.yaml` `[Prop]` (≈ mi-rayon sous le centre ; p. 14 : `techniques/p14.yaml`, « point bleu à l'intersection des axes »).

**Dessin** : la blanche vue de face, rayon `R` pixels (la blanche est dessinée à sa propre taille ; si une bille de but est aussi montrée dans la même illustration, elle l'est à `R / 0,945`).

- **Cible** : anneaux concentriques à `0,5 R` et `1,0 R` (bord de la blanche), croix du centre.
- **Axes** : repères de croix nommés « Haut », « Bas », « Gauche », « Droite », « Centre » (≥ 14, hors de la bille).
- **Point d'impact** : disque plein de rayon `0,177 R` (procédé 8,5 mm, `BlackballDimensions.tipRadiusOnCueBall`), couleur `TableColors.chalk`, **contour épais** de la couleur du thème ; plancher de 10 px de rayon pour la projection, avec un anneau de visibilité extérieur (cercle pointillé) qui le signale quand le plancher est actif. L'échelle du procédé n'est donc exacte que si `R ≥ 57 px` (10 / 0,177 = 56,5) ; le plancher est testé. Pour les débutants : pas plus de **deux** marqueurs lisibles à la fois en projection (le point d'impact plein et, au plus, un cercle creux de comparaison) ; `compare` à trois points reste réservé à la page de comparaison « centre, haut, bas ».
- **Positions** (rayons de blanche, `[Prop]`) : centre (0 ; 0) ; haut (0 ; 0,5) ; bas (0 ; − 0,5) ; gauche / droite (± 0,5 ; 0) ; diagonales (± 0,354 ; ± 0,354) (même norme 0,5).
- **Variantes** : `center`, `top` (au-dessus), `bottom` (en dessous), `left` / `right` (côté), et 4 diagonales. `compare` : liste de points rendus en cercles creux étiquetés par leur lettre, pour montrer côte à côte « centre, haut, bas » dans une même cible.
- **Option profil** (`cue_height`) : petite vue de côté en encart (blanche de profil, queue inclinée, procédé au point correspondant sur le bord). Hauteur du talon : `low = 0°`, `level = 10°`, `high = 25°` `[Prop]` (valeurs conservées de `cueElevation`).

**Paramètres** :

| Paramètre | Type | Défaut | Rôle |
|---|---|---|---|
| `tipPoint` | `TipPoint` (9 valeurs, existant) | `center` | point d'impact du procédé |
| `compare` | `List<TipPoint>` | `[]` | points d'appui de comparaison (cercles creux) |
| `cueHeight` | `CueHeight?` | `null` | affiche l'encart de profil |
| `compact` | `bool` | `false` | variante réduite (sans libellés d'axe) utilisée par `BallContactDiagram` |

**Sémantique** : `cueBallTargetLabel(tipName, compare, height?)` (« Cible sur la blanche : procédé au-dessus du centre ») ; `TipPoint` a déjà ses étiquettes (`tipPointCenter`…).

**Correspondance YAML** : ancien `cue_side` (`tip_point`, `cue_height`, 18 fichiers) devient `cue_ball_target` (`tip_point`, `cue_height` facultatif, `compare` facultatif). Ancien `contact` (`fraction`, `tip_point`) reste un type, avec moitié droite = `CueBallTarget(compact: true)`.

### 3.3 `PowerRatio` : le rapport amplitude × vitesse (remplace `power_scale`)

Source : fiche technique n° 2 (`02-techniques/02-puissance.md`) : « la puissance dépend de deux critères, la vitesse et l'amplitude (le recul de la main jusqu'à la fin de la pénétration) ; peu d'amplitude + peu de vitesse = doucement ; grande amplitude + grande vitesse = puissant ». Aucun « cran » dans la source ; les crans 1 à 5 étaient une image `[Prop]`.

**Dessin : un plan à deux axes**.

- Axe horizontal, **amplitude** (« recul de la main »), de « courte » à « longue » ; sous l'axe, deux petits schémas de queue (flèche courte / flèche longue) rappellent la fiche p. 12.
- Axe vertical, **vitesse du coup de queue**, de « lent » à « rapide » ; flèche épaisse croissante.
- **Trois zones** en bandes diagonales (de l'angle bas-gauche à l'angle haut-droit) : « doux », « moyen », « puissant » ; distinguées par **motif** (aucun, hachures, croisillons) et par **texte dans la zone**, pas par la couleur seule.
- **Exemples placés** : un ou plusieurs points (`amplitude`, `speed`) numérotés ou nommés, l'un pouvant être mis en évidence (coche, cadre épais). Une ligne de repère verticale et horizontale relie le point aux deux axes pour lire « le rapport ».
- **Résultat** : le texte de la zone atteinte est répété sous le plan (« Zone atteinte : puissant ») et dans la description parlée.
- `distance_label` (texte libre de la séance, ex. « bille lointaine ») reste possible sous le plan.
- **Charge pour des débutants** : au plus **deux** exemples placés par illustration (les deux extrêmes de la source, « doux » et « puissant » ; l'exemple du milieu seul, jamais), zones nommées *dans* la zone en texte ≥ 14, hachures à traits ≥ 3 px, pas de grille de neuf cases visible. Les crans disparaissent : le plan n'a pas de graduation chiffrée.

**Modèle** (pur, `shared/lib/power_ratio.dart`) `[Prop]` :

| Niveau | Valeur relative | Niveau | Valeur relative |
|---|---|---|---|
| `AmplitudeLevel.short` | 0,3 | `SpeedLevel.slow` | 0,3 |
| `AmplitudeLevel.medium` | 0,6 | `SpeedLevel.medium` | 0,6 |
| `AmplitudeLevel.long` | 1,0 | `SpeedLevel.fast` | 1,0 |

`powerZone(a, v)` : produit `p = a·v` ; `p < 0,2` : `soft` ; `0,2 ≤ p < 0,5` : `medium` ; `p ≥ 0,5` : `strong`. Les neuf combinaisons : (short, slow) 0,09 soft ; (short, medium) 0,18 soft ; (short, fast) 0,30 medium ; (medium, slow) 0,18 soft ; (medium, medium) 0,36 medium ; (medium, fast) 0,60 strong ; (long, slow) 0,30 medium ; (long, medium) 0,60 strong ; (long, fast) 1,00 strong. Seuls les deux extrêmes viennent de la source ; la grille intermédiaire est **`[Prop]`**, signalée dans le FORMAT et la description des séances.

**Paramètres** :

| Paramètre | Type | Défaut | Rôle |
|---|---|---|---|
| `points` | `List<PowerPoint>` (`amplitude`, `speed`, `label?`) | `[]` | exemples placés ; vide : plan seul |
| `highlight` | `int?` (index dans `points`) | `null` | exemple mis en évidence |
| `distanceLabel` | `String?` | `null` | repère de séance, déjà en français |

**Sémantique** : `powerRatioLabel(amplitude, speed, zone)` ; sans point : « Plan amplitude et vitesse : trois zones, doux, moyen, puissant ».

**Correspondance YAML** : `type: power_ratio`, `points: [{amplitude: short|medium|long, speed: slow|medium|fast, label?}]`, `highlight` (index 0-based), `distance_label`. Migration des 4 illustrations actuelles : `levels: 5` sans `highlight` (03-puissance-1 « Distance à parcourir ») devient plan seul ; `highlight: 1` devient (short, slow) ; `highlight: 5` devient (long, fast) ; `highlight: 2` (23-carreau-2, « la blanche s'arrête à l'impact ») devient (short, medium) soit zone soft, cohérent avec le texte « courte distance ».

### 3.4 Quatrième illustration facultative `contact_height` (D5)

**Réalisé (2026-10-15).** Deux billes inégales au contact, de côté, ligne des centres inclinée de 1,62° exagérée ×10 (16,24°) et signalée ; point de contact marqué au-dessus de l'équateur de la blanche. Params : aucun (l'exagération `ContactHeightView.exaggeration = 10` est interne, une clé YAML `exaggeration` est refusée). Sert la séance « bille pleine » (`07-bille-pleine-1`, section `centre`, texte sur l'équateur réservé aux adultes ; le schéma, lui, est vu par les deux publics car le format n'a pas d'illustration par public, consigné dans `uncertainties` `[Prop]`). Rayon exagéré de la bille de but `r_o' = r_c (1 + sin 16,24°) / (1 − sin 16,24°)` = 42,635 mm pour `r_c` = 24,0 mm (billes toujours posées sur le tapis) ; hauteur de contact dessinée `r_c · sin 16,24°` = 6,71 mm ; la légende donne la vraie valeur (0,68 mm). Source `[S]` : fiche n° 4 (« légèrement au-dessus de l'axe horizontal ») ; les 1,62° et 0,68 mm sont dérivés des cotes `[FFB]`.

### 3.5 Impact sur le modèle, le parseur, le validateur, le FORMAT, le mapper et la documentation

**Union `Illustration`** (`shared/lib/illustration.dart`, `illustration.freezed.dart` regénéré par `scripts/generate.sh`) :

| Avant | Après |
|---|---|
| `contact` (`fraction`, `tipPoint`) | inchangé |
| `contactStrip` (`fractions`, `highlight`) | inchangé (rendu corrigé, éléments sans blanche de face) |
| `ghostAim` | inchangé (rendu et calcul corrigés) |
| `cueSide` (`tipPoint`, `cueHeight`) | **supprimé** → `cueBallTarget` (`tipPoint`, `compare`, `cueHeight?`) |
| `stanceTop` (`annotations`) | **supprimé** → `playerFigure` (`view`, `focus`, `leadEye`, `headCase`, `bridge`) |
| `powerScale` (`levels`, `highlight`, `distanceLabel`) | **supprimé** → `powerRatio` (`points`, `highlight`, `distanceLabel`) |
| (nouveau, D5 réalisé) | `contactHeight` (sans paramètre) |

Les trois suppressions sont des **renommages avec changement de champs** : aucune compatibilité (V1 non livrée). Nouvelles énumérations pures : `PlayerView`, `PlayerMark`, `HeadCase`, `AmplitudeLevel`, `SpeedLevel`, `PowerZone`, `PowerPoint`. `CueHeight` reste.

**Parseur** (`session_sheet_yaml_parser.dart`) : clés strictes par type (comme aujourd'hui) ; types anciens `cue_side`, `stance_top`, `power_scale` **rejetés** avec le message « type hors de la liste fermée » ; énumérations en `snake_case`.

**Validateur** (`tool/fiches/session_rules.dart`) : listes de l. 20-24 et 159-165 mises à jour ; `cue_ball_target` : `tip_point` obligatoire, `compare` ⊂ `_tipPoints`, `cue_height` ⊂ `_cueHeights` ; `player_figure` : `view` ∈ {side, top, both}, `focus` ⊂ marques, `head_case` seulement si la vue contient `top` ; `power_ratio` : chaque `amplitude` ∈ {short, medium, long}, `speed` ∈ {slow, medium, fast}, `highlight` entier dans `0..points.length - 1`. Règles ajoutées au tableau V (FORMAT § 7) :

| N° | Règle |
|---|---|
| V25 | `cue_ball_target` : `tip_point` ∈ 9 valeurs, `compare` sans doublon ni `tip_point`, `cue_height` ∈ {high, level, low} |
| V26 | `player_figure` : `view`, `focus`, `head_case` cohérents (V7 pour les valeurs inconnues) ; `focus` non vide |
| V27 | `power_ratio` : niveaux dans les listes fermées ; `highlight` dans les bornes ; aucune clé `levels` ni `cran` |

Et V17 reformulée : fraction dérivée cohérente (`aimOffset`, tolérance 0,07·s) ; marge ≥ 0,02·s (test de contrat).

**Mapper** (`illustration_mapper.dart`) : trois cas remplacés, `semanticLabel` par type, légende affichée par `SheetIllustrationView`.

**Widgetbook** : cas d'usage `player_figure_use_cases.dart` (profil, dessus, les deux, `focus` partiel, `headCase` × 3, `bridge` × 2), `cue_ball_target_use_cases.dart` (9 points, `compare`, `cueHeight`, `compact`), `power_ratio_use_cases.dart` (plan seul, 2 exemples, 9 combinaisons) ; mise à jour de `illustration_gallery.dart` (galerie des types) et `session_sheet_use_cases.dart` ; suppression des cas `cue_side`, `stance`, `power_scale`. `main.directories.g.dart` est généré (`scripts/generate_widgetbook.sh`), jamais édité. Contrôle `scripts/check_widgetbook.dart` : chaque widget public a son cas.

**l10n** (fr **et** en, mêmes clés, `scripts/generate.sh`) :

| Famille | Clés |
|---|---|
| à supprimer | `stancePart*`, `stanceLabel`, `stanceLabelWithNotes`, `powerScaleLabel`, `powerScaleRangeLabel`, `powerScaleWeak`, `powerScaleStrong`, `cueSideLabel`, `cueSideLabelWithBridge` (`cueHeight*`, `cueBridge*` conservées) |
| `playerFigure…` | `playerFigureLabel`, `playerFigureNotToScale`, `playerMarkFeet`, `playerMarkLegs`, `playerMarkHead`, `playerMarkForearm`, `playerMarkBridge`, `playerMarkCue`, `playerMark…Hint` (textes de légende), `headCaseRightEye`, `headCaseBetweenEyes`, `headCaseLeftEye`, `playerViewSide`, `playerViewTop` |
| `cueBallTarget…` | `cueBallTargetLabel`, `cueBallTargetAxisTop/Bottom/Left/Right/Center`, `cueBallTargetTipName`, `cueBallTargetCompare` |
| `powerRatio…` | `powerRatioLabel`, `powerRatioEmptyLabel`, `powerRatioAxisAmplitude`, `powerRatioAxisSpeed`, `amplitudeShort/Medium/Long`, `speedSlow/Medium/Fast`, `powerZoneSoft/Medium/Strong`, `powerRatioReached` |

**Migration du contenu des 29 séances** (fichiers repérés par grep sur `type:`) :

| Type ancien | Fichiers (`docs/knowledge/05-seances/catalogue/`) | Nouveau type et changement de texte |
|---|---|---|
| `stance_top` (4 illustrations) | `01-posture-1` (2 : `posture-dessus`, `tete-oeil`), `02-posture-2`, `04-puissance-2` | `player_figure` ; `posture-dessus` : `view: side`, `focus` des 6 repères ; `tete-oeil` : `view: top`, `head_case` selon les trois cas (une illustration par cas ou une seule avec `view: top` et trois lignes de texte), `caption` et `alt` réécrits (ils disaient « ne montre pas la main droite ») ; supprimer les remarques d'écart de la rubrique `notes` qui parlent de « vue de dessus sans silhouette » |
| `cue_side` (18 fichiers) | 05, 06, 07, 11, 12, 13, 15, 17, 18, 19, 22, 23, 24, 25, 26, 27, 29 et 01 | `cue_ball_target` : mêmes `tip_point` et `cue_height` (12 `center/level`, 4 `top/level`, 3 `bottom/level`, 2 `bottom/high`) ; `caption` et `alt` : remplacer « vue de côté » par « cible sur la blanche » |
| `power_scale` (4 illustrations) | `03-puissance-1` (2 + 1 plan seul), `04-puissance-2`, `23-carreau-2` | `power_ratio` ; supprimer « cran », « échelle à cinq crans », « niveau 2 sur 5 » dans `caption`, `alt`, `key_point`, `demo`, `notes` ; le thème « curseur de puissance » est conservé mais décrit par deux curseurs (recul, vitesse) ; adapter la question « Quel cran du curseur était le plus difficile ? » en « Quel dosage du recul et de la vitesse était le plus difficile ? » |
| `contact` (13 fichiers), `contact_strip` (13), `ghost_aim` (13) | voir inventaire | pas de changement de YAML ; `caption` et `alt` : ajouter la taille relative quand le sujet est « la blanche est plus petite » |
| Textes mentionnant « 5 niveaux », « cran » | 03, 04, 23 (grep `\bcrans\?\b\|cinq niveaux\|de 1 (doux) à 5`) ; hors `caption` / `alt` : `03` l. 17 (« gradué de 1 à 5 »), 47-54 (section `curseur`, titre « Le curseur de 1 à 5 », `key_point`, `demo`), 202, 212, 214 ; `04` l. 17, 85, 172 ; `23` l. 70 (« un cran plus doux, un cran plus fort ») | réécriture ; l'`id` de section `curseur` et le thème « Le curseur de puissance » restent (V23, `05-seances/README.md`) ; le mot « officiel » reste interdit pour les `[Prop]` (V19) |
| Rétro, séances 26 à 29 (`contact_strip` avec `half`, illustrations `retro-demi`, `angle-90`) | `29` l. 50, 131, 137, 156 (« en demi-bille … 90° » ; la ligne 52 est déjà correcte) ; `28` l. 85 est déjà correcte (« proche du demi-bille, légèrement plus pleine ») | la source dit que la demi-bille **ne donne pas** 90° au Blackball (fiche n° 14, p. 25) : corriger `caption` et `alt` en « quantité proche du demi-bille, un peu plus pleine (≈ 0,7 mm de plus que la demi-bille : à dire, pas à dessiner), environ 90° » ; la légende du `contact_strip` ne doit pas présenter `half` comme la quantité du 90° |
| Mentions hors `caption` / `alt` : « vue de côté », « queue de côté », « pas à l'échelle », « vue de dessus sans silhouette » | 29 fichiers (grep `vue de côté\|de côté\|pas à l'échelle\|silhouette\|vue de dessus`), notamment `uncertainties` et `notes` (ex. `13` l. 226, `01` l. 145) | relecture ligne à ligne ; « non à l'échelle » devient « échelle réelle du matériel, sauf mention » seulement pour les schémas de table et de contact, pas pour `player_figure` |

Après les modifications des sources de séances : `scripts/sync_fiches.sh`, puis `scripts/sync_diagrammes.sh` (diagrammes de proposition) et `scripts/sync_catalogue.sh --check`.

---

## 4. Ordre de réalisation (BDD puis TDD, un lot = un commit à la demande de l'utilisateur)

| Lot | Contenu | Tests d'abord (rouge) | Garde-fou |
|---|---|---|---|
| T1 | `blackball_dimensions.dart`, `BallSizes`, règle d'architecture | `blackball_dimensions_test.dart` (5.1) | `check.sh --fast` |
| T2 | Géométrie : fantôme, `aimOffset`, V17 par `d`, recalcul `quart` / `finesse` | `ghost_ball_geometry_test.dart` réécrit (5.2) | `check.sh --fast` |
| T3 | Rendu des tailles : `TableGeometry`, `BilliardBall`, `BilliardCue`, `TableDiagram`, timeline, `BallContactDiagram` (gauche), `ContactStrip`, poche | tests peinture (5.3) | `--full` |
| T4 | `CueBallTarget` + migration `cue_side` + `.feature` « où viser » | 5.4 | `--full` |
| T5 | `PlayerFigure` + migration `stance_top` + `.feature` « se placer » | 5.5 | `--full` |
| T6 | `PowerRatio` + migration `power_scale` + `.feature` « doser la puissance » | 5.6 | `--full` |
| T7 | Contenu : recalcul `proposition/`, séances, FORMAT (deux fichiers), design-system, sync | validateurs | `fiches.dart --complete`, `validate_seances.dart` |
| T8 | Revue séparée (`architecte-fsd`, `testeur-bdd`, `relecteur-pedagogique`) puis `check.sh --full` | : | : |

Scénarios BDD (dans `app/test/bdd/`, à côté de `ball_contact_diagram.feature`) : `ball_sizes.feature` (le diamètre de la blanche vaut 0,945 fois celui de la bille de but dans la comparaison de tailles et dans chaque schéma, la bille fantôme touche la bille de but), `cue_ball_target.feature` (point d'impact par variante), `player_figure.feature` (six repères légendés), `power_ratio.feature` (zone atteinte selon amplitude et vitesse).

---

## 5. Plan de test (D) : valeurs calculées à la main

Tolérance par défaut `1e-6` sur les cases ; `1e-4` si la valeur est arrondie ici à 5 décimales.

### 5.1 Dimensions

| Test | Entrée | Attendu (calcul) |
|---|---|---|
| case | 925 / 4 | `cellMm` = 231,25 |
| rayon bille de but | 25,4 / 231,25 | 0,109838 |
| rayon blanche | 24,0 / 231,25 | 0,103784 |
| blanche plus petite | `cueBallRadius < objectBallRadius` | vrai |
| rapport | 24,0 / 25,4 | 0,944882 |
| distance de contact | 0,109838 + 0,103784 | 0,213622 |
| variante 47,6 | `BallSizes(cueDiameterMm: 47.6)` | `s` = 49,2 / 231,25 = 0,212757 ; rapport 0,937008 |
| billes égales (régression) | `BallSizes(cue: 50.8)` | `s` = 0,219676 (= 2 r_o) |
| poche | 76,2 / 231,25 ; 76,2 / 50,8 | 0,329514 ; 1,5 |
| ligne de départ (règle, dessinée) | 8 × 0,2 | 1,6 |
| procédé / blanche | 8,5 / 48 | 0,177083 (bornes 0,1667 et 0,1875) |
| écart de hauteur | 25,4 − 24,0 | 1,4 mm = 0,006054 case |
| aucune autre déclaration | grep sur `lib/`, `tool/` | pas de `ballRadius` hors module (règle d'architecture) |

### 5.2 Géométrie

| Test | Entrée | Attendu |
|---|---|---|
| fantôme, poche au nord | `O = (4, 2)`, `P = tm (4, 0)` | `G = (4, 2,213622)` |
| fantôme, diagonale | `O = (1, 1)`, `P = tl (0, 0)` | `G = (1,15105 ; 1,15105)` (0,213622 / √2 = 0,15105) |
| fantôme, diagonale est | `O = (6, 2)`, `P = br (8, 4)` | `G = (5,84895 ; 1,84895)` |
| bille sur la poche | `O = P` | `G = O` |
| ancien modèle exclu | `O = (4, 2)`, `P = tm` | `G.y ≠ 2,2` (écart 0,013622) |
| `aimOffset` nominal | `half` ; `quarter` ; `threeQuarter` | 0,109838 ; 0,161730 (= 0,109838 + 0,103784 / 2) ; 0,054919 |
| angle `θ` nominal | asin(`d` / 0,213622) | 0° ; 14,90° ; 30,94° ; 49,21° ; 71,81° |
| billes égales | `half`, `BallSizes` égales | 30,000° ; `quarter` 48,59° |
| `cutAngle` construit | `C = G − 3·(sin 30,94°, − cos 30,94°)` | 30,94° ± 1e-6 |
| `contactQuantity` | θ = 0, 14,90°, 30,94°, 49,21° | 1 ; 0,743 ; 0,486 ; 0,243 (± 0,001) |
| coupe ≥ 90° | `sin θ ≥ 1` | quantité 0 |
| V17, marge | toutes les `ghost_aim` des 29 séances | `|d − d_nominal| ≤ 0,07·s` et `≤ 0,05·s` après recalcul |
| contact, hauteur | `r_c · (r_o − r_c) / s` | 0,68 mm = 0,002941 case ; angle 1,624° |
| contact au-dessus de l'équateur | hauteur > 0 et < 0,03 · r_c | vrai |
| tolérance | `ghostAimTolerance` | 0,07·s = 0,014954 case |

### 5.3 Rendu des tailles

| Test | Entrée | Attendu |
|---|---|---|
| `TableGeometry` | surface 800 px de large (unité 100 px) | `radiusPxOf(white)` = 10,3784 ; `radiusPxOf(red)` = 10,9838 |
| `BilliardBall` blanche vs rouge, même `geometry` | diamètre rendu | 20,7568 px contre 21,9676 px |
| `TableDiagram` | ghost `impact` de la bille rouge en `(4, 2)` | rayon du cercle 10,3784 px ; centre à 21,3622 px du centre de la bille rouge |
| `BilliardCue` | pointe contre la blanche | à 10,3784 px du centre |
| timeline | impact d'un coup vers la poche | centre de la blanche à `s` (0,213622) du centre de la bille touchée |
| poche | ouverture 0,329514 | rayon peint = 0,164757 × unité (D6) |
| `BallContactDiagram` demi-bille | `r_o` = 40 px : distance horizontale entre centres | √(s² − d²) avec `s` = 77,80 px, `d` = 40 px : 66,73 px (billes inégales ; 69,28 px avant) |
| `ContactStrip` | 5 éléments | rayon blanche / rayon bille = 0,944882 sur chaque élément |
| écart visible | table de 9 cases (bandes comprises) à 360 px et à 1280 px | diamètre rouge − diamètre blanche = 0,0121 × 40 = 0,48 px puis 0,0121 × 142,2 = 1,72 px (le test affirme la **valeur**, pas la perception) |
| comparaison de tailles | cas « deux billes côte à côte » | rapport des diamètres 0,944882 ; légende « 48,0 mm » et « 50,8 mm » |
| projection | texte et traits | texte ≥ 14, traits ≥ 3 px à 360 px |

### 5.4 `CueBallTarget`

| Test | Attendu (R = 100 px, centre `(c_x, c_y)`) |
|---|---|
| anneaux | rayons 50 px et 100 px |
| marqueur `center` | centre `(c_x, c_y)`, rayon 17,7 px |
| `top` | `(c_x, c_y − 50)` |
| `bottom` | `(c_x, c_y + 50)` |
| `left` / `right` | `(c_x ∓ 50, c_y)` |
| `topRight` | `(c_x + 35,36, c_y − 35,36)` |
| R = 40 px | rayon du marqueur plancher 10 px et anneau de visibilité présent |
| profil | élévation 0° / 10° / 25° (`cueElevation`) |
| `Semantics` | libellé localisé fr et en, une seule étiquette parlée |
| l10n | mêmes clés en fr et en |

### 5.5 `PlayerFigure`

Géométrie pure (invariants de la fiche n° 1, tolérance 1e-9) :

| Test | Attendu |
|---|---|
| pied droit sous la main arrière | `x(rightFoot) == x(backHand)` |
| avant-bras vertical | `x(elbow) == x(backHand)` |
| inclinaison de la queue | angle de la queue = `cueElevation(level)` = 10° (talon plus haut que la pointe) |
| queue vers la blanche | la pointe est à la hauteur du centre de la blanche et la droite de la queue passe par ce centre |
| tête dans l'axe | `x(head)` compris entre `x(bridgeHand)` et `x(backHand)` ; hauteur de la tête > hauteur de la queue |
| main de chevalet | posée sur le rail (`frame`) ou sur le tapis (`surface`), jamais sous le tapis |
| proportions | queue / taille = 0,83 ± 0,02 ; plateau / taille = 0,48 ± 0,02 |
| repères | 6 pastilles numérotées 1 à 6, rectangles non sécants, tous dans le cadre |
| `focus` | repères hors focus estompés et sans ligne de légende |
| `headCase` | trois valeurs, œil directeur marqué |

Widgets : légendes présentes, ordre 1 à 6, texte ≥ 14 ; `Semantics` ; `view: both` s'empile à l'écran étroit ; rendu fr et en ; texte à 200 %.

### 5.6 `PowerRatio`

| Test | Attendu |
|---|---|
| zones | tableau des neuf combinaisons du 3.3 (0,09 → soft ; 0,30 → medium ; 0,60 et 1,00 → strong) |
| monotonie | `powerZone` ne décroît pas quand amplitude ou vitesse augmente (grille 3 × 3) |
| extrêmes source | (short, slow) = soft ; (long, fast) = strong |
| position d'un point | (long, fast) en haut à droite du plan ; (short, slow) en bas à gauche, à la précision d'un pixel |
| plan seul | pas de point, trois zones nommées |
| `highlight` | un seul point en évidence, coche et cadre (pas la couleur seule) |
| absence de « cran » | aucun texte ni clé l10n ne contient « cran » ou « niveau 1 à 5 » |
| `Semantics` | « amplitude longue, vitesse rapide : puissant » en fr, équivalent en en |

### 5.7 Données et contrats

| Test | Attendu |
|---|---|
| parseur | types anciens rejetés ; nouveaux types : clés requises et inconnues ; énumérations hors liste |
| contrat des 29 séances (`session_sheets_contract_test.dart`) | toutes parsées, rendues fr et en, deux publics, texte 200 %, tablette paysage |
| `fiches.dart --complete` | V7, V17, V24, V25 à V27 vertes |
| `diagrammes.dart` | placements : 0 chevauchement ; cercles `impact` de `proposition/` égaux à `G` recalculé (± 0,01) |
| galerie | chaque type de l'union a un cas dans `illustration_gallery.dart` |

### 5.8 Critères de fin

1. `scripts/check.sh --full` vert (format, analyse, architecture, tests, couverture ≥ 90 %, l10n, Widgetbook).
2. `dart run tool/fiches.dart --complete` et `dart run scripts/validate_seances.dart` verts ; `scripts/sync_fiches.sh --check`, `sync_diagrammes.sh --check`, `sync_catalogue.sh --check` verts.
3. Aucun identifiant `ballRadius`, `stance_top`, `cue_side`, `power_scale`, `StanceDiagram`, `CueSideView`, `PowerScale`, ni la chaîne « cran » dans `app/lib`, `app/assets`, `docs/knowledge/05-seances/catalogue` (grep).
4. La blanche est plus petite que la bille de but dans toutes les illustrations qui montrent les deux ; rapport vérifié par test.
5. Aucune chaîne en dur (clés fr et en identiques), aucune couleur en dur, `Semantics` localisés, textes ≥ 14 et traits ≥ 3 px.
6. Widgetbook : un cas par variante, galerie à jour, vérification visuelle en projection (largeur 360 px et 1280 px) par l'utilisateur.
7. Revue indépendante faite par `architecte-fsd`, `testeur-bdd`, `relecteur-pedagogique` dans des contextes séparés ; constats corrigés.
8. Aucun `TODO`, `skip`, `solo`, stub ; `docs/sources/` intact ; aucun commit sans demande explicite.

---

## 6. Risques et points ouverts

| Risque | Parade |
|---|---|
| Le personnage reste peu lisible sans maquette | Maquette en Widgetbook dès T5 (lot court), validation visuelle par l'utilisateur avant la migration des séances |
| `FORMAT` des diagrammes parle de « transcriptions à rayon 0.1 » | Mise à jour documentée (1.3) ; les positions `[S]` restent la mesure du PDF |
| Poches à 0,33 case peu visibles en projection | D6 : contrôle visuel ; repli possible sur un disque d'ombre plus large sans changer l'ouverture réelle |
| Grille amplitude × vitesse présentée comme règle fédérale | Mention `[Prop]` dans le FORMAT, l'`alt` et le badge « Proposition » (V19 : pas le mot « officiel ») |
| Ligne de départ 1,6 (`[FFB]`) contre 2,0 (`[Prop]`) | D2 tranchée le 2026-10-14 : 1,6 `[FFB]` ; positions YAML inchangées |
| Masses (94 g / 116 g) non dessinables | Non utilisées par les illustrations ; ne jamais les afficher comme règle fédérale |
| Longueur de queue non spécifiée | Dessinée à 0,83 H `[Prop]`, sans cote affichée |
| `tool/` importe `shared/lib` | À vérifier par `dart run tool/fiches.dart` et `check_architecture` ; repli : constantes dupliquées + test d'égalité |
| La différence de taille (5,5 %) est à peine visible à l'écran (≈ 0,5 px à 360 px) | Comparaison de tailles dédiée et légendée (1.4) ; pas d'exagération silencieuse |
| Personnage contraire à l'ADR 0004 | D8 : ADR 0005 avant T5, pictogramme neutre |
| Figure pour droitier seulement (joueurs gauchers, enfants comme adultes) | Légende explicite ; option miroir `handedness` à décider par l'animateur (non ajoutée au modèle) |
| Quantités du rétro : l'écart de 0,7 mm entre demi-bille et limite des 90° est indessinable | Dit dans le texte (doc de dimensions § 3.4), jamais dessiné ; hypothèse θ = 30° signalée `[Prop]` |
| Revue adverse du 2026-10-13 | Calculs de géométrie refaits à la main et par script (fantôme, angles, hauteur de contact, 16 `ghost_aim`, 191 diagrammes) : exacts, sauf les corrections consignées ci-dessus |
