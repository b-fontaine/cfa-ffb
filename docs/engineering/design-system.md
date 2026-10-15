# Design system et Widgetbook

Décision : [ADR 0002](adr/0002-design-system-widgetbook.md). Recherches :
[identite-visuelle.md](research/identite-visuelle.md),
[widgetbook.md](research/widgetbook.md).

Le design system vit dans la couche `shared` de l'application
(`app/lib/shared/ui/`) et est documenté **et prévisualisé** dans le projet
Widgetbook séparé `widgetbook/`.

## Principes

- **Thème évoquant la FFB et le Blackball** : bleu FFB, rouge FFB assombri,
  tapis « bleu poudre », billes rouges/jaunes/noire/blanche, police Exo 2.
- **Logo FFB** : `assets/images/ffb-logo.png`, exposé par le thème
  (`BrandAssets`) et affiché par `FfbLogo`, **éteint par défaut**
  (`AppTheme.light(showFfbLogo: false)`, [ADR 0010](adr/0010-roles-de-couleur-bleu-tapis-et-accent.md)) :
  sans logo, rien n'est affiché ni réservé. Son usage est encadré par la
  charte graphique de la fédération (contact `site@ffbillard.com`) :
  l'autorisation écrite reste à obtenir ; `showFfbLogo: true` est le seul
  endroit à rallumer. L'application se présente comme un outil d'animateur, jamais
  comme une application officielle de la fédération.
- **Un seul jeu de jetons** pour les publics enfants et adultes ; seules la
  densité (`AppTheme.light(density: …)`) et la taille du texte (réglage
  système, `TextScaleAddon` dans Widgetbook) varient.
- **Jamais la couleur seule** : une bille porte sa lettre (R/J/N ou R/Y/B/W
  selon la langue), une alerte porte une icône et un libellé de niveau, un
  score porte son texte `x/n`, un public porte une icône et son nom.
- **Accessibilité** : contrastes WCAG vérifiés par test, cibles tactiles
  ≥ 48 dp, texte ≥ 12 px (corps 14–16 px), titres exposés comme en-têtes
  sémantiques, étiquettes parlées localisées.

## Provenance des couleurs

