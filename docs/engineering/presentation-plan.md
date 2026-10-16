# Plan de conception : présentation plein écran (lot U3)

Statut : **livré le 2026-10-16**. Décision structurante :
[ADR 0017](adr/0017-plein-ecran-port-controleur-partage.md). Écarts avec la
conception, voir § 16. Source : roadmap (U3,
F1, lot 13), [guide-mener-plan.md](guide-mener-plan.md) § 9 (point d'accroche du
menu ⋮), [ux/recommandations-design.md](ux/recommandations-design.md), ADR 0010
(rôles de couleur), `design-system.md`, `testing.md`. Dépendances : U4 (menu ⋮ du
guide, route hors shell) et U7 (motif de tapis `ClothPattern`), livrés.

## 1. Constat sur le code actuel

- `RunPresentationView` (features/run_sheet) calcule la hauteur du schéma **par
  mesure de texte** (`_textHeight`, `_figureHeight`, constantes `_badgeHeight`,
  `_minFigureHeight`) puis la passe à `TableDiagramPlayer.maxHeight`. Le calcul
  recopie les marges de `PresentationScope` à la main : il se désynchronise dès
  qu'un padding change. C'est la cause de F1 (légende du bas tronquée à 1280 × 800,
  commandes du lecteur coupées) : la figure est bornée, pas la page.
- `PresentationScope` agrandit le texte (×1,5), peint un fond **opaque**
  (`surface`) et écrit la légende sous le contenu ; il ne sait pas laisser voir un
  motif derrière lui.
- `TableDiagramPlayer` borne déjà schéma + commandes (lecture, rejouer, vitesse)
  par `maxHeight` via `_FigureAboveControls` (rendu sur mesure, minimum 120 px).
  Ce mécanisme est sain et **réutilisé** tel quel.
- `ClothPattern` (shared/ui) : losanges bleu-tapis à 6 % d'opacité, exclus de la
  sémantique, utilisé seulement par `home_page`.
- Aucun plein écran : ni API Fullscreen web, ni `SystemChrome`. `package:web` est
  seulement une dépendance **transitive** (`pubspec.lock`) ; `dart:js_interop`
  fait partie du SDK. Le menu ⋮ du guide est une liste de `StepAppBarAction`
  (`run_sheet_view.dart`).
- La page `SheetPresentationPage` est de premier niveau, `ResponsiveBody(maxWidth:
  1200)`, `Scaffold` + `SafeArea`.

## 2. Périmètre

**Dans U3** : `DiagramStage` ; port `FullscreenController` + implémentations web et
mobile + `FullscreenCubit` ; entrée « Plein écran » (présentation et menu ⋮ du
guide) ; indication « Tournez l'appareil » ; fond `ClothPattern` ; l10n fr + en ;
BDD et tests ; ADR 0017.

**Hors U3** : plein écran sur le bureau natif (Linux, macOS, Windows : non pris
en charge, entrée masquée) ; verrouillage d'orientation (on indique, on ne force
pas) ; mode « télécommande » ; nouvelle dépendance ; test en PWA installée
(lot 15, déjà au roadmap).

## 3. `DiagramStage` (shared/ui/diagram_stage.dart)

Remplace le calcul de hauteur par mesure de texte : **la mise en page réserve
elle-même** ce qui est fixe, le schéma reçoit le reste. Plus de constantes
recopiées, plus de `TextPainter`.

### Contrat

```
DiagramStage(
  header,                       // titre + position + boutons (Plein écran, Fermer)
  figure: (context, size) => …, // size = zone du schéma (largeur, hauteur max)
  caption,                      // String? légende, texte ×1,5 dans un panneau
  badge,                        // Widget? ex. ProposalBadge
  bottomBar,                    // précédent / suivant, 56 dp
  figureAspect,                 // largeur / hauteur du schéma, pour l'indication
)
```

### Algorithme (rendu sur mesure `_RenderStage`, même patron que
`_RenderFigureAboveControls`)

1. Mettre en page **d'abord** les parties fixes à leur hauteur naturelle sous la
   largeur donnée : `header`, `caption` (+ `badge`), `bottomBar`. La légende n'est
   donc jamais mesurée à la main et **jamais tronquée**.
