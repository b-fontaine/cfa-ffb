# Plan de conception : guide en mode « Mener » (lot U4)

Statut : **livré le 2026-10-16** (parcours web fait, voir § 18) (conception du 2026-10-16 ;
conception puis lots 1 et 2 dans l'arbre de travail, rien de commité). Décision
structurante : [ADR 0015](adr/0015-guide-mener-route-modes-origine.md). Écarts de
la conception à l'implémentation : voir « Écarts » en fin de document. Source : roadmap (U4, F3, lots
12, 13 et 15), [ux/plan-ux-proposition.md](ux/plan-ux-proposition.md) (U4 et
scénarios « U4 » du § 4, décisions Q1 à Q8, Q4 surtout),
[ux/recommandations-design.md](ux/recommandations-design.md) (R7, R9),
[ux/audit-ux-ui.md](ux/audit-ux-ui.md) (G1 à G7), ADR 0004, 0007, 0010, 0011,
[catalogue-preparer-plan.md](catalogue-preparer-plan.md) (SheetOrigin, U-9),
[aujourdhui-plan.md](aujourdhui-plan.md) (U-12, bilan),
[navigation-plan.md](navigation-plan.md). Lot livré = ADR 0015 (voir § 12),
`design-system.md`, `testing.md`, `guide-animateur.md`, roadmap.

Dépendances : U1 (`StepAppBar`, `PhaseTimeline`, `TimerChip`), U5 (feuille
de saisie), U7 (bilan), U8 (origines du détail), tous livrés.

## 1. Constat sur le code actuel

- Le guide est une route **dans le `ShellRoute`** (`/catalogue/:sheetId/guide`,
  `app/router.dart` l. 781) : rail ou barre de navigation visibles, sélection
  « Séances » par préfixe d'adresse. La présentation, elle, est déjà de premier
  niveau.
- `RunSheetView` empile : barre d'actions (Sommaire, Montrer, Terminer), carte
  minuteur, titre de la séance, public, `_ThemeTile`, compteur « Étape n sur m »,
  `LinearProgressIndicator`, ligne de phase, puis l'étape. `_StepLayout`
  place `lead` (objectif, passages, chevalet…) **avant** le média : le schéma est
  la 7e information (G6). Les trois actions du bas : `Précédent` / `Suivant`
  seulement ; `Noter les résultats` est dans le texte de l'étape.
- Minuteur : `_TimerBar` affiche le **temps écoulé** sur le prévu, avec un message
  d'alerte quand le reste est ≤ 60 s ou négatif ; pas de changement de fond.
  `TimerChip` (U1) affiche le **temps restant** avec ton neutre / attention /
  dépassé (`timerToneFor`) mais aucun écran ne l'utilise.
- Provenance : `_Source` rend un `ProvenanceBadge` partout (10+ éléments par
  étape) ; aucune notion de mode.
- Origine : `SheetOrigin { catalogue, planner, today }` n'existe que pour le
  détail. `AppRoutes.guide(id, {audience, session, step, group})` ne porte ni
  origine ni (depuis le détail) groupe. Retour du guide (`origin()` du routeur) :
  séance planifiée -> `/planner` (même depuis Aujourd'hui, U-9), sinon
  `AppRoutes.sheet(id, audience)` sans `from` ni `group`.
- `RunKey(sheetId, audience, sessionId, group)` identifie le cubit ; le cubit vit
  dans `RunSheetSessions` (singleton), donc survit à la saisie, à la présentation
  et à un retour par `context.go`.

## 2. Périmètre exact

**Dans U4**

1. Route du guide **hors du shell** (plus de rail ni de barre).
2. Écran recomposé : `StepAppBar` + `PhaseTimeline` + ligne « phase · minuteur »
   (`TimerChip`) ; schéma en premier ; sections repliées en mode Mener ; barre
   basse `Précédent / Noter / Suivant` ; menu ⋮ (sommaire, Relecture, « La
   séance », minuteur à zéro, terminer).
3. Modes **Mener** et **Relecture** (Q4) : badges `[Prop]` masqués / affichés,
   sections repliées / dépliées.
4. « Terminer » confirmé (existe déjà) + action de dernière étape ; lien avec le
   bilan d'U7 inchangé.
5. Solde de **U-9** : retour du guide vers l'origine (Aujourd'hui, Planifiées,
   Suggestion, Catalogue avec son groupe) ; conservation de `group` de
   catalogue -> détail -> guide -> présentation -> saisie, et vers le
   planificateur (« Planifier cette séance »).
6. Retrait de ce que le nouvel écran rend caduc : barre de progression linéaire,
   carte minuteur, boutons Sommaire / Montrer / Terminer en tête.

**Hors U4 (reporté, dit explicitement)**

| Sujet | Reporté à | Raison |
|---|---|---|
| Mode immersif / plein écran natif | **U3** (plein écran de la présentation), test PWA au **lot 15** | voir § 9 |
| Maintien de l'écran allumé (wake lock) | lot 15 | demande une API web ou une dépendance ; hors R7/R9 |
| `DiagramStage`, zoom du schéma, « tournez l'appareil » | U3 | propre à la présentation |
| ~~Compteurs d'initiation et score persistés (G7)~~ | ~~lot 10 / U9~~ **soldé par le lot 10b** (2026-10-17, [plan](seance-en-cours-plan.md), [ADR 0020](adr/0020-seance-en-cours-persistee-locale-hors-sauvegarde.md)) | état gardé sur l'appareil, hors sauvegarde ; la mention « non enregistré » reste telle quelle (le bilan de la séance ne reçoit ni compteurs ni score) |
| Marque « relu » persistante des `[Prop]` | lot 16 | le mode Relecture lui sert d'appui |
| Mode (Mener / Relecture) mémorisé dans les Réglages | non prévu | la règle par défaut suffit (§ 4) |
| « Préparer » depuis Aujourd'hui qui emporte le groupe de la séance planifiée | hors lot | aucun marqueur de groupe n'existe sans groupe de catalogue ; `HomePage.onPrepare` ne change pas |

## 3. Route hors shell : conséquences