| Jeton | Valeur | Statut |
|---|---|---|
| Bleu FFB (`primary` clair) | `#1964af` | **Publié** : charte graphique FFB v1.0 (2015) |
| Rouge FFB (référence) | `#e10a19` | **Publié** (4,93:1 sur blanc : trop juste pour du texte) |
| Rouge assombri (`BrandColors.accent` clair) | `#b80d1a` | Proposition (dérivé du rouge FFB, 6,75:1) ; accent de marque hors `ColorScheme` (ADR 0010) |
| Bleu-tapis des états (`secondary` clair / sombre) | `#2f6b8a` / `#9fcfe8` (conteneurs `#cfe6f3` / `#1f5873`) | Proposition (famille du tapis, ADR 0010) |
| Autres rôles `ColorScheme`, clair et sombre | voir `app_color_schemes.dart` | **Proposition** (non publiée par la FFB) |
| Billes : rouge `#d4101e`, jaune `#f2c200`, noire `#111111`, blanche `#ffffff` | `ball_colors.dart` | **Proposition** à valider visuellement par l'animateur |
| Tapis : `#7fb0cf` (clair), `#2d6a8a` (sombre) | `ball_colors.dart` | **Proposition** : le règlement FFB impose un drap « bleu poudre » sans valeur hexadécimale |
| Succès, attention (ambre) | `status_colors.dart` | **Proposition** |
| Rails gris bois `#8f8a82` (clair) / `#6f6a63` (sombre) | `table_colors.dart` | **Proposition** : teinte lue sur les schémas du PDF, assombrie pour que les losanges blancs atteignent 3:1 |
| Bande intérieure `#245572` / `#8cc1dd`, poches `#0d0d0d` / `#000000`, losanges `#ffffff` / `#f2f2f2` | `table_colors.dart` | **Proposition** (tracé des schémas fédéraux, aucune valeur publiée) |
| Ligne de départ `#0b2f40` / `#e6eef3`, grille pointillée `#3f7596` / `#8cc1dd` | `table_colors.dart` | **Proposition** |
| Queue : fût `#e8c98f`, talon `#3b2412` (contour `#f1ddb5` en sombre), virole `#f6f1e4`, procédé `#2b4a63` | `table_colors.dart` | **Proposition** |
| Craie bleue (point d'impact du procédé) `#1b55b5` | `table_colors.dart` | **Proposition** (point bleu des fiches) |
| Dimensions du matériel : blanche 48,0 mm, bille de but 50,8 mm, poche 76,2 mm, surface 1850 × 925 mm (1 case = 231,25 mm) | `blackball_dimensions.dart` (source unique) | **`[FFB]`** (voir `docs/knowledge/02-techniques/06-dimensions-du-materiel.md`) ; la blanche est plus petite que les billes de but `[S]` |
| Dessin : ligne de départ x = 1,6 `[FFB]`, rails = 0,5 case | `table_geometry.dart` | Ligne `[FFB]` ; rails **Proposition** `[Prop]` (voir `docs/knowledge/03-exercices/diagrammes/FORMAT.md`) |

Toute couleur « non publiée par la FFB » est une **proposition** : ne jamais la
présenter comme la couleur officielle.

## Où est quoi

```
app/lib/shared/ui/
├── theme/
│   ├── app_color_schemes.dart   # ColorScheme M3 explicite, clair + sombre (pas fromSeed)
│   ├── ball_colors.dart         # ThemeExtension : billes + tapis
│   ├── brand_colors.dart        # ThemeExtension : accent de marque (rouge FFB)
│   ├── status_colors.dart       # ThemeExtension : succès, attention
│   ├── table_colors.dart        # ThemeExtension : rails, bande, poches, losanges, queue, craie
│   ├── app_typography.dart      # échelle Exo 2 (axe wght de la police variable)
│   ├── app_spacing.dart         # AppSpacing (4/8/16/24/32, cible 48) et AppRadii (8/12/16)
│   └── app_theme.dart           # AppTheme.light() / AppTheme.dark()
├── nav_icon.dart                # NavIcon : cinq glyphes de navigation (plein / contour)
├── score_indicator.dart         # score x/n : pastilles pleines/creuses + texte
├── student_chip.dart            # StudentChip : prénom + pastille d'état (à faire, manqué, réussi), cible ≥ 48 dp
├── pass_dots.dart               # PassDots : n pastilles tapables (pleine = empochée, creuse = manquée) + « x/n »
├── timer_chip.dart              # TimerChip : minuteur compact, ton neutre / attention / dépassé, lecture-pause
├── phase_timeline.dart          # PhaseTimeline : frise proportionnelle des phases (minutes), phase courante, tapable
├── step_app_bar.dart            # StepAppBar : en-tête d'étape (titre, « 6/9 », menu ⋮ d'actions injectées)
├── ball_chip.dart               # pastille de bille avec lettre
├── table_geometry.dart          # repère table (cases) <-> pixels, poches, rayon de bille
├── billiard_table.dart          # table peinte 2:1 + overlay (billes, flèches, queue)
├── billiard_ball.dart           # bille peinte (dégradé, reflet), nom parlé localisé
├── billiard_cue.dart            # queue de billard peinte, orientée autour de la pointe
├── ball_contact_diagram.dart    # schéma de la quantité de bille (+ point du procédé)
├── table_diagram/
│   ├── table_diagram_spec.dart  # modèle immuable d'un schéma d'exercice (Dart pur)
│   ├── label_placement.dart     # placement des étiquettes et des médaillons hors trajectoire (Dart pur)
│   ├── diagram_timeline.dart    # déroulé : position des billes à l'instant t (Dart pur)
│   ├── table_diagram.dart       # rendu statique (table, billes, cercles, flèches, zones)
│   └── table_diagram_player.dart # lecteur animé : lecture, pause, rejouer, ×0,5 / ×1 / ×2
├── section_card.dart            # carte de section (titre = en-tête sémantique)
├── page_header.dart             # titre + sous-titre de page
├── empty_state.dart             # état vide (icône, message, action)
├── audience_badge.dart          # badge enfants / adultes
├── proposal_badge.dart          # badge « Proposition » : élément [Prop], non fédéral, à valider (texte + icône)
├── contact_strip.dart           # bande des cinq quantités de bille (une en évidence)
├── ghost_aim_diagram.dart       # visée à la bille fantôme (table, ligne de visée, fantôme calculé)
├── cue_ball_target.dart         # la blanche de face avec une cible et le point d'impact du procédé (à l'échelle), profil de la queue
├── cue_side_view.dart           # queue et blanche vues de côté (hauteur, chevalet)
├── contact_height_view.dart     # deux billes inégales au contact, vue de côté, inclinaison exagérée ×10 et signalée
├── player_figure.dart           # joueur schématique de profil / de dessus, six repères numérotés et légendés
├── ball_size_comparison.dart    # la blanche (48,0 mm) et une bille de but (50,8 mm) côte à côte, à l'échelle, diamètres écrits
├── power_ratio.dart             # plan amplitude × vitesse : trois zones (doux, moyen, puissant), exemples placés
├── angle_mark.dart              # marque d'angle sur la table (rebond, rejet, angle droit)
├── pdf_page_chip.dart           # renvoi « Voir la page n du PDF » (texte seul)
├── presentation_scope.dart      # affichage agrandi pour montrer aux élèves
├── exercise_title.dart          # titre « bloc · exercice n », suffixé « · Proposition » pour un bloc [Prop]
├── app_alert.dart               # alerte attention / persistante
└── responsive_body.dart         # largeur maximale tablette/desktop/web
app/assets/fonts/                # Exo 2 (variable) + OFL.txt (licence SIL OFL 1.1)
app/test/unit/shared/ui/         # tests widget + contrastes (theme/contrast_test.dart)
widgetbook/                      # catalogue (projet séparé, voir ci-dessous)
```

La police Exo 2 vient de `github.com/google/fonts` (`ofl/exo2`) ; la licence
OFL est conservée à côté des fichiers et mentionnée dans `app/pubspec.yaml`.
Pas de téléchargement à l'exécution (Linux, Windows, web hors ligne).

### Rôles de couleur, surfaces et icônes (lot U1, R1 à R3)

[ADR 0010](adr/0010-roles-de-couleur-bleu-tapis-et-accent.md).

| Rôle | Jeton | Usage |
|---|---|---|
| État (sélection, puces, segments, pistes) | `secondary` / `secondaryContainer` (bleu-tapis) | indicateur de la navigation, `FilterChip`, `SegmentedButton`, piste de `ProgressMeter`, bord de `SectionCard` forte |
| Marque | `BrandColors.accent`, `onAccent`, `accentContainer`, `onAccentContainer` (rouge FFB) | ligne d'objectif de `ProgressChart`, badge « Enfants » ; **toujours via un composant** |
| Statut | `StatusColors` (`success`, `attention`) | réussite, alerte ambrée, ton `attention` de `TimerChip` |
| Erreur | `error` / `errorContainer` | échec, minuteur dépassé |

- **`BrandColors`** : `ThemeExtension` branchée dans `AppTheme.light` et
  `AppTheme.dark`. Un écran ne la lit pas directement ; `contrast_test.dart`
  vérifie chaque paire (≥ 4,5:1).
- **Surfaces** : `SectionCard.emphasis` (`SectionEmphasis.low` par défaut :
  `surfaceContainerLow`, sans bord ; `medium` : `surfaceContainer` et bord
  `outlineVariant` ; `high` : `surfaceContainer` et bord `secondary` de 2 dp,
  réservée à l'étape courante, à l'élève en cours de saisie, à l'alerte). Le
  titre reste l'en-tête sémantique : le niveau ne porte jamais seul le sens.
- **Logo** : `showFfbLogo` (faux par défaut) est le seul interrupteur ; sans
  logo, `FfbLogo` et `PageHeader` n'affichent ni ne réservent rien.
- **`NavIcon`** : cinq glyphes (`NavGlyph` : séances, élèves, résultats,
  aujourd'hui, plus), dessinés par `CustomPainter` sans police d'icônes, à la
  couleur et à la taille de l'`IconTheme` courant (plein = sélectionné,
  contour = non sélectionné). Exclu de la sémantique : le libellé de la
  destination porte le sens. `AppDestination` accepte des widgets d'icône
  (constructeur `AppDestination.material` pour une `IconData`).
- Widgetbook : feuille `[Design system]/Thème/Rôles de couleur`
  (`widgetbook/lib/support/color_roles_sheet.dart`), qui montre côte à côte,
  en thème clair et sombre, la barre de navigation, une puce et un segment
  sélectionnés, un compteur, une barre de progression, les trois emphases de
  `SectionCard`, `BrandColors` et `StatusColors`. Use cases :
  `nav_icon_use_cases.dart` et `section_card_use_cases.dart` (knob et trois
  niveaux).

### PassDots et TimerChip (lot U1, R4)

- **`PassDots`** : `value` est la **liste des issues par essai** (ordre des
  passages conservé pour la saisie en grille, U5) et `total` le nombre
  d'essais ; les essais absents de `value` sont manqués. Taper la pastille `k`
  appelle `onChanged` avec la liste complète (longueur `total`) dont l'essai
  `k` a basculé. États : interactif ; `readOnly` (bilan, fiche élève) ;
  désactivé (`onChanged == null`, atténué). Cible de 48 dp par pastille, retour
  à la ligne quand `total` est grand (aucun débordement à 320 dp). Jamais la
  couleur seule : pleine avec coche ou creuse avec contour (`secondary`,
  bleu-tapis). Sémantique : un bouton par pastille (« Essai k sur n :
  empochée / manquée ») dans un conteneur « x sur n empochées ».
- **`TimerChip`** : reçoit `remaining`, `running` et `onToggle` (aucune
  minuterie interne). Le ton vient de la fonction pure `timerToneFor` :
  `neutral` (≥ 1 min, `surfaceContainerHighest`), `attention` (de 0 inclus à
  1 min exclue, `StatusColors.attention`), `overdue` (< 0,
  `errorContainer`, temps affiché `+mm:ss`). Une icône accompagne les tons
  `attention` et `overdue`. La région vive (`liveRegion`) n'existe qu'à ces
  deux seuils : le lecteur d'écran n'annonce pas chaque seconde.
- Use cases Widgetbook : `pass_dots_use_cases.dart` (interactif, lecture
  seule, désactivé, vingt essais) et `timer_chip_use_cases.dart` (interactif
  avec curseur du temps, neutre, attention, dépassé, en pause).

### PhaseTimeline et StepAppBar (lot U1, R4)

- **`PhaseTimeline`** : `phases` est une liste de `PhaseTimelineEntry`
  (libellé, minutes ; données du parent, aucune dépendance au domaine),
  `currentIndex` (à partir de 0) et `onSelected(index)`. Largeur de chaque
  segment proportionnelle aux minutes, relevée à 48 dp pour rester tapable
  (le surplus est reparti au prorata sur les autres) ; la frise défile
  horizontalement si les segments minimaux ne tiennent pas. Phase courante :
  remplissage `secondaryContainer`, contour de 3 dp et libellé gras (jamais la
  couleur seule). Libellé tronqué à l'écran, entier dans la sémantique
  (« Phase 2 sur 5 : entraînement, 35 min, en cours ») et l'infobulle. Prévue
  pour 3 à 6 phases et des totaux de 90 ou 120 min. Non branchée avant U4 (guide)
  et U8 (détail).
- **`StepAppBar`** : `PreferredSizeWidget` de 48 dp. `title` (en-tête
  sémantique, une ligne, ellipse), `position` / `total` affichés « 6/9 » et
  annoncés « Étape 6 sur 9 », menu ⋮ construit depuis `actions`
  (`StepAppBarAction` : libellé, rappel, icône optionnelle ; pas de menu si la
  liste est vide), bouton `onBack` (flèche) ou `onClose` (croix) optionnel.
  Aucune logique de guide : libellés et rappels viennent du parent (U4).
- Use cases Widgetbook : `phase_timeline_use_cases.dart` (interactif adultes,
  enfants, phases courtes et libellés longs) et `step_app_bar_use_cases.dart`
  (interactif, bouton fermer sans menu, titre long).


### Saisie rapide en grille (lot U5, R11, corrige F4)

- **`StudentChip`** (`shared/ui`, R4) : `name`, `status`
  (`StudentChipStatus` : `todo`, `missed`, `reached`), `statusLabel`, `detail`
  optionnel (« 2/5 »), `maxWidth` et `semanticsLabel`. Aucune dépendance aux
  entités. Hauteur d'au moins 48 dp, prénom sur deux lignes au plus, une icône
  par état (jamais la couleur seule), bleu-tapis (`secondary`) pour « réussi »,
  aucun rouge d'état. `SectionCard.header` accepte un composant à la place du
  titre texte (le titre reste le libellé sémantique). Use cases :
  `student_chip_use_cases.dart` (interactif, trois états, prénom long).

- **`StudentPassRow`** (`features/record_results/presentation/ui/`) : une ligne
  par élève présent, des `PassDots` (une pastille par essai), le bouton
  « Saisir », l'état de validation à droite (« n sur 5 passages réussis ») et
  un résultat par passage en toutes lettres (« Passage 1 : 4 sur 6, réussi » ou
  « manqué »). La ligne passe en emphase bleu-tapis (`SectionEmphasis.high`)
  quand le dernier passage atteint le taux ; aucun rouge d'état ; jamais la
  couleur seule.
- **Compacte sous 600 dp** (`StudentPassRow.compactBreakpoint`) : prénom et
  cumul, pastilles sans score (`PassDots.showScore: false`), réglage des
  tentatives et « Saisir » sur une ligne de 48 dp ; dix élèves tiennent sur
  390 x 844. Le libellé complet est porté par la sémantique.
- **Refus d'un passage** : `AppAlert` niveau attention, jamais de rouge seul.
- **Tentatives** : le changement est rare, relégué sous la ligne
  (« Tentatives : n (fiche) » + « Changer pour ce passage » qui déplie le
  `CounterField`).
- **Sélecteur d'exercice** : `DropdownMenu` nommé (sémantique), libellé = nom
  de l'exercice de la séance du catalogue (`SessionOverview.exerciseName`,
  fourni par `SheetOption.exerciseTitles`), sinon « bloc · n° » ; bloc et taux
  en sous-titre ; `expandedInsets: zero`, `maxLines: 2`, sans troncature.
- **Historique** groupé par élève puis par exercice ; modifier et supprimer
  inchangés (ADR 0006).
- **Feuille basse depuis le guide** (`app/record_sheet.dart`, clé
  `record-sheet`) : « Noter les résultats » ouvre la saisie en feuille sur
  l'exercice courant ; le guide reste monté à la même étape ; la route plein
  écran et les liens profonds (ADR 0007) restent valides.
- Widgetbook : use cases `StudentPassRow` (dont « Liste compacte
  (téléphone) ») dans `feature_use_cases.dart`.

## Règles d'usage

0. **Une seule action principale par page** : `FilledButton` ; les autres
   actions sont `OutlinedButton` ou `TextButton` (R2, ADR 0010).
1. **Jamais de couleur ou de style en dur** dans les écrans : lire
   `Theme.of(context).colorScheme`, `textTheme` et les extensions
   (`BallColors`, `StatusColors`, `TableColors`, `BrandColors`). Les états
   (sélection, puces, pistes) lisent `secondary` (bleu-tapis) ; le rouge de
   marque passe par `BrandColors`, jamais directement dans un écran.
2. **Espacements et rayons** : constantes `AppSpacing` / `AppRadii`.
3. **Textes** : uniquement via `AppLocalizations` (clés `fr` **et** `en`,
   voir [i18n.md](i18n.md)). Un composant du design system reçoit ses textes
   métier en paramètre (`title`, `message`) et n'embarque que des libellés
   génériques localisés (nom de bille, niveau d'alerte).
4. **Indépendance du métier** : `shared/ui` n'importe aucune entité. Un
   composant exprime ses variantes avec ses propres enums (`BallKind`,
   `AudienceKind`, `AlertLevel`) ; la page mappe le domaine vers ces enums.
5. **Police dans Widgetbook** : l'application utilisée comme dépendance sert
   ses polices sous `packages/billard_cfa/Exo2` ; Widgetbook passe donc
   `AppTypography.packageFontFamily` à `AppTheme`.
6. Les billes ne sont jamais identifiées par la couleur seule (daltonisme).

## Table, billes et queue

Primitives de dessin des schémas d'exercices (les diagrammes YAML de
`docs/knowledge/03-exercices/diagrammes/` les animeront).

- **Repère** : `TableGeometry` convertit les cases (`x` ∈ [0, 8], `y` ∈ [0, 4],
  origine en haut à gauche de la surface, départ à gauche) en pixels, donne le
  rayon d'une bille **selon sa couleur** (`radiusPxOf(kind)` : blanche 0,1038
  case, bille de but 0,1098 case, cotes de `BlackballDimensions`), celui de la
  bille fantôme (`ghostRadiusPx`, une blanche), celui de l'ouverture d'une poche
  (`pocketRadiusPx`, 76,2 mm : 0,165 case) et le centre des six poches. Classe
  Dart pure (seulement `dart:ui`), sans widget. La blanche est toujours plus
  petite que la bille de but : à 360 px de large l'écart de diamètre n'est que
  d'environ 0,5 px (1,7 px à 1280 px), il se montre par la comparaison de tailles
  de Widgetbook, sans exagération silencieuse dans les schémas de table.
