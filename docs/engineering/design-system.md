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
  (`BrandAssets`, `AppTheme.light(assetPackage: …)`) et affiché par `FfbLogo`
  (accueil en grand, en-tête de chaque page en petit et décoratif). Son usage
  est encadré par la charte graphique de la fédération (contact
  `site@ffbillard.com`) : l'autorisation d'usage reste à obtenir ou à
  documenter. L'application se présente comme un outil d'animateur, jamais
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
| Rouge assombri (`secondary` clair) | `#b80d1a` | Proposition (dérivé du rouge FFB, 6,75:1) |
| Autres rôles `ColorScheme`, clair et sombre | voir `app_color_schemes.dart` | **Proposition** (non publiée par la FFB) |
| Billes : rouge `#d4101e`, jaune `#f2c200`, noire `#111111`, blanche `#ffffff` | `ball_colors.dart` | **Proposition** à valider visuellement par l'animateur |
| Tapis : `#7fb0cf` (clair), `#2d6a8a` (sombre) | `ball_colors.dart` | **Proposition** : le règlement FFB impose un drap « bleu poudre » sans valeur hexadécimale |
| Succès, attention (ambre) | `status_colors.dart` | **Proposition** |
| Rails gris bois `#8f8a82` (clair) / `#6f6a63` (sombre) | `table_colors.dart` | **Proposition** : teinte lue sur les schémas du PDF, assombrie pour que les losanges blancs atteignent 3:1 |
| Bande intérieure `#245572` / `#8cc1dd`, poches `#0d0d0d` / `#000000`, losanges `#ffffff` / `#f2f2f2` | `table_colors.dart` | **Proposition** (tracé des schémas fédéraux, aucune valeur publiée) |
| Ligne de départ `#0b2f40` / `#e6eef3`, grille pointillée `#3f7596` / `#8cc1dd` | `table_colors.dart` | **Proposition** |
| Queue : fût `#e8c98f`, talon `#3b2412` (contour `#f1ddb5` en sombre), virole `#f6f1e4`, procédé `#2b4a63` | `table_colors.dart` | **Proposition** |
| Craie bleue (point d'impact du procédé) `#1b55b5` | `table_colors.dart` | **Proposition** (point bleu des fiches) |
| Dimensions : bille = 0,1 case de rayon, ligne de départ x = 2, rails = 0,5 case | `table_geometry.dart` | **Proposition** `[Prop]` (voir `docs/knowledge/03-exercices/diagrammes/FORMAT.md`) |

Toute couleur « non publiée par la FFB » est une **proposition** : ne jamais la
présenter comme la couleur officielle.

## Où est quoi

```
app/lib/shared/ui/
├── theme/
│   ├── app_color_schemes.dart   # ColorScheme M3 explicite, clair + sombre (pas fromSeed)
│   ├── ball_colors.dart         # ThemeExtension : billes + tapis
│   ├── status_colors.dart       # ThemeExtension : succès, attention
│   ├── table_colors.dart        # ThemeExtension : rails, bande, poches, losanges, queue, craie
│   ├── app_typography.dart      # échelle Exo 2 (axe wght de la police variable)
│   ├── app_spacing.dart         # AppSpacing (4/8/16/24/32, cible 48) et AppRadii (8/12/16)
│   └── app_theme.dart           # AppTheme.light() / AppTheme.dark()
├── score_indicator.dart         # score x/n : pastilles pleines/creuses + texte
├── ball_chip.dart               # pastille de bille avec lettre
├── table_geometry.dart          # repère table (cases) <-> pixels, poches, rayon de bille
├── billiard_table.dart          # table peinte 2:1 + overlay (billes, flèches, queue)
├── billiard_ball.dart           # bille peinte (dégradé, reflet), nom parlé localisé
├── billiard_cue.dart            # queue de billard peinte, orientée autour de la pointe
├── ball_contact_diagram.dart    # schéma de la quantité de bille (+ point du procédé)
├── table_diagram/
│   ├── table_diagram_spec.dart  # modèle immuable d'un schéma d'exercice (Dart pur)
│   ├── diagram_timeline.dart    # déroulé : position des billes à l'instant t (Dart pur)
│   ├── table_diagram.dart       # rendu statique (table, billes, cercles, flèches, zones)
│   └── table_diagram_player.dart # lecteur animé : lecture, pause, rejouer, ×0,5 / ×1 / ×2
├── section_card.dart            # carte de section (titre = en-tête sémantique)
├── page_header.dart             # titre + sous-titre de page
├── empty_state.dart             # état vide (icône, message, action)
├── audience_badge.dart          # badge enfants / adultes
├── app_alert.dart               # alerte attention / persistante
└── responsive_body.dart         # largeur maximale tablette/desktop/web
app/assets/fonts/                # Exo 2 (variable) + OFL.txt (licence SIL OFL 1.1)
app/test/unit/shared/ui/         # tests widget + contrastes (theme/contrast_test.dart)
widgetbook/                      # catalogue (projet séparé, voir ci-dessous)
```

La police Exo 2 vient de `github.com/google/fonts` (`ofl/exo2`) ; la licence
OFL est conservée à côté des fichiers et mentionnée dans `app/pubspec.yaml`.
Pas de téléchargement à l'exécution (Linux, Windows, web hors ligne).

## Règles d'usage

1. **Jamais de couleur ou de style en dur** dans les écrans : lire
   `Theme.of(context).colorScheme`, `textTheme` et les extensions
   (`BallColors`, `StatusColors`, `TableColors`).
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
  rayon d'une bille (0,1 case) et le centre des six poches. Classe Dart pure
  (seulement `dart:ui`), sans widget.
- **`BilliardTable`** : surface 2:1 plus rails d'une demi-case (le widget a donc le
  rapport 9:5). `showGrid` (grille 8 × 4 pointillée), `showHeadString` (x = 2) et
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
| `DiagramArrow`, `DiagramArrowKind`, `DiagramBand` | flèche et rebonds | `arrows` (`kind` : `object`/`cue`/`indication`, `path`, `bounces`, `to`) |
| `DiagramZone` | zone grisée (rectangle) | `zones` (`shape: rect`, `from`, `to`) |
| `DiagramStep`, `ContactFraction` | un tir | `sequence` (`cue`, `hit`, `contact`, `pocket`, `repeat`, `from`) |
| `DiagramPocket` | poche (source unique des coordonnées ; `TablePocket` en dérive) | `tl`/`tm`/`tr`/`bl`/`bm`/`br` |
| `DiagramLayout` | dimensions de la table (cases, ligne de départ, rayon de bille) ; `TableGeometry` en dérive | : |
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
  deux rayons derrière la bille, dans l'axe de la poche.
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
  tirets (blanche), points (indication), repère rond à chaque rebond.
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
- `inset` (quantité de bille, point du procédé) n'est pas rendu dans le
  schéma ; utiliser `BallContactDiagram` à côté.
- La ligne de départ est toujours à x = 2 (écart de lecture consigné dans
  `uncertainties` de chaque transcription) ; `via`, `order` et `bridge` du
  FORMAT ne sont pas portés par le modèle.
- Les positions sont des mesures à ≈ 0,15 case : les trajectoires animées
  indiquent la direction du tir, pas une simulation physique (pas de rebond de
  la blanche après le contact, ni de choc entre billes).

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