**Décision.** `GoRoute('/catalogue/:sheetId/guide')` passe **au premier niveau**, à
côté de la présentation (`router.dart`, après le `ShellRoute`). Même modèle que
`/students/:id/show` et la présentation.

Conséquences, une par une :

- **Adresse et liens profonds** : inchangés (`audience`, `session`, `step`,
  `group`) ; deux paramètres s'ajoutent (§ 6 : `from`, `via`) et un facultatif
  `mode` (§ 4). Les anciens liens restent valides.
- **Shell** : `AppShell.indexOf` ne voit plus l'adresse du guide (aucun changement
  de code : son préfixe `catalogue` reste utile au détail). Le test
  `shell_routes_test.dart` n'a qu'à ajouter un cas « le guide n'est pas sous le
  shell ».
- **Cubit et reprise** : inchangés. Le cubit vient de `RunSheetSessions`
  (`BlocProvider.value`), pas de la route ; changer de parent ne détruit rien.
  Aujourd'hui (`RunningSessionCard`) reprend toujours par `AppRoutes.guide(...,
  step)`.
- **Retour** : plus de rail pour sortir. La **flèche de `StepAppBar`** est l'unique
  sortie douce (§ 6) ; « Terminer » l'unique sortie qui libère le cubit. La flèche
  **n'arrête pas la séance** : le cubit reste dans `RunSheetSessions` (plafond
  `maxRunning = 4`), Aujourd'hui propose « Reprendre ». Pas de confirmation sur la
  flèche (rien n'est détruit) ; `_TimerGuard` met le minuteur en pause à la sortie.
- **Geste de retour système** : comportement actuel de `go_router` (historique du
  navigateur en web). Les écrans empilés au-dessus (feuille de saisie, route
  présentation en `push`) se ferment d'abord, scénarios existants inchangés.
- **Feuille de saisie (`showRecordSheet`)** : ouverte avec le `context` du guide ;
  sans shell elle couvre tout l'écran (92 % de hauteur, comme le teste
  `the_record_sheet_is_open`). Aucune adaptation.
- **Barre d'état / zones sûres** : le `Scaffold` du guide gère `SafeArea` ; plus
  de barre de navigation à contourner.

## 4. Modèle des modes Mener / Relecture

**Décision : l'état vit dans le cubit** (`RunSheetState.mode`), **reflété dans
l'adresse** comme l'étape (`?mode=review|lead`, ajouté seulement quand l'animateur
bascule ou qu'un lancement l'impose).

Pourquoi pas un simple paramètre de route : le mode doit survivre à « Reprendre »
depuis Aujourd'hui (l'adresse de reprise est reconstruite par le routeur), à la
présentation, à la feuille de saisie et aux `context.go(guide(step))` à chaque
« Suivant ». Le cubit est déjà l'état du guide et traverse tout cela.
Pourquoi pas un état seul : le rechargement web perdrait le choix et un lien ne
pourrait pas ouvrir « en Relecture » (utile aux scénarios et au lot 16). Le
reflet dans l'adresse suit le modèle existant de `?step=` : le cubit fait foi,
l'adresse suit (`syncFromRoute(step, mode)` ; idempotent).

- **Domaine pur** (`features/run_sheet/domain/run_mode.dart`) :
  `enum RunMode { lead, review }` ;
  `RunMode.defaultFor({required bool planned})` -> `planned ? lead : review` ;
  `bool get showsProvenance => this == review` ; `bool get expandsSections =>
  this == review`. Aucun `BuildContext`, aucune horloge.
- **Règle par défaut (Q4)** : séance planifiée (`RunKey.sessionId != null`) ->
  **Mener** ; guide lancé **sans** séance planifiée (détail, lien direct) ->
  **Relecture**. Un lancement explicite peut imposer `mode=lead` : proposé pour
  la **séance suggérée** (`[U4-1]`) puisque l'animateur y a déjà choisi ses élèves.
- **Cubit** : `RunSheetCubit` initialise `state.mode` avec `RunMode.defaultFor`
  de sa clé ; `modeChanged(RunMode)` ; `syncFromRoute({int? step, RunMode?
  mode})` n'applique `mode` que s'il est présent. `finish()` repart du mode par
  défaut. Le mode n'entre pas dans `hasProgress` (comme le minuteur).
- **Bascule** : entrée de menu ⋮ « Mode Relecture » (case à cocher, libellé qui
  dit l'effet : « Afficher les propositions et tout déplier »), 48 dp, sémantique
  `checked`. Après bascule : `onModeChanged` -> `context.go(guide(step, mode))`.
- **Effets** :

| | Mener | Relecture |
|---|---|---|
| Badges `[Prop]` (`_Source`, `ProposalBadge` du schéma, ligne « cette cible est une proposition ») | masqués | affichés (comportement actuel) |
| Sections repliables (voir § 5) | repliées | dépliées |
| Information `[Prop]` | accessible : `Semantics(label: 'Proposition')` sur un nœud sans rendu, juste avant l'élément ; message d'étape « n propositions » dans « La séance » ; bascule en un geste | visible |
| Provenance des données | inchangée : `Provenance.prop` reste dans `RunPlan`, `RunPlan.isProposal(step)` aussi | idem |

La présentation n'a pas de mode : son badge d'illustration est inchangé
(scénarios existants conservés).

## 5. Composition de l'écran

```
+--------------------------------------------------------+  48
| <-  Exercice 1 · Les six parts de gâteau     6/10   ⋮  |  StepAppBar
|--------------------------------------------------------|
| [Accueil][Notion][ Entraînement ][Jeu][Bilan]          |  56 PhaseTimeline
| Entraînement · 35 min                  [ 18:40  ⏸ ]    |  56 phase + TimerChip
|--------------------------------------------------------|
|  schéma de table (TableDiagramPlayer)  [Montrer]       |  scroll
|  Objectif 4/6 · 5 passages à valider                   |
|  Mise en place / Consigne / Attendu                    |
|  ▸ Erreurs fréquentes   ▸ Accroche et défi             |
|--------------------------------------------------------|
| [<-]        [ Noter les résultats ]            [->]    |  barre basse 56
+--------------------------------------------------------+
```

**En-tête** (hauteur 48 + 56 + 56 = 160 dp, contre ~360 aujourd'hui ; cible
mesurée par scénario : l'en-tête occupe **au plus 25 %** de 844 dp) :

- `StepAppBar` : `title = runStepTitle(l10n, plan, step)` (le titre d'étape
  disparaît du contenu : **un seul** `Text` « Exercice 1 · … », sinon
  `find.text` en trouve deux), `position/total`, flèche `onBack`. Actions ⋮ :
  Sommaire, Mode Relecture, La séance, Minuteur à zéro, Terminer la séance.
  Plus de titre de séance, de public ni de thème dans l'en-tête (G2).
- `PhaseTimeline` : une entrée par phase (`runPhaseTitle` court, minutes de
  `plan.timing.phaseMinutes`, toutes ≥ 1 par `SessionShape.isValidFor`) ; phase
  courante = celle de l'étape ; un tap saute à la **première étape de la phase**
  (`RunPlan.firstStepOf(phase)`, domaine pur testé). Libellés **courts**
  nouveaux (Accueil, Notion, Entraînement, Jeu, Bilan) ; les noms complets
  restent dans la ligne de phase et la sémantique.
- Ligne « phase · minuteur » : `_PhaseLine` conservée (clé `phase:<nom>`, texte
  « Entraînement · 35 min », badge `minutes` en Relecture seulement) à gauche,
  `TimerChip` à droite.
- **Épinglage** : StepAppBar, ligne minuteur et barre basse restent toujours
  visibles ; la frise est épinglée si `maxHeight >= 600 × facteur de texte`
  (règle existante `_pinnedMinHeight`), sinon elle défile avec le contenu (320 dp,
  texte 200 %, paysage de téléphone).

**Contenu** (`_StepLayout`) :

- Plus d'en-tête de titre. Ordre : **média (schéma / illustration)**, puis
  `lead` (objectif, passages, chevalet, rappel), puis `text`. Sur ≥ 720 dp :
  deux colonnes, **schéma à gauche**, texte à droite (inverse d'aujourd'hui).
- Test chiffré : à 390 × 844, pour un exercice et pour le créneau de rappel, le
  schéma (table et commandes du lecteur) est **entièrement** entre le bas de
  l'en-tête et le haut de la barre basse. Budget : 844 − 24 (barre d'état) − 160
  − 72 (barre basse) = 588 dp pour un schéma ≤ 360 de large -> marge.
- « Montrer » : bouton sous le schéma (`OutlinedButton`, présent seulement si
  `plan.isPresentable(step)` : masqué, plus désactivé).
- **Repliées en Mener** (`ExpansionTile`, dépliées en Relecture) : exercice :
  « Erreurs fréquentes (animateur) », « Accroche et défi » ; jeu : « Variante »,
  « Lien avec la séance précédente », « Adaptation » ; bilan : « Points à valider »
  (`uncertainties`). **Toujours ouvertes** : mise en place, consigne, attendu,
  objectif, passages, règles du jeu, score, compteurs d'initiation, théorie.
  Les sections `[Prop]` repliées gardent leur libellé et la marque sémantique.
- Remplacent la barre de progression linéaire (supprimée : la frise et le « n/m »
  disent où l'on est ; l'ancien scénario de piste non rouge disparaît avec elle).
- Proposition de reprise (`_ResumeOffer`) : conservée sous la frise.
- `_ThemeTile` : sorti de l'en-tête ; thème, notion (avec badge `[Prop]` du thème
  en Relecture) et public · durée vont dans **« La séance »** (feuille basse du
  menu ⋮). En Relecture, la tuile repliée est aussi rendue **en fin d'étape**
  (jamais avant le schéma) pour garder la relecture du thème en contexte.

**Barre basse** (hauteur 56 dp, cibles ≥ 48 dp) :

- Étape sans saisie (théorie, jeu, bilan, rappel) : `Précédent` | `Suivant`, texte
  visible, deux colonnes égales.
- Étape exercice ou créneau de rappel : `Précédent` | **`Noter les résultats`** |
  `Suivant`. ≥ 600 dp : trois boutons avec texte. < 600 dp : flèches (infobulle et
  sémantique « Précédent » / « Suivant ») de part et d'autre d'un bouton plein
  `Noter les résultats` (`[U4-7]`). À texte ≥ 130 % la ligne passe en deux rangées.
- **Dernière étape** : `Suivant` devient **`Terminer`** (plein) et appelle la même
  confirmation que le menu ; libellé distinct de l'entrée de menu « Terminer la
  séance » (clé `guideFinishShort`), pour qu'un `find.text` n'en trouve jamais deux.
- `Noter` appelle `onRecord(exercise)` : le routeur ouvre la feuille d'U5 comme
  aujourd'hui (aucun changement de contrat). Le texte d'aide
  `guideRecordHint` disparaît de l'étape et s'affiche en Relecture sous le schéma.

**Minuteur** (§ 7) et **menu** (§ 8) : voir plus bas.

## 6. Origine et groupe à travers guide -> détail -> planificateur -> saisie

### Le problème (U-9)

`group` a déjà un sens dans le guide (groupe proposé à la saisie, `RunKey.group`,
ADR 0009). Depuis le détail, ce paramètre est perdu ; le retour du guide ignore
l'origine ; Aujourd'hui -> « Lancer » finit sur Planifiées.

### Décisions

1. **`group` garde un seul sens : « le groupe pour lequel on prépare ou on mène »**
   (le même que celui du catalogue). Il traverse : catalogue -> détail
   (déjà fait, U8) -> **guide** -> présentation -> saisie, et détail ->
   **planificateur** (« Planifier cette séance »). `[U4-8]`
2. **Deux paramètres d'origine, même énumération, jamais une adresse libre** :
   - `SheetOrigin` s'étend à `{ catalogue, planner, today, suggestion }`
     (`suggestion` = `from=suggestion`). Le détail l'utilise déjà (libellé et
     retour) ; la séance suggérée qui ouvre un détail passe `from=suggestion`.
   - **`from`** sur le guide = origine **directe** : « Lancer » d'Aujourd'hui
     (`today`), de Planifiées (`planner`), de la Suggestion (`suggestion`),
     « Reprendre » d'Aujourd'hui (`today`).
   - **`via`** sur le guide = origine **du détail** quand le guide est lancé
     depuis le détail (le détail a lui-même `from`) : le retour revient au détail
     avec sa propre origine et son groupe.
3. **Règle de retour** (fonction pure `guideBackTarget` dans `app/`, testée sans
   widget) :

| `session` | `from` | `via` | Retour (flèche et « Terminer » sans saisie) |
|---|---|---|---|
| présent | absent | : | `/planner` (compatibilité avec les liens existants) |
| quelconque | `planner` | : | `/planner` |
| quelconque | `today` | : | `/` (Aujourd'hui) |
| quelconque | `suggestion` | : | `/session` |
| absent | absent | `x` ou absent | `AppRoutes.sheet(id, audience, origin: x, group)` |
| toute valeur inconnue | : | : | le détail sans origine (jamais une adresse libre) |

4. **`RunKey` ne change pas** : l'origine n'est pas une identité de séance (deux
   lancements de la même séance partagent leur état, donc la reprise). Elle reste
   dans l'adresse, relue à chaque construction de la route. **Conséquence assumée** :
   comme `group` fait partie de la clé, lancer depuis un détail avec le groupe A
   puis sans groupe crée deux cubits (déjà vrai pour la suggestion) ; plafond
   `maxRunning = 4`.
5. **Propagation** (`AppRoutes`) : `guide(id, {audience, session, step, group,
   SheetOrigin? from, SheetOrigin? via, RunMode? mode})` ; `presentation(...)`
   gagne `from`, `via` ; `onStepChanged`, `onShow`, la fermeture de la
   présentation et l'adresse de retour de la saisie reconstruisent **toutes** les
   adresses avec les mêmes paramètres (un seul constructeur local `guide(step)`
   dans le routeur, déjà le cas pour `step`). La saisie plein écran reçoit déjà
   l'adresse complète du guide dans `from` (`_guideReturn`, limité à
   `/catalogue/…`) : rien à ajouter.
6. **Appelants** : détail `onLaunch` -> `via: origin`, `group` ; détail `onPlan` ->
   `AppRoutes.plan(id, audience, group)` ; `SessionPlannerEvent.started` gagne
   `groupId` (groupe présélectionné si plannable, le public suit la règle
   existante « le public suit le groupe ») ; accueil `onLaunch`, `onResume` -> `from:
   today` ; planificateur `onLaunchSheet` -> `from: planner` ; suggestion
   `onLaunch` -> `from: suggestion`, `group`.
7. **Libellé de la flèche** : `StepAppBar` a une infobulle fixe (« Retour »).
   Pas de nouveau champ dans le composant partagé : le titre de destination est
   déjà dans l'écran d'arrivée (U8). `[U4-9]` : la flèche ne devient pas un texte.

## 7. Minuteur

- **Source** : `RunSheetState.timerSeconds` et `RunTicker` inchangés (écoulé,
  remis à zéro au changement de phase, jamais bloquant).
- **Affichage** : `TimerChip(remaining: Duration(minutes: planned) - elapsed,
  running, onToggle: timerToggled)`. Le **temps restant** remplace « écoulé /
  prévu » (R9, G4) : la phrase `guideTimerLine` disparaît de l'écran ; elle
  reste dans la sémantique de la ligne « phase · minuteur ».
- **Ton** : `timerToneFor(remaining)` du composant U1, sans nouvelle logique :
  neutre ≥ 1 min ; **attention** de 0 inclus à 1 min exclue ; **dépassé** < 0
  (texte `+mm:ss`, icône, région vive annoncée **au franchissement**, pas chaque
  seconde). Jamais de rouge (ADR 0010, décision de l'animateur du 2026-10-17) :
  `StatusColors.attention`, puis `inverseSurface` (fond sombre) avec icône sablier
  et `+mm:ss`.
- **Ancien comportement conservé** : le message d'alerte n'apparaissait qu'une fois
  le minuteur lancé ; avec `remaining = prévu` au départ (≥ 1 min), le ton neutre
  l'impose déjà. Minutes de phase ≥ 1 : pas de cas « attention » au repos.
- **Remise à zéro** : l'icône `restart_alt` de la carte disparaît (le chip a un
  seul bouton) ; entrée « Minuteur à zéro » du menu ⋮, inactive à 0 s. Infobulles
  « Lancer / Mettre en pause le minuteur » inchangées (tests existants).
- **Vibration** `[U4-5]` : `HapticFeedback.mediumImpact()` une fois au passage en
  attention et une fois au passage en dépassé (`BlocListener` sur le changement de
  ton, services Flutter, sans dépendance ; sans effet en web).
- **Garde** : `_TimerGuard` conservé (pause à la sortie du guide).

## 8. « Terminer », bilan, menu ⋮

- **Deux entrées, une confirmation** : menu « Terminer la séance » et action de
  dernière étape « Terminer » appellent `_confirmFinish` (`showConfirmDialog`,
  titre `guideFinishTitle`, corps `guideFinishBody`). Annuler ne change rien
  (scénario existant conservé). Le corps indique déjà que rien n'est écrit ; à
  l'écriture, y ajouter « Le bilan s'ouvre ensuite » quand `recordChoice != null`
  (un seul libellé conditionnel, domaine inchangé).
- **Après confirmation** : `SheetGuidePage.onFinish(recordId)` : identique à U7
  (lecture de `recordChoice?.recordId` **avant** `finish()`, `go(review(id))` si une
  saisie a été ouverte, sinon `go(guideBackTarget)`, puis `sessions.release`). U4
  ne touche ni le bilan ni `RunRecordChoice`.
- **Menu ⋮** (`StepAppBarAction`, libellés injectés par `RunSheetView`) : Sommaire
  (ouvre `_showOutline`, inchangé) ; Mode Relecture (case) ; La séance (feuille
  basse : titre, public · durée, thème, notion, nombre de propositions de l'étape) ;
  Minuteur à zéro ; Terminer la séance. Pas de bouton « Montrer » ici (il est sous
  le schéma).

## 9. Ce qui est reporté à U3 et pourquoi

> **Livré par U3 le 2026-10-16** : voir [presentation-plan.md](presentation-plan.md) et
> l'[ADR 0017](adr/0017-plein-ecran-port-controleur-partage.md). L'entrée « Plein
> écran » du menu ⋮ est entre « La séance » et « Minuteur à zéro », masquée si
> `FullscreenController.isSupported` est faux ; le contrat de `RunSheetView` gagne
> deux paramètres facultatifs (`fullscreen`, `onToggleFullscreen`).

Le plein écran natif demande, sur le web (cible principale, PWA), l'API
Fullscreen (geste utilisateur, `dart:js_interop` via import conditionnel) ou, sur
mobile natif, `SystemChrome`. Un contrôleur de plein écran se conçoit **une
fois** et sert deux écrans (présentation et guide) : il appartient à U3, qui
dispose déjà de l'entrée « plein écran » dans son périmètre. U4 livre le mode
immersif **fonctionnel** (route hors shell : plus de rail ni de barre) et prévoit
un point d'accroche : une entrée de menu « Plein écran » ajoutée par U3 sans
changer le contrat du guide. Aucun code de plein écran dans U4. Test en PWA
installée : lot 15 (déjà écrit au roadmap).

## 10. Slices FSD et composition (sans import latéral)

| Couche | Fichier | Changement |
|---|---|---|
| `shared/lib` | `session_shape.dart` (existant) | inchangé |
| `shared/ui` | `step_app_bar.dart`, `phase_timeline.dart`, `timer_chip.dart` | **inchangés** (consommés) |
| `shared/l10n` | `app_fr.arb`, `app_en.arb` | clés § 11 ; suppression de `guideTimerLine` du rendu (clé gardée si sémantique) ; `flutter gen-l10n` |
| `features/run_sheet/domain` | `run_mode.dart` (nouveau), `run_plan.dart` (+ `firstStepOf(phase)`, `phaseIndexOf(step)`, `phaseEntries` neutres : minutes par phase) | Dart pur, testé |
| `features/run_sheet/presentation/bloc` | `run_sheet_state.dart`, `run_sheet_cubit.dart` | `mode`, `modeChanged`, `syncFromRoute(mode)`, `finish()` |
| `features/run_sheet/presentation/ui` | `run_sheet_view.dart` (réécrit), `run_guide_header.dart`, `run_bottom_bar.dart`, `run_guide_menu.dart`, `run_session_info_sheet.dart` (nouveaux, `part` ou widgets publics), `run_step_views.dart` (ordre média / lead / texte, sections repliables, `_Source` conscient du mode), `run_timer_bar.dart` (supprimé, remplacé par `TimerChip`) | compose seulement des `shared/ui` et le domaine du slice |
| `features/plan_session` | `session_planner_event.dart`, `session_planner_bloc.dart` | `started(groupId)` |
| `pages/sheet_guide` | `sheet_guide_page.dart` | Scaffold, callbacks `onBack` (flèche), `onFinish`, `onModeChanged` ; remplace `fromPlanner` (devenu inutile : le routeur calcule le retour) |
| `app` | `router.dart` (route de premier niveau, `SheetOrigin.suggestion`, `AppRoutes.guide/presentation/plan`, `guideBackTarget`), `record_sheet.dart` (inchangé) | seule couche qui connaît les adresses |
| `widgetbook` | cas « En-tête du guide », « Barre basse », « Mener / Relecture » | feuille Widgetbook |

Aucun import entre slices d'une même couche : `run_sheet` n'importe pas
`plan_session` ; la page ne connaît ni `AppRoutes` ni `SheetOrigin` (callbacks).

## 11. Libellés (fr + en, aucune chaîne en dur)

Nouveaux : `guideModeReview`, `guideModeReviewHint`, `guideSessionInfo`,
`guideSessionInfoProposals(n)`, `guideTimerResetMenu`, `guideFinishShort`,
`guideFinishBodyWithSummary`, `guideBottomBarLabel`, quatre ou cinq libellés
courts de phase (`guidePhaseShort*`), `guideProposalSemantic`. Les libellés
actuels `guideOutline`, `guideShow`, `guideFinish`, `guideRecord`, `guidePrevious`,
`guideNext`, `guideStepCounter` restent (scénarios existants, carte d'Aujourd'hui).

## 12. Lots d'implémentation (ordre)

Chaque lot : `.feature` + steps implémentés **avant** le code, rouge constaté et
dit, TDD unitaire, `scripts/check.sh --fast`, puis revue `architecte-fsd` +
`testeur-bdd` dans un contexte séparé ; `--full` à la fin.

0. **Migration mécanique des scénarios (reste vert sur l'UI actuelle)** : nouveaux
   steps agnostiques `I see the guide at step {N} of {M}` (trouve le texte actuel
   « Step N of M » ou l'étiquette sémantique du `StepAppBar`), `I open the guide
   menu`, `I end the guided session` (ouvre le menu s'il existe, puis « End
   session » + « Confirm »), `I see the session audience {…}`. Migrer les scénarios
   listés au § 14. But : le gros de `session_guide.feature` change sans que l'écran
   change.
1. **Domaine et cubit** (unitaire seulement, pas de comportement visible) :
   `RunMode`, `RunPlan.firstStepOf/phaseIndexOf`, cubit `mode`/`syncFromRoute`.
2. **Routage et origine (U-9)** : `SheetOrigin.suggestion`, `AppRoutes`,
   `guideBackTarget`, route de premier niveau, appelants, `SessionPlanner.started
   (groupId)`. BDD : scénarios « navigation et origine » du § 13.
3. **En-tête, frise, minuteur, barre basse, schéma en premier** : réécriture de
   `RunSheetView` (hors modes). BDD : « mise en page et minuteur ».
4. **Modes Mener / Relecture, sections repliées, provenance** : `_Source`,
   `ExpansionTile`, menu, feuille « La séance ». BDD : « modes ».
5. **Terminer, vibration, accessibilité** : action de dernière étape, retour, test
   à 320 dp / texte 200 %, cibles 48 dp, sémantique.
6. **Documentation et livraison** : ADR 0015 (+ index `adr/README.md`),
   `design-system.md`, `testing.md`, `architecture.md`, `guide-animateur.md`,
   roadmap (U4 retiré, lot 12 barré, F3 corrigé, reports U-9 soldés), plan
   `catalogue-preparer-plan.md` / `navigation-plan.md` / `aujourdhui-plan.md`
   (reports cochés), Widgetbook.

**ADR 0015 (à écrire au lot 6)** : route de premier niveau, modes (état du cubit
reflété dans l'adresse), `from` / `via` / `SheetOrigin.suggestion`, sens unique de
`group`. Décision structurante : oui (elle fixe le contrat d'adresse du guide).

## 13. Scénarios BDD à écrire d'abord

Nouveaux, dans `session_guide.feature` sauf mention. Titres en anglais comme
l'existant.

**Navigation et origine (lot 2)**

1. The guide shows no navigation bar and no rail (390 × 844 puis 1280 × 800).
2. A planned session launched from Planned leads back to Planned. *(`session_guide`)*
3. A planned session launched from Today leads back to Today. *(`home.feature`)*
4. Resuming from Today leads back to Today. *(`home.feature`)*
5. A guide launched from a detail opened from the catalogue leads back to that
   detail, then to the catalogue with the chosen group selected.
6. A guide launched from a detail opened from Today leads back to the detail, then
   to Today.
7. A guide launched from the suggestion leads back to the suggestion.
8. Plan this session from the detail keeps the chosen group. *(`session_planner`)*
9. The group chosen in the catalogue is proposed to the record opened from the guide.
10. Closing the presentation and closing the record sheet keep the origin of the guide.
11. An unknown origin value falls back to the session of the catalogue.

**Mise en page et minuteur (lot 3)**

12. The header shows the step title once, the position and the phase timeline.
13. The header takes at most a quarter of a 390 × 844 screen.
14. Scenario Outline : The diagram of an exercise is visible without scrolling
    (390 × 844 et 1280 × 800 ; étapes : exercice 1, créneau de rappel).
15. Tapping a phase of the timeline jumps to its first step.
16. The bottom bar offers Previous, Note the results and Next on an exercise.
17. The bottom bar offers only Previous and Next on a notion step.
18. The last step offers Finish instead of Next.
19. The bottom bar and the header fit at 320 dp with text at 200 % and stay reachable.
20. The timer shows the time remaining in the header.
21. The timer turns to attention under one minute and to over time past zero
    (ticker simulé, `the guide timer has run {n} seconds`).
22. Changing phase resets the timer; the menu resets it.
23. The timer pauses when the guide is left.

**Modes et sections (lot 4)**

24. A guide launched without a planned session opens in review mode (badges
    visible, sections open).
25. A guide launched from a planned session opens in lead mode (badges hidden,
    mistakes and playful sections folded).
26. The guide launched from the suggestion opens in lead mode. *(si `[U4-1]` accepté)*
27. The menu switches between lead and review mode and the choice is kept through
    Next, the presentation, the record sheet and a resume from Today.
28. In lead mode a proposal is still announced to screen readers.
29. The session sheet gives the title, the audience, the theme, the notion and the
    number of proposals of the step.

**Terminer (lot 5)**

30. Finish asks for confirmation from the menu and from the last step; Cancel
    keeps everything.
31. Finishing with recorded results opens the summary. *(`session_review`, adapté)*

Tests unitaires associés : `run_mode_test`, `run_plan_test` (phases),
`run_sheet_cubit_test` (mode, sync), `run_sheet_view_test` (réécrit : en-tête,
frise, barre, sections, `_Source`), `sheet_guide_page_test`, `shell_routes_test`
(`AppRoutes.guide/presentation/plan`, `guideBackTarget`, parse défensif),
`session_planner_bloc_test` (groupe), `timer_chip_test` inchangé.

## 14. Scénarios existants impactés

Compte relevé : `session_guide.feature` 408 lignes, ~45 scénarios ;
`home.feature` (3 assertions « Step n of m »), `screen_navigation.feature` (1),
`session_review.feature` (3 scénarios), `design_system.feature` (1).

| Changement | Scénarios touchés |
|---|---|
| `I see {'Step n of m'} text` devient `I see the guide at step {n} of {m}` (22 assertions) | session_guide (21, dans ~14 scénarios), screen_navigation (« Back to the guided session », l. 23) ; **home.feature : inchangé** (la carte d'Aujourd'hui garde le texte) |
| Public · durée (`Children · 90 min`) passe dans « La séance » : step `I see the session audience {…}` | Launching a session…, Showing the diagram…, A planned session keeps its counters…, A planned session launches with its audience, Launching a planned session prefills…, design_system « The audience badges… », home « Launch from the home… » |
| `Outline` passe par le menu (`I open the guide menu`) | Previous goes back and the outline…, A planned session keeps its counters… |
| `End session` + `Confirm` passe par le menu (`I end the guided session`) | A session is read from start to end, Ending the session resets…, …asks for confirmation (Cancel), A planned session leads back…, session_review ×3 |
| « Montrer » masqué (plus désactivé) sur une étape sans schéma ; le scénario français vérifie `Suivant` et `Étape 1 sur 10`, plus `Montrer` à l'étape 1 sauf si l'étape a une illustration | The French interface labels the guide |
| Barre de progression retirée | scénario « progress bar track is not red » (`design_system.feature`) : réduit à la frise (`the_phase_timeline_*` existent) ; aucun scénario de guide ne la teste |
| Badges visibles : lien direct sans séance -> Relecture -> **inchangés** | An exercise shows its diagram…, A proposed game is read…, An exercise of a proposed block is badged…, The playful theme… (la tuile reste lisible : fin d'étape en Relecture) |
| Retour par la flèche | The guide leads back to the session of the catalogue (inchangé : sans `from` ni `session`) |
| Inchangés (comportement conservé) | reprise (« Launching again a started session… »), sommaire par saut, saisie en feuille et retour à la même étape, adresse de retour étrangère ignorée, présentation (3 scénarios + Outline 1280 × 800), compteurs locaux, bibliothèque illisible, clamp d'étape, « Noting the results opens the record… » |

Steps `test/step` à toucher : `the_phase_is_on_screen` (inchangé), `i_go_to_the_guide_step`
(inchangé, `Next` reste du texte à ≥ 600 dp : le harnais par défaut est 800 × 600 ;
sur écran téléphone, flèches : steps `tap Previous/Next` par infobulle), nouveaux
steps listés au lot 0 ; `la_seance_guidee_est_commencee_a_letape` à relire.

## 15. Risques

| # | Risque | Parade |
|---|---|---|
| R1 | Ampleur de `session_guide.feature` (≈ 35 scénarios touchés) | lot 0 mécanique et vert avant tout changement d'écran ; steps agnostiques |
| R2 | Titre d'étape long tronqué dans `StepAppBar` (une ligne) | sémantique complète (`header`), infobulle ; le sommaire garde le titre entier ; si trop pauvre en mesure, étudier deux lignes dans le composant partagé (mesure, pas de présupposé) |
| R3 | `Semantics` : l'étiquette « Step 6 of 10 » n'est pas un `Text` ; `find.bySemanticsLabel` demande `ensureSemantics` | step dédié du lot 0 |
| R4 | Flèches sans texte en téléphone (< 600 dp) cachent « Précédent / Suivant » | infobulle + sémantique + cible 56 ; repli deux rangées à texte ≥ 130 % ; `[U4-7]` |
| R5 | En-tête de 160 dp à 200 % de texte, ou en paysage de téléphone | frise défilante sous le seuil de hauteur ; test 320 dp / 200 % |
| R6 | Deux cubits pour une même séance (groupe A / sans groupe) | assumé (idem suggestion), plafond 4 ; noter dans l'ADR |
| R7 | Boucle `syncFromRoute` <-> `context.go(guide(..., mode))` | `modeChanged` idempotent, `syncFromRoute` n'émet que si le mode diffère |
| R8 | Une `Semantics` sans rendu pour les `[Prop]` masqués peut être ignorée des lecteurs d'écran | test sémantique dédié (scénario 28) ; mode Relecture reste la voie visuelle |
| R9 | Sections repliées cachent un contenu que l'animateur croit absent | libellés visibles et chevrons ; Relecture déplie tout ; seules des sections « pour aller plus loin » sont repliées |
| R10 | `TimerChip` n'a pas de réinitialisation | menu ⋮ ; test d'accessibilité du menu |
| R11 | Régression de la feuille de saisie hors shell (92 % de hauteur) | scénarios U5 existants conservés, lancés en lot 2 |
| R12 | Historique navigateur : chaque « Suivant » est une entrée d'historique (comportement actuel de `go`) | inchangé ; hors lot |

## 16. Points qui demandent une décision `[U]` de l'animateur

Aucun ne bloque la conception ; chaque défaut ci-dessous sera appliqué si rien
n'est dit.

| # | Question | Défaut proposé |
|---|---|---|
| U4-1 | Un guide lancé depuis la **séance suggérée** (groupe et élèves choisis, pas de séance planifiée) : Mener ou Relecture ? La lettre de Q4 dit Relecture sans séance planifiée | **Mener** (`mode=lead` imposé par la suggestion) ; Relecture pour le détail et les liens directs |
| U4-2 | Sections repliées en Mener : Erreurs fréquentes, Accroche et défi (exercice) ; Variante, Lien, Adaptation (jeu) ; Points à valider (bilan). Toute autre ? | cette liste ; tout le reste ouvert |
| U4-3 | La dernière étape propose-t-elle « Terminer » à la place de « Suivant » (en plus du menu) ? | **oui** |
| U4-4 | La flèche de retour quitte-t-elle le guide **sans** confirmation, la séance restant « en cours » ? | **oui** (reprise depuis Aujourd'hui) |
| U4-5 | Vibration légère aux seuils du minuteur (mobile) | **oui**, une fois par seuil |
| U4-6 | Public · durée, thème et notion dans « La séance » (menu ⋮) plutôt qu'en en-tête | **oui** |
| U4-7 | Téléphone : flèches Précédent / Suivant autour d'un « Noter les résultats » plein (libellés complets dès 600 dp) | **oui** |
| U4-8 | Le groupe choisi dans le catalogue devient aussi le groupe **proposé à la saisie** du guide | **oui** |
| U4-9 | La flèche du guide garde l'infobulle « Retour » (pas de nom de destination) | **oui** |
| U4-10 | Minuteur affiché en **temps restant** (et plus écoulé / prévu) | **oui** |
| U4-11 | Plein écran natif : reporté à U3, test PWA au lot 15 | **oui** |

## 17. Écarts entre la conception et l'implémentation (2026-10-16)

- **Libellés** : `guideModeReviewHint`, `guideTimerResetMenu` et `guideProposalSemantic`
  ne sont pas créés : « Mode relecture » seul dans le menu, `guideTimerReset` existant
  pour « Minuteur à zéro », `proposalBadge` pour l'annonce sémantique. Ajoutés :
  `guidePhaseShort*` (cinq), `guideFold*` (accroche et défi, variante, lien,
  adaptation), `guideBottomBarLabel`, `guideSessionInfo*`, `guideFinishShort`.
  Retirés : `guideTimerLine`, `guideTimerSoon`, `guideTimerOver`, `guideTimerStart`,
  `guideTimerPause`.
- **Domaine** : `RunPlan.phases`, `phaseIndexOf(step)` et `proposalCountOf(step)`
  (nombre de `[Prop]` visibles en Relecture, minutes comprises) ; `firstStepOf`
  existait déjà.
- **Composant partagé** : `StepAppBarAction.checked` (case à cocher, annoncée
  « cochée ») et `enabled`; `StepAppBar` impose des boutons de 48 dp (le retour et le
  menu mesuraient 40 dp). `TimerChip`, `PhaseTimeline` inchangés.
- **Fichiers** : `run_sheet_view.dart` (vue, portée `_GuideScope`, garde du minuteur,
  vibration), `run_guide_header.dart` (frise, ligne phase · minuteur),
  `run_bottom_bar.dart`, `run_session_info.dart` (feuille « La séance »),
  `run_step_views.dart` (média d'abord, `_Fold`, `_Source` conscient du mode) ;
  `run_timer_bar.dart` supprimé. Parties `part` privées (aucun nouveau widget public).
- **Mise en page** : l'étape n'est plus dans une `Card` (gain de largeur) ; le schéma
  est borné à la hauteur restante (`TableDiagramPlayer.maxHeight`) quand l'écran est
  assez haut pour épingler la frise, sinon le contenu défile ; ligne phase · minuteur
  en `Row` (minuteur sous la phase à texte ≥ 130 %).
- **Barre basse** : flèches seulement sur un exercice (ou le créneau de rappel) sous
  600 dp ; sans saisie, deux boutons avec texte ; à texte ≥ 130 % sous 600 dp,
  boutons empilés à pleine largeur.
- **Tuile du thème** : en Relecture, en fin d'étape ; en Mener, dans « La séance ».
- **Reports soldés** : U-9 (retour à l'origine, groupe conservé de bout en bout,
  « Planifier cette séance » emporte le groupe) ; **non soldé** : la séance suggérée
  ouvre son détail sans groupe (le rappel `onOpenSheet` de la page ne porte pas le
  groupe) ; le lancement direct depuis la suggestion garde le sien.
- **Plein écran natif** : reporté à U3 (§ 9), test PWA au lot 15, inchangé.

## 18. Parcours web de confirmation (2026-10-16)

Build `flutter build web --release`, servi par `http.server`, Playwright à 390 × 844,
1024 × 768 et 1280 × 800. Aucune erreur ni avertissement console, aucun défaut
bloquant, aucune correction de code nécessaire.

- **Vérifié** : pas de barre ni de rail dans le guide ; en-tête compact (retour,
  titre, position, menu, frise) ; schéma visible sans défiler (bas à y ≈ 365 à 448
  sur 844, barre basse à y ≈ 775) ; sections repliées en Mener, badges masqués,
  information « Proposition » dans l'arbre sémantique ; Relecture ouverte sans séance
  planifiée, avec badges ; minuteur (neutre à 1:00, attention à 0:30, dépassé avec
  « + » et icône) ; Noter (présélection de l'exercice, retour à la même étape) ;
  « Terminer » confirmé, bilan d'U7 quand des passages ont été saisis ; rechargement
  (étape et mode conservés) ; U-9 (retour à Aujourd'hui, à Planifiées, au détail puis
  au catalogue avec le groupe coché) ; deux colonnes à 1024.
- **Corrections après revue** (sans lien avec un défaut du parcours) : l'aide de
  saisie `guideRecordHint` suit désormais `mode == review` ; tests ajoutés pour
  `proposalCountOf` (adaptation du public), les seuils exacts de la vibration
  (60 s restantes : rien ; 0 s : rien ; dépassement à 1 s) et les sections repliées du
  jeu (variante, lien, adaptation) en Mener et en Relecture ; le rappel de la séance
  précédente reste lisible en Mener (constat D3 : voulu, ce n'est pas une section
  repliable).
- **Constats tranchés conformes** : D2 minuteur dépassé : `errorContainer` retiré le 2026-10-17 (pas de rouge), remplacé par
  `inverseSurface` avec sablier (design-system.md) ; E1 « Noter » aux seules étapes d'exercice (§ 5) ; E2 le
  retour du guide lancé depuis le détail ramène au détail (`guideBackTarget`).
- **Hors périmètre U4, à traiter ailleurs** :
  - ~~D1~~ **soldé le 2026-10-16** ([ADR 0016](adr/0016-identite-de-la-saisie-par-groupe-jour-et-seance.md),
    [plan](lien-saisie-planifiee-plan.md)) : une séance planifiée dont la date et le
    groupe ont déjà une saisie s'affichait « Résultats saisis » dès sa création (et
    « Noter » réécrivait la séance de l'autre saisie). Une saisie est désormais
    identifiée par (groupe, jour, séance du catalogue), règle unique `recordFor`.
  - E3 : titres d'exercice tronqués dans l'en-tête à 390 dp (titre complet dans le
    contenu). E4 : segment « Bilan » de la frise étroit.
  - Rechargement web : minuteur et compteurs repartent de zéro (architecture.md).
  - Non vérifiés : vibration (pas de capteur) et mode immersif (U3, lot 15).

### Mineurs des revues indépendantes, soldés (2026-10-16)

- **Seuil unique** : `TimerTone`, `timerAttentionThreshold` et `timerToneFor` vivent
  dans `shared/lib/timer_tone.dart` (Dart pur) ; `TimerChip` et le guide
  (`RunSheetState.timerTone`) en dérivent. `RunTimerStage`, `runTimerStageOf` et le
  test de concordance sont supprimés ; les bornes exactes (60 s, 0 s, dépassement)
  sont testées une fois, dans `timer_tone_test.dart`.
- **Libellé du dépassement** : pas de défaut de code. Le texte (`+mm:ss`) et le
  libellé sémantique (« Over time by mm:ss ») viennent de la même valeur `remaining`
  dans un même `build` ; un test fixe `-22 s` à `+00:22` et « Over time by 00:22 »
  (rouge par mutation). L'écart vu sous `page.clock` est un artefact de l'horloge
  simulée (arbre sémantique web lu à un autre instant).
- **BDD en comportement** : les scénarios d'origine et de mode vérifient l'effet
  visible (destination Aujourd'hui sélectionnée, onglet Planifiées / Suggestion,
  détail affiché, case « Mode relecture » du menu ⋮, nombre exact de badges) ; le
  rechargement est un step (`I reload the guide`). Les paramètres d'adresse restent
  testés dans `shell_routes_test` (`guideBackTarget`, `AppRoutes.guide`, dont
  l'omission du mode par défaut) et dans `run_sheet_cubit_test` (`routeMode`).
- **U4-8** : déjà couvert par « The group chosen in the catalogue is proposed to the
  record opened from the guide » (rouge constaté par mutation : retirer le groupe du
  lancement depuis le détail).
- Aucune décision `[U]` modifiée ; l'ADR 0015 est inchangé.