2. La zone du schéma reçoit `viewportHeight - fixes - écarts`.
3. Si cette zone est **inférieure à 160 dp**, la scène prend la hauteur
   `fixes + 160` et défile (`SingleChildScrollView` extérieur) au lieu d'écraser
   le schéma. Le mode compact (4.) évite ce cas sur téléphone en paysage.
4. **Compact** (hauteur < 480 dp, ex. téléphone en paysage 844 × 390) : le titre
   visuel passe dans la barre basse (position au centre), le titre reste dans la
   sémantique (`Semantics(header: true)`), la légende passe en `bodyLarge` ×1,5.
5. La zone du schéma est donnée à un `LayoutBuilder` : `TableDiagramPlayer(maxHeight:
   zone.height)` conserve ses commandes de lecture **dans** la zone (non
   coupées) ; le schéma prend la plus grande taille possible respectant le ratio
   de la table (les bandes de tapis restent visibles autour, voir 6.).
6. Fond : `ClothPattern` derrière **toute la scène**, schéma et légende au-dessus
   (voir § 6). La légende est posée sur un panneau `surface` arrondi : le contraste
   du texte ne dépend jamais du motif.

Le contrat de l'indication « tournez l'appareil » est exposé par la scène
(`figureAspect`, § 5). Étapes à plusieurs illustrations ou sans schéma de table :
inchangées (colonne défilante existante), `DiagramStage` ne sert que les étapes
« un schéma de table + légende ». `_figureHeight`, `_textHeight`, `_badgeHeight`,
`_minFigureHeight`, `_presentationScale` sont supprimés de `RunPresentationView`.

### Tailles de contrôle (F1)

| Taille | Attendu |
|--------|---------|
| 1280 × 800 (F1) | schéma large, légende entière, barre basse visible, pas de défilement |
| 900 × 600 | idem ; schéma plus petit |
| 390 × 844 (portrait) | schéma limité par la largeur, légende entière, indication « tournez l'appareil » |
| 844 × 390 (paysage, compact) | schéma ≥ 160 dp, légende entière, barre basse visible |
| 320 dp de large, texte système ×1,3 | rien ne déborde ; défilement vertical autorisé, jamais horizontal |

## 4. Plein écran natif

### Port (shared/lib/fullscreen_controller.dart, Dart pur)

```
abstract interface class FullscreenController {
  bool get isSupported;        // l'API existe ici (sinon l'entrée est masquée)
  bool get isActive;
  Stream<bool> get changes;    // vrai/faux à chaque bascule, y compris Échap navigateur
  Future<void> enter();        // doit être appelé dans le geste de l'utilisateur
  Future<void> exit();
}
```

`enter`/`exit` ne lèvent pas : en cas de refus, `isActive` reste faux et un
`FullscreenFailure` n'est pas nécessaire (l'interface rapporte l'état réel via
`changes`).

### Implémentations (lib/app/platform/, couche `app`, seule autorisée à connaître
la plate-forme ; aucune dépendance ajoutée)

| Fichier | Rôle |
|---------|------|
| `fullscreen_controller_factory.dart` | `FullscreenController createFullscreenController()` ; import conditionnel : `if (dart.library.js_interop) fullscreen_controller_web.dart`, sinon `fullscreen_controller_native.dart` |
| `fullscreen_controller_web.dart` | `dart:js_interop` : liaisons minimales (`document.documentElement.requestFullscreen()`, `document.exitFullscreen()`, `document.fullscreenElement`, `document.fullscreenEnabled`, événement `fullscreenchange`) ; `isSupported = fullscreenEnabled` (faux sur iPhone Safari) ; promesse rejetée interceptée |
| `fullscreen_controller_native.dart` | `SystemChrome.setEnabledSystemUIMode(immersiveSticky)` / `edgeToEdge` ; `isSupported` vrai seulement sur Android et iOS ; flux interne |