- **`BilliardTable`** : surface 2:1 plus rails d'une demi-case (le widget a donc le
  rapport 9:5). `showGrid` (grille 8 × 4 pointillée), `showHeadString` (x = 1,6) et
  `overlay` (`Widget Function(BuildContext, TableGeometry)`) pour poser billes,
  flèches et queue avec `geometry.ballRect(...)`.
- **`BilliardBall`** : diamètre en pixels ou issu de la géométrie. À partir de
  28 px la bille porte sa lettre (ou son libellé) ; en dessous, le libellé est posé
  à côté et le nom parlé localisé reste la source d'identification (jamais la
  couleur seule).
- **`BilliardCue`** : boîte `length × thickness`, pointe au milieu du bord droit,
  `angle` en radians autour de la pointe. `BilliardCue.positionedAgainst(...)` la
  pose, pointe contre la bille.
- **`BallContactDiagram`** : `ContactFraction` (pleine, trois-quarts, demi,
  quart, finesse) et `TipPoint` ; le recouvrement vient de
  `ContactFraction.centerOffset`.
- **Couleurs** : `TableColors` (extension) pour la table et la queue,
  `BallColors` pour tapis et billes. Aucune teinte en dur dans un composant ; les
  reflets et ombres sont dérivés des jetons.
- Chaque paire marquage/support de `TableColors` est testée à 3:1
  (`theme/table_colors_test.dart`).

