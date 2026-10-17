# ADR 0010 — Rôles de couleur : bleu-tapis pour les états, rouge en accent

- Statut : **accepté** (2026-10-14), décisions Q1 et Q2 de l'animateur
  (`ux/plan-ux-proposition.md` § 6). Lot U1 « Fondations du design system ».
- **Amende l'[ADR 0002](0002-design-system-widgetbook.md), décision 2** (le
  rouge FFB assombri était le rôle `secondary`). Les décisions 1, 3, 4 et 5 de
  l'ADR 0002 restent en vigueur ; la décision 5 (pas de logo) est mise en
  œuvre par un drapeau de thème (Q2).
- Fondement : `ux/recommandations-design.md` R1 à R4 (audit UX/UI, constats
  T1, M3, R3, X2, D4).

## Contexte

Dans le schéma Material 3 de l'ADR 0002, `secondary` et `secondaryContainer`
portaient le rouge FFB (`#b80d1a` / conteneur rose `#fddad7`). Or Material
affecte `secondaryContainer` aux **états** : indicateur de la barre de
navigation, puces sélectionnées, segments, boutons tonals. Résultat : chaque
état « sélectionné » était rose, ce qui se lit comme une erreur ou un avertissement
; la piste d'une barre de progression pouvait elle aussi devenir rouge. Le
rouge, couleur de marque, n'avait pas de rôle propre.

## Décisions

1. **Q1 — Bleu-tapis pour les états.** `secondary` / `secondaryContainer`
   (et leurs `on*`) prennent la famille du tapis bleu poudre : clair
   `#2f6b8a` / `#cfe6f3`, sombre `#9fcfe8` / `#1f5873`. `tertiary` reste dans
   cette même famille (valeurs inchangées). Les états sélectionnés de la
   navigation, des puces et des segments sont donc bleu-tapis dans les deux
   thèmes ; la piste d'une barre de progression est `secondaryContainer`
   (`ProgressIndicatorThemeData` et `ProgressMeter`), **jamais rouge**.
2. **Le rouge FFB devient un accent explicite** : `ThemeExtension`
   `BrandColors` (`shared/ui/theme/brand_colors.dart`), `accent` `#b80d1a`
   (sombre `#ffb3ad`), `onAccent`, `accentContainer`, `onAccentContainer`.
   Usages autorisés, **toujours via un composant du design system** :
   ligne d'objectif de `ProgressChart`, badge « Enfants » (`AudienceBadge`),
   titre de l'application et pastille d'en-tête lorsqu'ils existent. Un écran
   ne lit jamais `BrandColors` directement.
3. **Hiérarchie de surfaces** (R2) : `SectionCard.emphasis` (`low` par défaut :
   `surfaceContainerLow` sans bord ; `medium` : `surfaceContainer` + bord
   `outlineVariant` ; `high` : `surfaceContainer` + bord bleu-tapis de 2 dp,
   réservée à l'étape courante, à l'élève en cours de saisie, à l'alerte). Le
   titre reste l'en-tête sémantique : le niveau ne porte jamais seul le sens.
4. **Q2 — Logo FFB éteint derrière un drapeau de thème.**
   `BrandAssets.logo` est nullable ; `AppTheme.light/dark(showFfbLogo: false)`
   par défaut ne fournit aucun logo ; `FfbLogo` et `PageHeader` n'affichent
   rien (et ne réservent aucune place) sans logo. Le composant, le PNG et son
   test (480 × 300) sont conservés. **Un seul endroit à rallumer** : passer
   `showFfbLogo: true` dans `app.dart` (et Widgetbook) quand l'autorisation
   écrite de la FFB (`site@ffbillard.com`) existe.
5. **Icônes de navigation dédiées** (R3) : cinq glyphes dessinés sans police
   d'icônes (`NavIcon`, `CustomPainter`, couleur et taille de l'`IconTheme`
   courant ; plein = sélectionné, contour = non sélectionné) : table vue de
   dessus, deux billes, fiche à pastilles, maison, losange du rail.
   `AppDestination` accepte des widgets d'icône.

## Conséquences

- Aucune couleur de marque en dur dans les écrans ; `contrast_test.dart`
  couvre `BrandColors` (≥ 4,5:1 pour chaque paire, clair et sombre).
- Tout usage de `colorScheme.secondary*` exprime désormais un **état**, pas la
  marque. Les usages qui exprimaient la marque (objectif des courbes, badge
  « Enfants ») passent par `BrandColors`. La main de `CueSideView`, qui
  utilisait `secondaryContainer` comme teinte « chair » involontaire, passe à
  `surfaceContainerLowest` (neutre, contour conservé).
- Le texte et les valeurs hexadécimales des couleurs restent des
  **propositions** non publiées par la FFB (sauf le bleu `#1964af`).
- `PassDots`, `TimerChip`, `PhaseTimeline`, `StepAppBar` et la feuille
  Widgetbook « Rôles de couleur » sont livrés dans le même lot, avec leurs use
  cases. Les destinations de navigation ne changent pas ici (lot U6).
- **Hors U1, reporté** : le signe en bille n° 8 et le motif de tapis (R3) vont
  à U7 (accueil, état vide) et U3 (présentation) ; `StudentChip` (R4) à U5,
  `NowCard` à U7, `DiagramStage` à U3.

## Addendum du 2026-10-17 : minuteur dépassé

Décision de l'animateur : le minuteur dépassé n'est **pas** rouge. `TimerChip`
passe de `StatusColors.attention` (sous une minute) à `inverseSurface` /
`onInverseSurface` au dépassement, avec l'icône sablier et le temps en
`+mm:ss` (jamais la couleur seule). `errorContainer` reste réservé aux échecs
(`AppAlert` persistant, `design-system.md`). La paire est couverte par
`contrast_test.dart` et son câblage par `timer_chip_test.dart`.