Enregistrement : `lib/app/di/fullscreen_module.dart` (`@singleton`, fabrique) ;
`injection.config.dart` régénéré par build_runner, jamais édité. **Un seul
contrôleur partagé** par la présentation et le guide : le plein écran survit à la
navigation guide <-> présentation (cas d'usage principal : on passe en plein écran
une fois pour la séance).

### `FullscreenCubit` (features/run_sheet/presentation/bloc/)

`@injectable`, état `FullscreenState(supported, active)` ; abonné à `changes` ;
`toggle()` appelle `enter`/`exit`. Fourni par `SheetPresentationPage` et par la
page du guide (même instance de contrôleur via get_it). Les vues le lisent avec
`BlocBuilder` : aucune vue ne touche à get_it.

### Entrées d'interface

- Présentation : bouton `FilledButton.tonalIcon` « Plein écran » / « Quitter le
  plein écran » dans l'en-tête, à côté de « Fermer », cible ≥ 48 dp ; masqué si
  `!supported`.
- Guide : `StepAppBarAction` « Plein écran » dans le menu ⋮ (point d'accroche de
  guide-mener-plan § 9), même condition, entre « La séance » et « Minuteur à
  zéro ». Le contrat de `RunSheetView` ne change pas : le cubit est lu depuis le
  contexte.
- Clavier (web) : `F` bascule le plein écran dans la présentation. Échap quitte
  d'abord le plein écran (le navigateur le consomme) ; l'application ne ferme
  pas la présentation sur ce même Échap (le `CallbackShortcuts` ne reçoit pas la
  touche).
- Fermer la présentation **ne quitte pas** le plein écran.

## 5. « Tournez l'appareil »

Règle pure (shared/lib/stage_fit.dart, testable sans widget) :
`isWidthLimited(Size zone, double aspect)` vrai quand `zone.width / aspect <=
zone.height`, c'est-à-dire que la largeur, pas la hauteur, borne le schéma.
Affichage : `orientation == portrait && isWidthLimited(zone, figureAspect)` et
la zone est plus haute que large.

Forme : bandeau discret au-dessus du schéma (icône `screen_rotation`, texte
`presentationRotateHint`, bouton de fermeture de 48 dp). **Non bloquant** : le
schéma reste utilisable, le bandeau est exclu de la navigation clavier
prioritaire et se retire pour le reste de l'étape à la fermeture (état local du
widget, pas de persistance). Annoncé en région vive (`liveRegion`) une seule fois.
Jamais affiché en paysage ni quand la hauteur est le facteur limitant.

## 6. Fond `ClothPattern` et contraste

- `ClothPattern` est posé en `Stack` derrière `DiagramStage` (page, pas dans le
  widget partagé de la légende). Il reste à 6 % d'opacité, `ExcludeSemantics`.
- `PresentationScope` reçoit `transparent` (défaut `false` : comportement
  inchangé pour les autres usages) pour ne pas peindre `surface` par-dessus le
  motif ; l'agrandissement du texte est conservé.
- Texte (titre, légende) : sur panneau `surface` ou sur motif atténué ; couleur
  `onSurface`. Un test calcule le contraste du texte sur le pire pixel du motif
  (`surface` mélangé à `cloth` à 6 %) et exige ≥ 4,5 (7 pour la légende ×1,5, texte
  « grand » : ≥ 3 suffit mais on garde 4,5).