## Diagrammes d'exercices

`app/lib/shared/ui/table_diagram/` rend les transcriptions YAML de
`docs/knowledge/03-exercices/diagrammes/` (format : `FORMAT.md`) par-dessus les
primitives ci-dessus. Aucune dépendance au domaine ; le repère est celui de la
table, en cases.

### Modèle (`table_diagram_spec.dart`, Dart pur)

| Classe / enum | Rôle | Champ du FORMAT |
|---|---|---|
| `TableDiagramSpec` | schéma complet | un élément de `diagrams` |
| `DiagramBall`, `BallKind`, `DiagramBallRole` | bille posée (état initial) | `balls` (`color`, `role` : `cue`/`object`/`obstacle`, `label`) |
| `DiagramGhost`, `DiagramGhostRole` | cercle creux | `ghosts` (`role` : `cue_start`/`impact`, `for`, `label`) |
| `DiagramArrow`, `DiagramArrowKind`, `DiagramBand` | flèche et rebonds | `arrows` (`kind` : `object`/`cue`/`indication`, `path`, `bounces`, `to`) ; `aim` (ligne de visée) n'existe que dans les illustrations de séance |
| `DiagramAnnotation` | texte posé sur la table (« 90° », « Bille fantôme »), déjà localisé par l'appelant | : (illustrations de séance) |
| `DiagramZone` | zone grisée (rectangle) | `zones` (`shape: rect`, `from`, `to`) |
| `DiagramInset`, `ContactFraction`, `TipPoint` | médaillon de la quantité de bille ; absent quand la fiche ne la précise pas (`contact: none`) | `inset` (`contact`, `tip_point`) |
| `DiagramStep`, `ContactFraction` | un tir | `sequence` (`cue`, `hit`, `contact`, `pocket`, `repeat`, `from`) |
| `DiagramPocket` | poche (source unique des coordonnées ; `TablePocket` en dérive) | `tl`/`tm`/`tr`/`bl`/`bm`/`br` |
| `DiagramLayout` | dimensions de la table (colonnes, rangées, ligne de départ ; les rayons de bille viennent de `BlackballDimensions`, blanche et bille de but distincts) ; `TableGeometry` en dérive | : |
| `DiagramPoint` (alias de `Point<double>`) | point `[x, y]` | `at`, `path`, `from`, `to` |

`contact: none` du FORMAT devient `DiagramStep.contact == null`. Le modèle se
remplit à la main (aucune lecture de YAML dans l'application) : recopier les
nombres de la transcription.

**Une seule définition par notion.** La couleur d'une bille est `BallKind`
(`ball_kind.dart`), la quantité de bille `ContactFraction`
(`contact_fraction.dart`), les poches `DiagramPocket`, les dimensions
`DiagramLayout` : tous en Dart pur, à côté du modèle. `TablePocket`,
`TableGeometry` et les composants Flutter en dérivent ; aucune copie à tenir à
jour. Les modèles du schéma sont `@freezed` : égalité par valeur, donc un parent
qui reconstruit un schéma identique ne relance pas l'animation et ne repeint
rien. Le fichier `table_diagram_spec.freezed.dart` est généré
(`scripts/generate.sh`), jamais versionné.

**Lecture du YAML : branché.** La conversion YAML → modèle est dans
`entities/exercise_diagram/data` (`parseDiagramPage`), le modèle dans son
domaine, et la présentation convertit vers `TableDiagramSpec`
(`tableDiagramSpecOf`). Le test de contrat porte sur cette conversion de
production, pas sur une copie locale.

**État : branché sur la fiche d'un exercice.** `TableDiagramPlayer` est affiché
par `ExerciseDiagramView` (`features/suggest_session/presentation/ui`), donc par
`pages/exercise_sheet`. Le texte parlé (`semanticLabel`) est localisé par
l'appelant (`exerciseDiagramSemantics`) ; la quantité de bille est écrite sous
le schéma (`exerciseDiagramContact`, liste via `ExerciseDiagram.contacts`,
domaine). Le chevalet n'est écrit qu'une fois, par la carte de la fiche, d'après
le catalogue (rang 1) ; un test de contrat vérifie que les transcriptions n'y
contredisent pas.
Scénarios : `app/test/bdd/exercise_sheet_diagram.feature` ; use cases
Widgetbook `ExerciseDiagramView` (un schéma, deux schémas, aucun, illisible).

### Lisibilité des schémas (lot U2, R5, corrige F2)

Règles de rendu de `TableDiagram`, vérifiées par des tests géométriques
(`exercise_diagram.feature`, `ball_sizes.feature`, tests unitaires de
`table_diagram`, `label_placement` et `billiard_cue`) :

| Règle | Détail |
|---|---|
| Étiquettes hors trajectoire | `placeLabels` essaie seize positions autour du point (huit points cardinaux, puis huit intermédiaires), sur quatre anneaux de distance croissante, et retient la première qui ne croise ni flèche, ni queue, ni bille, ni cercle, ni autre étiquette, ni le bord de la table (une étiquette qui en sortirait glisse vers l'intérieur). Un texte plus large que 40 % de la table passe à la ligne ; sur une table chargée, des largeurs plus étroites (25 %, 15 %) sont essayées avant de s'entasser. Calculé sur l'**état initial affiché** (la blanche part de son point de départ, pas de `at`) : les étiquettes suivent leur bille sans bouger pendant l'animation. |
| Halo | si aucune position n'est libre, l'étiquette est posée sur un halo de tapis (`BallColors.cloth` à 85 %). Le repli choisit le moins gênant : le bord (prohibitif), puis recouvrir une bille, un cercle ou une autre étiquette (50), puis croiser un trait (1 par segment, que le halo compense). |
| Pointe de flèche | la pointe qui arrive sur un cercle creux s'arrête à son bord : le cercle reste visible. |
| Queue | `BilliardCue.positionedAgainst` raccourcit la queue pour que les deux coins du talon restent dans la table, rails compris (jamais coupée). Longueur nominale 1450 mm quand elle tient. |
| Repères numérotés | cercle creux du diamètre de la blanche (`TableGeometry.ghostRadiusPx`) ; le numéro est écrit **dans** le cercle quand ce diamètre mesure au moins 28 px (même seuil que les lettres de bille) et qu'aucune bille n'est posée en son centre, **à côté** (placé comme les autres étiquettes) sinon. |
| Médaillon `inset` | `BallContactDiagram` (quantité + point du procédé) sur fond de surface, large de 20 % de la surface de jeu (au moins la largeur de son libellé, qui ne se coupe pas). `placeBlock` le pose en premier sur la table : coins (bas droite, bas gauche, haut droite, haut gauche), puis le long des bords, à pleine taille puis réduit à 75 %, sans jamais recouvrir une trajectoire, la queue, une bille, un cercle ou un point d'annotation ; les étiquettes l'évitent ensuite. S'il n'y a aucune place libre (ou si son libellé dépasse 25 % de la table, cas du téléphone), il est **écrit sous la table**, à droite, jamais sur un objet. Une seule quantité par schéma : celle de la fiche ; il reste affiché pendant toutes les étapes. |
| Présentation | sous `PresentationScope`, étiquettes de **16 px au moins** (taille logique, agrandissement du texte compris, `TableDiagram.presentationMinLabel`) ; hors présentation la taille ne change pas. La page de présentation borne la hauteur de la figure (`RunPresentationView`, `SheetIllustrationView.presentationHeight`) : sous une hauteur bornée, `TableDiagramPlayer` laisse au schéma ce que les commandes ne prennent pas, pour que schéma, commandes et légende tiennent au-dessus de la barre précédent/suivant ; sous 320 px de figure, la page défile. |
| Limites connues | mesuré sur les 111 schémas à billes du catalogue, avec la police de test (Ahem, environ deux fois plus large que la police réelle) : aucune étiquette ne recouvre une bille ou une autre étiquette à 390, 450 et 900 px à plat, ni à 900 px en présentation ; à 310 px à plat, un schéma (`initiation-p11-sb`, dont les « étiquettes » de billes sont des phrases) et trois croisements de flèche restent ; en présentation sous 900 px, le texte de 16 px ne tient pas sur les schémas de dix billes ou plus (39 recouvrements à 310 px). Le halo rend ces cas lisibles sans les supprimer. |

Widgetbook : « Statique, six repères », « six repères sur grande table »,
« médaillon de la quantité de bille », « médaillon sous la table (écran étroit) », « queue contre la bande », « En
présentation », et la visée à la bille fantôme (`GhostAimDiagram`).

### Déroulé (`DiagramTimeline`, Dart pur)

`DiagramTimeline.from(spec)` (ou `DiagramTimeline.of(spec)`, qui mémorise le
déroulé par instance de schéma) calcule, pour un avancement `t ∈ [0, 1]`
(`frameAt`) ou une durée (`frameAtTime`), la position de chaque bille
(`DiagramFrame.balls`) avec son état « empochée ». Les billes avancent à vitesse
constante sur la ligne brisée (3 cases par seconde à ×1, `casesPerSecond`).

1. La blanche suit sa flèche (rebonds compris) jusqu'au contact et s'y arrête.
2. La bille touchée part alors sur sa flèche `object` jusqu'à la poche, où elle
   disparaît.
3. Tir suivant : la blanche et la bille touchée reviennent à leur position
   initiale ; les billes déjà empochées restent absentes.
4. `DiagramFrame.cueAngle` donne la direction de la queue tant que la blanche
   n'a pas bougé.

Choix de lecture `[Prop]` (le FORMAT ne le précise pas) :

- **Flèche de la blanche** : celle qui part du cercle `from` du tir ; sinon la
  flèche `cue` de la blanche qui finit le plus près de la bille touchée (à
  0,6 case au plus). Sans flèche, la blanche vise en ligne droite le point situé
  à `r_c + r_o` (0,2136 case ; `2 r_o` pour deux billes de but) derrière la
  bille, dans l'axe de la poche.
- **Poche** : `DiagramStep.pocket`, sinon `DiagramArrow.pocket`. La flèche est
  prolongée (ou complétée) jusqu'au centre de la poche.
- Sans poche, la bille touchée ne bouge pas.

`DiagramTimeline.from` lève une `InvalidDiagramException` si un tir cite une bille ou un
cercle absent du schéma, ou si une bille, un cercle ou un point de flèche `cue`
ou `object` sort de la table (`x` hors de [0, 8] ou `y` hors de [0, 4], bords
compris) : c'est une erreur de transcription, jamais bornée en silence. Seule la
flèche `indication` (ligne de visée, qui se prolonge au-delà de la bande sur les
schémas) peut dépasser ; le rendu la rogne au bord de la table. Le message de
l'exception s'adresse aux développeurs. `TableDiagram` et `TableDiagramPlayer`
l'interceptent et affichent un `ErrorView` au libellé localisé
(`diagramInvalid`) : un schéma invalide ne produit jamais d'écran d'erreur
rouge, et le lecteur n'offre alors aucun contrôle.

### Rendu et lecteur

- **`TableDiagram(spec, semanticLabel, frame?, showGrid, showHeadString)`** :
  table, zones, cercles creux (numérotés), flèches, queue puis billes. Sans
  `frame`, l'état initial. `semanticLabel` est la description parlée de
  l'exercice, **fournie par l'appelant** et localisée par lui.
- **Flèches** : une seule teinte (`TableColors.headString`, contraste 3:1 déjà
  testé sur le tapis) ; la nature se lit au trait : plein (bille touchée),
  tirets (blanche), points (indication), trait-point (`aim`, visée de la
  blanche vers la bille fantôme), repère rond à chaque rebond.
- **Annotations** : `TableDiagramSpec.annotations` écrit chaque texte à côté de
  son point, dans la teinte `BallColors.onCloth`.
- **Billes** : à 28 px et plus, la lettre est sur la bille ; en dessous, la
  lettre est écrite à côté, suivie du repère (« J x4 »).
- **`TableDiagramPlayer(spec, semanticLabel, showGrid, showHeadString)`** :
  lecture/pause, rejouer, vitesse ×0,5 / ×1 / ×2 (`SegmentedButton`), boutons
  ≥ 48 dp, libellés localisés (`diagramPlay`, `diagramPause`, `diagramReplay`,
  `diagramSpeedHalf`/`Normal`/`Double`). Départ à l'arrêt, sur l'état initial.
  Avec `MediaQuery.disableAnimations`, l'image finale est affichée sans
  mouvement ; les boutons restent actifs et lancent la lecture à la demande.
  Sans tir à dérouler, seul le schéma est affiché.
  Le contrôleur utilise `AnimationBehavior.preserve` : le réglage système
  « réduire les animations » n'accélère pas la lecture demandée.
  Scénarios de comportement : `app/test/bdd/exercise_diagram.feature` et
  `ball_contact_diagram.feature`.

### Exemple

```dart
const spec = TableDiagramSpec(
  id: 'entrainement-p03-e1',
  balls: [
    DiagramBall(id: 'y1', color: BallKind.yellow,
        at: DiagramPoint(1.18, 2.07), label: 'x4'),
    DiagramBall(id: 'w', color: BallKind.white,
        at: DiagramPoint(1.99, 3.51), role: DiagramBallRole.cue),
  ],
  steps: [
    DiagramStep(cueId: 'w', hitId: 'y1', contact: ContactFraction.full,
        pocket: DiagramPocket.tl, repeat: 4),
  ],
);

TableDiagramPlayer(
  spec: spec,
  semanticLabel: l10n.exerciseFullBallDescription, // texte localisé de l'appelant
);
```

Exercices réels recopiés (Widgetbook, `widgetbook/lib/support/diagram_examples.dart`) :
bille pleine (`entrainement/p03.yaml`), demi-bille (`entrainement/p06.yaml`),
jeu de la puissance (`jeux/p03.yaml`), deux bandes (`entrainement/p16.yaml`).

### Limites

- Zones : rectangles seulement (`shape: rect`) ; `polygon` et `circle` ne sont
  pas dessinés.
- `repeat` (« x 4 ») est conservé dans le modèle et le repère « x4 » est
  affiché, mais le tir n'est joué qu'une fois.
- La ligne de départ est toujours à x = 1,6 `[FFB]` (écart de lecture consigné
  dans `uncertainties` de chaque transcription ; les mentions « et non 2,0 » ou « FORMAT : 2,0 [Prop] » y renvoient à l'ancienne convention 2,0 `[Prop]`, la lecture source ≈ 1,8 restant valable, comparée à 1,6) ; `via`, `order` et `bridge` du
  FORMAT ne sont pas portés par le modèle.
- Les positions sont des mesures à ≈ 0,15 case : les trajectoires animées
  indiquent la direction du tir, pas une simulation physique (pas de rebond de
  la blanche après le contact, ni de choc entre billes).

## Illustrations des séances

Les séances du catalogue
([FORMAT](../knowledge/05-seances/catalogue/FORMAT.md) § 6) utilisent une
liste fermée de 10 types d'illustration, tous **générés** (aucune photo de PDF).
Les composants vivent dans `shared/ui`, sans dépendance au domaine : ils
reçoivent des types primitifs ou des énumérations de `shared/lib`
(`ContactFraction`, `TipPoint`, `CueHeight`, `AngleKind`, `TablePocket`). Le
passage de l'union `Illustration` (domaine) vers ces composants est l'affaire de
l'`IllustrationMapper` (`entities/session_sheet/presentation`, lot L4), que la
galerie Widgetbook (`widgetbook/lib/support/illustration_gallery.dart`) utilise
telle quelle. `SheetIllustrationView` ajoute la légende et, quand l'élément qui
cite l'illustration est un `[Prop]`, le badge « Proposition » ; il reçoit les
schémas transcrits déjà résolus (`diagrams`, par identifiant de diagramme) : la
résolution est faite par le cas d'usage `GetSheet`, pas par l'entité. Le texte
alternatif (`alt`) de la séance remplace la description générée du composant.

| `type` du FORMAT | Composant | Paramètres | Géométrie pure (Dart, `shared/lib`) |
|---|---|---|---|
| `diagram_ref` | `TableDiagram` / `TableDiagramPlayer` | schéma transcrit, résolu par l'appelant | : |
| `table` | `TableDiagram` | `TableDiagramSpec` | : |
| `contact` | `BallContactDiagram` | `contact`, `tipPoint` (9 valeurs), `showTip` | `ContactFraction.aimOffset` (`contact_fraction.dart`) |
| `contact_strip` | `ContactStrip` | `fractions`, `highlight?`, `showSizeNote` | : |
| `ghost_aim` | `GhostAimDiagram` | `cue`, `object`, `pocket`, `fraction` | `ghostBallPosition`, `contactPoint`, `cutAngle`, `aimDistance`, `contactQuantity` (`ghost_ball_geometry.dart`) |
| `cue_ball_target` | `CueBallTarget` | `tipPoint`, `compare`, `cueHeight?` | `tipHeightFactor`, `cueElevation`, `tipOffsetShare` (`cue_side_geometry.dart`) ; `CueBallTargetGeometry` (rayon du procédé 0,177 R) |
| `player_figure` | `PlayerFigure` | `view`, `focus`, `leadEye?`, `headCase?`, `bridge` | `SidePose`, `TopPose`, `PlayerMark`, `HeadCase` (`player_figure_layout.dart`) |
| `ball_size` | `BallSizeComparison` | aucun | `BallSizes` (`blackball_dimensions.dart`) : rapport 48,0 / 50,8 = 0,945 |
| `contact_height` | `ContactHeightView` | aucun | `contactHeight`, `exaggeratedObjectRadius` (`cue_side_geometry.dart`) ; `BlackballDimensions.contactHeightAboveCueEquatorMm` |
| `power_ratio` | `PowerRatio` | `points` (≤ 2 : `amplitude`, `speed`, `label?`), `highlight?`, `distanceLabel?` | `powerZone`, `AmplitudeLevel`, `SpeedLevel` (`power_ratio.dart`) ; `PowerPlaneGeometry` |
| `angle` | `AngleMark` | `kind`, `vertex`, `rays` | `angleBetween`, `angleDegrees` (`angle_geometry.dart`) |
| `pdf_ref` | `PdfPageChip` | `file`, `page` | : |

Transversal : `PresentationScope` (affichage agrandi pour les élèves : texte
agrandi, légende en gros, `PresentationScope.isActive(context)`),
`ProvenanceBadge` (pastille de la source `[S]`/`[FFB]`/`[Web]`, ou badge
« Proposition » pour un `[Prop]` : le sens est écrit, jamais porté par la seule
couleur) et `FrenchContentNotice` (bandeau « contenu en français » sous une
interface qui n'est pas en français, ADR 0004 décision 12). `CueBallTarget`,
`PlayerFigure` et `PowerRatio` réservent la largeur de leurs légendes selon la
taille du texte système : aucun débordement à 200 %. `CueSideView` n'est plus
rendu par une séance (le type `cue_side` est retiré) ; le contact des deux
billes de côté est porté par `ContactHeightView` (type `contact_height`, D5
réalisé : `CueSideView.showContact` est supprimé).
`MissingPageView` est l'écran « page introuvable » (message localisé et retour à
l'accueil) partagé par `NotFoundPage` et par les pages de séance dont
l'identifiant est bien formé mais inconnu.

### Règles communes

- **Description parlée localisée** (fr et en) : chaque composant enveloppe son
  rendu dans un `Semantics` unique (`excludeSemantics`), qui dit ce qui est
  montré (quantité, poche, hauteur, niveau, angle en degrés).
- **Jamais la couleur seule** : mise en évidence par cadre épais et coche
  (`ContactStrip`, `PowerRatio`), zones de puissance par un motif (aucun,
  hachures, croisillons) et par leur nom écrit dans la zone, nature de la
  flèche par le trait, parties du joueur par une pastille numérotée et une
  légende, angle écrit en degrés.
- **Projection** : textes à 14 ou plus, traits d'au moins 3 px, pastilles de
  28 px ; la légende du joueur est une liste hors du dessin.
- **Thème** : couleurs lues dans `ColorScheme`, `BallColors` et `TableColors` ;
  aucune teinte en dur.
- **Échelle** : les tables et les contacts sont à l'échelle du matériel (blanche
  48,0 mm, bille de but 50,8 mm) ; le joueur, le profil de la queue et le plan
  de dosage sont schématiques (`[Prop]`, billes agrandies pour le joueur) ; l'illustration prend la provenance de l'élément de séance
  qui la référence, le badge « Proposition » est posé par la page.
- **Largeur** : les composants s'adaptent à la largeur donnée (passage à la
  ligne de `ContactStrip`, étiquettes sans retour à la ligne de la posture) ;
  chaque use case a une variante en largeur réduite.

### Choix de rendu `[Prop]`

- **Bille fantôme** : `G = O - s · unit(P - O)` avec `s = r_c + r_o` (0,2136
  case : c'est une blanche, dessinée au rayon `r_c`) ; le point de contact
  `O - r_o · unit(P - O)` est un petit point plein. La quantité de bille
  annoncée (`fraction`) nomme l'illustration, sa cohérence avec la géométrie
  (`|d - d_nominal| ≤ 0,07 s`) est contrôlée par la règle V17 (outil et test de
  contrat), pas par le composant.
- **Contact vu de côté** (`ContactHeightView`, type `contact_height`, D5) :
  une bille de but touche la blanche, toutes deux posées sur le tapis ; le
  contact est au-dessus de l'équateur de la blanche (fiche n° 4 `[S]` ; 0,68 mm
  et 1,62° en réalité, dérivés des diamètres). L'**inclinaison** de la ligne des
  centres est **exagérée ×10** (16,24°, `exaggeratedObjectRadius`) pour être
  visible : la légende (« Inclinaison exagérée ×10 … Ce dessin n'est pas une mesure »)
  et la description parlée le disent, jamais présenté comme une mesure ; point
  de contact plein et équateur en pointillé, nommés dans une légende (texte
  16 px, traits 3 px).
- **Hauteur de la queue** (`CueHeight`, schématique) : `low` talon presque à
  plat (0°), `level` inclinaison moyenne (10°), `high` talon relevé (25°).
  De côté, un impact à gauche ou à droite ne se voit pas : il est dessiné à
  hauteur du centre et dit dans la description parlée. Le chevalet
  (`CueBridge.frame` sur le rail, `CueBridge.surface` sur le tapis) est un
  paramètre du composant que le FORMAT ne porte pas encore ; absent, aucune main
  n'est dessinée.
- **Joueur** (`PlayerFigure`) : pictogramme neutre (ni visage, ni sexe, ni âge,
  une seule couleur de figure, les membres éloignés plus clairs), droitier, qui
  regarde vers la droite du dessin ; de dessus, sa droite est donc en bas.
  Proportions `[Prop]` (plateau 0,48 H, queue 0,83 H, talon relevé de 10°) ;
  billes agrandies, dit dans la description parlée. L'œil marqué d'une cible
  est `leadEye`, sinon celui de `headCase` ; aucun quand la queue passe entre
  les deux yeux. Cette figure renverse la décision « pas de silhouette
  humaine » de l'ADR 0004 : voir l'ADR 0005.
- **Cible sur la blanche** (`CueBallTarget`) : anneaux à mi-rayon et au bord,
  point d'impact à mi-rayon du centre `[Prop]` ; le procédé (8,5 mm) est dessiné
  à l'échelle de la blanche (48,0 mm), plancher de 10 px de rayon avec un anneau
  pointillé, et la phrase « à l'échelle » n'est alors pas écrite.
- **Tailles des billes** (`BallSizeComparison`) : la blanche (48,0 mm) et une
  bille de but (50,8 mm) côte à côte, à la même échelle, diamètres écrits sous
  les billes ; c'est la seule figure où la différence se voit à l'écran. Toute
  autre figure tire ses rayons de `blackball_dimensions.dart`.
- **Dosage** (`PowerRatio`) : la zone est le produit `amplitude × vitesse`
  (limites hyperboliques, 0,2 et 0,5), seuls les deux extrêmes viennent de la
  fiche n° 2 ; aucun « cran » ni niveau numéroté. Un `highlight` hors de
  `points` n'est pas mis en évidence (le parseur de séance le refuse).
- **Angle** : la valeur en degrés est **calculée** depuis les deux premiers
  rayons (`angleDegrees`) ; `right_angle` dessine un carré plutôt qu'un arc. Avec
  moins de deux rayons, aucun angle n'est tracé ni écrit.

### Galerie Widgetbook

Use case **« Galerie des illustrations »** (`[Design system]/Illustrations`) :
les 12 types côte à côte, chacun avec sa légende. Les illustrations du pilote
`08-demi-bille-1.yaml` sont lues par le vrai parseur (`parseSessionSheet`) et
résolues dans la vraie bibliothèque de schémas ; les types que le pilote
n'utilise pas (`table`, `cue_ball_target`, `player_figure`, `contact_height`,
`power_ratio`,
`angle`, `pdf_ref`) sont des exemples, signalés « exemple hors pilote ». Le
commutateur « affichage élèves » montre chaque illustration dans un
`PresentationScope`.

## Garde-fou : contrastes

`app/test/unit/shared/ui/theme/contrast_test.dart` recalcule, avec la formule
WCAG 2.x, le ratio de chaque paire `onX/X` des deux schémas (et des extensions
billes/statuts) : **≥ 4,5:1** pour le texte, **≥ 3:1** pour `outline` contre la
surface. Il échoue si une valeur est modifiée sans respecter ces seuils.

## Ajouter un composant et son use case

1. **Comportement** : si le composant change ce que l'utilisateur voit dans
   l'application, écrire d'abord un scénario `.feature`
   (`app/test/bdd/`, voir [testing.md](testing.md)).
2. **Test widget rouge** dans `app/test/unit/shared/ui/<composant>_test.dart`
   (helper `pump_ui.dart` : thème + l10n fr/en), puis le composant minimal dans
   `app/lib/shared/ui/<composant>.dart` (TDD).
3. **Textes** : clés dans `app_fr.arb` **et** `app_en.arb`, puis
   `scripts/generate.sh`.
4. **Use case Widgetbook** dans `widgetbook/lib/use_cases/<composant>_use_cases.dart` :

   ```dart
   @widgetbook.UseCase(
     name: 'Interactif',
     type: MonComposant,
     path: '[Design system]/Composants',
   )
   Widget buildMonComposantUseCase(BuildContext context) =>
       MonComposant(label: context.knobs.string(label: 'label', initialValue: 'x'));
   ```

   Prévoir un use case interactif (knobs) et les états limites (vide, plein,
   erreur).
5. `scripts/generate_widgetbook.sh`, puis `scripts/check.sh --full` : le
   garde-fou `scripts/check_widgetbook.dart` échoue si un widget public de
   `shared/ui`, `widgets`, `pages` ou `features/*/presentation/ui` n'a aucun
   use case.

## Widgetbook

- Projet Flutter séparé `widgetbook/` (package `widgetbook_workspace`),
  dépendance `billard_cfa: path: ../app`. Il reste hors de la résolution de
  l'application : le générateur Widgetbook 3.x contraint `analyzer` (< 14) alors
  que `freezed` 4 exige `analyzer` ≥ 14 ; seules les dépendances d'exécution de
  l'app entrent dans la résolution de Widgetbook.
- Versions : `widgetbook ^3.25.0`, `widgetbook_annotation ^3.11.0`, dev
  `widgetbook_generator ^3.24.0` et `build_runner` (pas la 4.0 bêta).
- Addons : viewports (mobile, tablette, desktop), thème clair/sombre,
  localisation fr/en, échelle de texte, grille, inspecteur. `DeviceFrameAddon`
  et `AccessibilityAddon` sont dépréciés et non utilisés.
- Code généré (`lib/main.directories.g.dart`) : non versionné, produit par
  `scripts/generate_widgetbook.sh`. Le projet dépend du code généré de `app/`
  (freezed) : lancer d'abord `scripts/generate.sh`.

```bash
scripts/generate.sh && scripts/generate_widgetbook.sh   # code généré
cd widgetbook && flutter run -d chrome                  # catalogue en local
cd widgetbook && flutter build web                      # build de contrôle
dart run scripts/check_widgetbook.dart app widgetbook   # use cases complets
```

## Catalogue des pages et des composants du suivi

`widgetbook/lib/support/preview_world.dart` compose le graphe réel (dépôts en
mémoire, catalogue de l'asset, horloge figée au 12/10/2026) et amorce un club de
démonstration (une élève enfants avec passages réussis et manqués, un élève
adulte). Les use cases des pages et des vues du suivi
(`app_pages_use_cases.dart`, `feature_use_cases.dart`, `shared_ui_use_cases.dart`)
s'appuient sur ce monde via `WorldScope` / `LoadedScope`, avec les vrais Bloc.