- ADR 0010 : aucun rouge comme état (le rouge FFB reste un accent de marque et
  n'apparaît pas dans la scène) ; état « plein écran actif » rendu en bleu-tapis
  (`secondary`) et par le libellé, pas par la couleur seule ; cibles ≥ 48 dp
  (bouton plein écran, fermeture du bandeau, précédent/suivant à 56).
- Thème sombre : même mélange, vérifié par le même test (clair et sombre).

## 7. Fichiers par couche (FSD, imports vers le bas uniquement)

| Couche | Fichier | Nature |
|--------|---------|--------|
| app | `app/platform/fullscreen_controller_{factory,web,native}.dart` | implémentations ; exclues de la couverture si les scripts le prévoient (voir § 10) |
| app | `app/di/fullscreen_module.dart` | enregistrement get_it |
| shared/lib | `fullscreen_controller.dart` | port Dart pur |
| shared/lib | `stage_fit.dart` | `isWidthLimited` pur |
| shared/ui | `diagram_stage.dart` | scène (mise en page, compact, défilement) |
| shared/ui | `rotate_hint.dart` | bandeau « Tournez l'appareil » |
| shared/ui | `presentation_scope.dart` | paramètre `transparent` |
| features/run_sheet | `presentation/bloc/fullscreen_cubit.dart` (+ état freezed) | cubit |
| features/run_sheet | `presentation/ui/run_presentation_view.dart` | recomposé sur `DiagramStage`, calcul de hauteur supprimé |
| features/run_sheet | `presentation/ui/run_sheet_view.dart` | entrée du menu ⋮ |
| pages | `sheet_presentation/…/sheet_presentation_page.dart`, page du guide | `BlocProvider<FullscreenCubit>`, `ClothPattern` en fond |
| test/support | `fake_fullscreen_controller.dart` | double : `supported`, `active`, compteurs, `emit` |

Fichiers générés (`*.freezed.dart`, `injection.config.dart`) : régénérés par
build_runner uniquement.

## 8. Libellés (fr + en, mêmes clés)

| Clé | fr | en |
|-----|----|----|
| `presentationFullscreen` | Plein écran | Full screen |
| `presentationFullscreenExit` | Quitter le plein écran | Exit full screen |
| `presentationRotateHint` | Tournez l'appareil pour agrandir le schéma | Rotate the device to enlarge the diagram |
| `presentationRotateDismiss` | Masquer l'indication | Dismiss the hint |
| `guideFullscreen` | Plein écran | Full screen |
| `guideFullscreenExit` | Quitter le plein écran | Exit full screen |

`presentationFullscreen*` et `guideFullscreen*` restent deux jeux de clés pour que
le menu ⋮ puisse évoluer sans toucher la présentation (convention du dépôt : une
clé par écran). Régénérer avec gen-l10n ; `scripts/check.sh --full` contrôle la
parité.

## 9. ADR 0017 (à écrire avec le lot)

Titre : « Plein écran : port `FullscreenController`, API Fullscreen via
`dart:js_interop`, un seul contrôleur partagé ». Décisions : (1) port Dart pur,
implémentations en couche `app` par import conditionnel ; (2) **aucune nouvelle
dépendance** : `dart:js_interop` du SDK plutôt que `package:web` (transitive, la
passer en directe est une décision de dépendance qu'on évite) ; (3) l'entrée
n'apparaît que si `isSupported` (iPhone Safari n'a pas l'API ; en PWA installée
`display: standalone`, le plein écran est déjà obtenu) ; (4) le plein écran est
global à la séance : fermer la présentation ne le quitte pas ; (5) `DiagramStage`
remplace la mesure de texte. Alternatives rejetées : `package:web` direct,
`universal_html`, plugin `fullscreen`, verrouillage d'orientation. Mise à jour du
`adr/README.md`, de la roadmap (U3 livré, F1 soldé), de `design-system.md`
(`DiagramStage`, `RotateHint`) et de `testing.md` (double de plein écran).

## 10. Scénarios BDD à écrire d'abord (rouge constaté)

`test/bdd/session_presentation_stage.feature` (+ steps ; étendre
`ui_world.dart` pour le double de plein écran et les tailles d'écran) :

1. **Légende entière à 1280 × 800** : étape avec schéma et légende longue ->
   la légende est visible en entier, les boutons Précédent et Suivant sont
   visibles, aucune erreur de débordement. (F1)
2. **Légende entière aux petites tailles** (plan de scénario : 900 × 600,
   390 × 844, 844 × 390, 320 dp) -> idem ; en 844 × 390 le schéma garde au moins
   160 dp.
3. **Commandes du lecteur visibles** : lecture, rejouer, vitesse atteignables sans
   défiler à 1280 × 800.
4. **Entrée « Plein écran » masquée si non pris en charge** (double
   `supported: false`).
5. **Passer en plein écran** : appui sur « Plein écran » -> `enter` appelé une
   fois, le bouton devient « Quitter le plein écran ».
6. **Quitter** : appui -> `exit` appelé ; le bouton revient.
7. **Sortie par le navigateur** : le double émet `false` (Échap) -> le bouton
   revient sans action de l'utilisateur.
8. **Plein écran depuis le menu ⋮ du guide** -> même effet ; l'entrée affiche
   « Quitter le plein écran » une fois actif.
9. **Le plein écran survit à la navigation** : plein écran actif, ouvrir la
   présentation depuis le guide, la fermer -> toujours actif, bouton cohérent.
10. **« Tournez l'appareil » en portrait** (390 × 844, schéma limité par la
    largeur) -> bandeau visible ; la navigation reste possible.
11. **Pas d'indication en paysage** (844 × 390 et 1280 × 800).
12. **Fermer l'indication** -> bandeau retiré pour l'étape ; le schéma ne bouge pas.
13. **Navigation conservée** : étapes sans schéma de table (plusieurs
    illustrations) restent affichées comme avant (non-régression).
14. **Motif de tapis présent, texte lisible** : clé `presentation-cloth` présente,
    sémantique inchangée (le motif n'est pas annoncé).

Scénarios existants impactés : tout scénario de présentation qui s'appuie sur la
hauteur calculée ou sur `PresentationScope` opaque (`session_guide*.feature`, tests
de `RunPresentationView`) ; à relire et ajuster, sans supprimer de test.

## 11. Tests unitaires et de widget (TDD, un rouge par comportement)

- `stage_fit_test` : `isWidthLimited` aux bornes (carré, très large, très haut,
  rapport exactement égal).
- `fullscreen_cubit_test` : état initial depuis le contrôleur ; `toggle` appelle
  `enter` quand inactif, `exit` quand actif ; suit `changes` (y compris sortie
  externe) ; ferme son abonnement ; `supported: false` -> `toggle` sans effet.
- `diagram_stage_test` (widget) : pour chaque taille du § 3, la légende la plus
  longue du catalogue (calculée sur `docs/knowledge`) n'est pas coupée
  (`tester.getRect` dans la zone visible, sans `RenderFlex overflowed`), la barre
  basse est visible, la zone du schéma est ≥ 160 dp ou la scène défile ; mode
  compact ; texte système ×1,3 à 320 dp.
- `rotate_hint_test` : visible en portrait limité par la largeur, absent sinon,
  fermeture, cible ≥ 48 dp, annonce une seule fois.
- `cloth_contrast_test` : contraste ≥ 4,5 clair et sombre.
- `presentation_scope_test` : `transparent` ne peint pas `surface` ; défaut
  inchangé.
- `run_presentation_view_test` : suppression du calcul de hauteur sans régression
  (étapes sans schéma, proposition avec badge).
- Contrat `FullscreenController` : suite commune exécutée sur le double
  (`fake_fullscreen_controller`) ; les implémentations web et native sont fines
  (aucune logique) et vérifiées au parcours web § 12.

## 12. Vérification

`scripts/check.sh --full` vert, puis parcours web avec Playwright (mémoire
`tester-app-web-playwright`) : build web, présentation à 1280 × 800, 900 × 600,
390 × 844, 844 × 390 ; clic sur « Plein écran » (geste utilisateur réel, le test
vérifie `document.fullscreenElement`), Échap, retour ; captures hors dépôt (chemin
absolu). Non vérifiable en automatique : iPhone Safari, PWA installée, Android
natif -> lot 15 (déjà au roadmap).

## 13. Risques

| Risque | Parade |
|--------|--------|
| `requestFullscreen` refusé hors geste | appel synchrone dans le `onPressed`, jamais après un `await` ; promesse rejetée interceptée, état réel via `fullscreenchange` |
| iPhone Safari sans API Fullscreen | entrée masquée (`isSupported`) ; piste PWA `standalone` au lot 15 |
| Échap navigateur et fermeture de la présentation | le navigateur consomme Échap en plein écran ; test manuel au § 12 |
| `LayoutBuilder` sous un rendu à intrinsèques | la scène est un `RenderBox` sur mesure sans intrinsèques ; aucun `IntrinsicHeight` |
| Régression de `TableDiagramPlayer.maxHeight` | mécanisme conservé, seul l'appelant change ; tests existants du lecteur inchangés |
| Architecture : implémentations en `app/platform` | à vérifier avec `scripts/check_architecture` ; sinon `shared/platform` avec règle documentée |
| Couverture des fichiers web/native (non testables en Dart VM) | vérifier la liste d'exclusions de `scripts/coverage` ; ne **pas** abaisser le seuil ; si l'exclusion n'existe pas, l'ajouter est une décision de garde-fou à faire valider, pas à contourner |
| Légende très longue (> 45 % de la hauteur) | la scène défile ; le test du § 11 couvre la plus longue du catalogue |
| Motif et contraste | panneau `surface` sous la légende ; test de contraste |

## 14. Lots d'implémentation (ordre)

1. `stage_fit` + `FullscreenController` (port) + double + `FullscreenCubit`
   (BDD 4 à 9 rouge puis TDD).
2. `DiagramStage` + `PresentationScope.transparent` + recomposition de
   `RunPresentationView` (BDD 1 à 3, 13, 14).
3. `RotateHint` (BDD 10 à 12).
4. Implémentations web et native, fabrique, module DI, entrée du menu ⋮ du guide.
5. ADR 0017, `adr/README.md`, roadmap (U3 livré, F1 soldé), `design-system.md`,
   `testing.md`, `guide-mener-plan.md` § 9 (renvoi), parcours web § 12.

## 15. Décisions `[U]` à confirmer

| # | Question | Défaut proposé |
|---|----------|----------------|
| U3-1 | Plein écran sur le bureau natif | non pris en charge, entrée masquée |
| U3-2 | Fermer la présentation quitte-t-il le plein écran | non |
| U3-3 | Raccourci clavier `F` | oui, présentation seulement |
| U3-4 | Indication « Tournez l'appareil » mémorisée entre étapes | non, réaffichée à chaque étape portrait limité |

## 16. Écarts constatés à la réalisation

- `isWidthLimited` prend `width`, `height`, `aspect` (`shared/lib` est du Dart pur,
  sans `Size`). La décision d'afficher le bandeau se prend sur la zone du corps
  (largeur × hauteur du viewport), borne haute de la zone du schéma.
- Le titre visuel défile avec le corps de la scène (mesuré avec la légende) au lieu
  de rester fixe ; seuls l'en-tête et la barre basse sont fixes.
- La zone du schéma est une hauteur **minimale** : un schéma qui ne tient pas
  dedans (commandes du lecteur comprises) grandit et la scène défile, au lieu de
  déborder sur la légende. Minimum 304 dp pour un schéma de table avec commandes
  (240 de schéma + 16 + 48), 160 dp par défaut (`minFigureHeight`).
- Textes un cran plus petits (`bodyLarge` ×1,5 au lieu de `headlineSmall`) sous
  600 dp de large ou 640 dp de haut ; mode compact (titre dans la barre basse)
  sous 480 dp de haut.
- « Plein écran » se réduit à une icône (48 dp, info-bulle) sous 560 dp de large ;
  la page de présentation a des marges verticales réduites (8 dp).
- L'import conditionnel a le web par défaut et `dart.library.io` pour le natif, afin
  que `scripts/check_coverage.dart` (qui lit le premier import) voie le fichier
  web comme référencé sans exclusion ni baisse de seuil. La logique du web est
  dans `web_fullscreen_controller.dart` (testée), les liaisons dans
  `fullscreen_controller_web.dart`.
- `FullscreenCubit` est fourni par le routeur (une instance par écran, un contrôleur
  singleton) ; les vues reçoivent l'état en paramètres facultatifs.
- Le bouton « Plein écran » actif n'est pas teinté en bleu-tapis : le libellé et
  l'icône changent (« Quitter le plein écran », `fullscreen_exit`).
- Restes : en paysage sur téléphone (844 × 390), le schéma de table avec ses
  commandes (304 dp) dépasse la zone : la scène défile pour atteindre commandes et
  légende ; iPhone Safari, PWA installée et Android natif non vérifiés (lot 15).
