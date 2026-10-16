# Plan d'exécution : catalogue et détail en mode « Préparer » (lot U8)

Statut : **livré le 2026-10-16** (voir § 12 « Réalisation »). Sources :
[roadmap](roadmap.md) (U8), [ux/plan-ux-proposition.md](ux/plan-ux-proposition.md)
(§ 4, scénarios « U8 »), [ux/recommandations-design.md](ux/recommandations-design.md)
(R12, R13), [ux/audit-ux-ui.md](ux/audit-ux-ui.md) (C1 à C5, D1 à D4),
[ADR 0004](adr/0004-catalogue-fiches-seances.md),
[0009](adr/0009-suggestion-seance-du-catalogue.md),
[0010](adr/0010-roles-de-couleur-bleu-tapis-et-accent.md),
[0011](adr/0011-creneau-exercice-de-rappel.md),
[aujourdhui-plan.md](aujourdhui-plan.md) (U-12),
[navigation-plan.md](navigation-plan.md). Pas d'ADR (voir § 9) : aucune
persistance, aucune dépendance, aucun schéma ; tout est dérivé de données
existantes.

## 1. Périmètre exact

**Dans le lot**

1. Catalogue (`/catalogue`) : titre de ligne = nom évocateur ; sous-titre
   « Séance k/n · <technique> » ; **un** badge « n points à valider » (motifs majeurs) et un badge neutre par proposition mineure ;
   pastille « Source fédérale » retirée de la liste ; ligne « 14 techniques ·
   28 séances » en sous-titre de l'en-tête ; sélecteur de groupe et marqueur de
   parcours (✓ / ▶ / ○) ; bouton « Suggestion par groupe » retiré.
2. Détail (`/catalogue/:sheetId`) : `PhaseTimeline` tapable sous la bascule de
   public (remplace « Aller à ») ; carte d'exercice en deux colonnes dès 720 dp ;
   phrase « lecture seule » supprimée ; note « à valider » détaillée par motif ;
   menu ⋮ « Signaler une proposition » ; origine de la page (Aujourd'hui /
   Planifiées / Catalogue).
3. Report d'U7 (U-12) : « Préparer » depuis « Aujourd'hui » revient à
   « Aujourd'hui ». Report d'U6 : retrait du bouton redondant.

**Hors lot** (documenté, rien de stubbé) : workflow de validation `[Prop]` et
marque « relu » (lot 16) ; courriel réel (voir § 6, `[U-5]`) ; retour du guide
vers « Aujourd'hui » quand « Lancer » part d'Aujourd'hui (le guide revient à
« Planifiées », comportement U7 inchangé, risque R5) ; frise collante ; tout
changement de `docs/knowledge`, du schéma drift, de la sauvegarde.

## 2. État constaté dans le code (points qui contraignent la conception)

- Ligne actuelle (`sheet_catalogue_view.dart`, `_SheetTile`) : titre
  `sheetPartLabel`, sous-titre `sheet.theme.name`, puis un `Wrap` de
  `ProvenanceBadge` (sources), `ProposalBadge` et un `StatusBadge` **par motif**
  (`ReviewReason`). Clés `review:<id>:<motif>` utilisées par les steps.
- `reviewReasonsOf` (entities/session_sheet) : motifs `game`, `exercise`,
  `initiation`, `recall` (`counts: true`), `gameLink`, `theory` (`counts:
  false`, signalés sans déclencher). `needsReview` = au moins un motif qui
  compte ; le filtre « À valider » l'utilise. Sur les 28 séances : 18 « à
  valider », 24 avec théorie `[Prop]`, 16 avec règle de lien.
- Le **nom évocateur** est `SessionSheet.theme.name` (« Le partage du gâteau »),
  déjà dans les 28 YAML, obligatoire (`SheetTheme` requis). Le thème est
  `[Prop]` par définition (`_ThemeBlock` pose `Provenance.prop`). Le titre de
  technique est `SessionSheet.title` (« Quantité demi-bille »).
- Aucune notion de **groupe sélectionné** dans le catalogue. La règle
  « faite » (ADR 0009 S7) est **privée** à `suggestSheet`
  (`lastGiven`) ; la séance recommandée vient de `SuggestSession` /
  `SuggestNextSheet` (qui exige des élèves attendus et lève `noStudents`).
- `PhaseTimeline` exige `minutes > 0` par segment ; `phaseMinutes` des 5 phases
  est ≥ 1 (`SessionShape.isValidFor`). `currentIndex` hors bornes (-1) est
  accepté par le code (aucun segment courant).
- Le détail passe par `ScrollPage` → `ResponsiveBody(maxWidth: 720)` : le
  contenu fait **au plus 688 dp**. Un seuil de 720 dp sur la largeur du contenu
  ne se déclencherait **jamais**. Le guide utilise `maxWidth: 1100`.
- Origine : `AppRoutes.sheet(..., fromPlanner)` ajoute `from=planner` ; la page
  et le routeur comparent la chaîne. « Préparer » d'Aujourd'hui l'utilise
  (`fromPlanner: true`). Le guide lancé depuis le détail revient au détail
  **sans** `from`.
- Ni `url_launcher`, ni `share_plus`, aucune adresse de courriel dans le dépôt.
  `Clipboard` (`flutter/services`) est disponible sans dépendance.
- `AppShell.sessionsTabOf` compare `state.uri.path` : un paramètre de requête
  sur `/catalogue` ne fait pas perdre les onglets.

## 3. Décisions argumentées

### 3.1 Badge unique « n points à valider »

- **n** = nombre de motifs **qui comptent** de `reviewReasonsOf` (jeu,
  exercices, initiation, rappel) : 0 à 4. Fonction pure
  `reviewPointCount(SessionSheet)` ajoutée à
  `entities/session_sheet/domain/needs_review.dart`. **Invariant testé :**
  `reviewPointCount > 0 ⇔ needsReview` ; le filtre « À valider » et le badge
  ne peuvent donc pas diverger. Un « point » = un type de contenu à relire, pas
  un bloc : la liste détaillée est dans le détail.
- **Une ligne = au plus un badge « à valider »**, remplaçant `ProposalBadge` +
  les `StatusBadge` des motifs majeurs + les `ProvenanceBadge` ; les
  propositions mineures gardent leur badge neutre (`[U-1]`, plus bas). Rendu : `StatusBadge`
  (`BadgeTone.attention`, icône + libellé, jamais la couleur seule, pas de
  rouge : ADR 0010). Libellé `catalogueReviewPoints(n)` (pluriel ICU :
  « 1 point à valider » / « 3 points à valider »).
- **Détail au survol** : `Tooltip` sur le badge (survol web/desktop, appui long
  tactile) listant les motifs qui comptent (les propositions mineures ont leur
  propre badge neutre, clé `review:<id>:<motif>`) ;
  `Semantics.label` identique (le survol ne doit pas être la seule voie). Même
  liste, en puces, dans le **détail** : `_ToValidateNote` devient « n points à
  valider » + une ligne par motif (réutilise les libellés `catalogueReason*`,
  déplacés dans un helper `review_labels.dart` du slice `browse_sheets`).
- **Distinction `[Prop]` / à valider / source fédérale, sans masquer la
  provenance** :
  - *À valider* (n > 0) : le badge.
  - *`[Prop]` mineurs* (théorie, règle de lien) : jamais dans n (ADR 0004 §
    indicateur : sinon 24 et 16 séances sur 28 vident le signal) ; **badge
    neutre rétabli par ligne** (décision `[U-1]`), sur toute ligne qui en a,
    n = 0 comme n > 0 ; listés aussi dans la note du détail, où
    `ProposalBadge` reste posé **en contexte sur chaque élément** (inchangé).
  - *`[Prop]` par définition* (nom évocateur, minutes, poids, défis, variante) :
    badgés en contexte dans le détail (inchangé). Parce que le **titre de
    ligne** devient un `[Prop]`, l'en-tête du catalogue porte une ligne fixe
    `catalogueNamesNote` (« Les noms évocateurs sont des propositions, non
    fédérales. ») : c'est la seule façon de ne pas répéter 28 fois un badge
    vrai partout (même raisonnement que « Source fédérale »), sans laisser un
    `[Prop]` non signalé.
  - *Source fédérale* : retirée de la liste, **conservée** dans le détail (les
    `_Source` par élément et la section « Sources » ne changent pas).
  - Séance à n = 0 : pas de badge « à valider », mais le badge neutre de
    chaque proposition mineure (« Règle de lien du jeu : proposition »), comme
    avant U8 : aucune proposition mineure ne disparaît de la liste (`[U-1]`).
    Infobulle et sémantique du badge neutre : « Proposition non sourcée :
    signalée, non comptée dans les points à valider. »

### 3.2 Nom évocateur : source et repli

- Source : `SessionSheet.theme.name` (donnée existante, aucune migration, aucun
  YAML modifié). Le modèle impose déjà un `SheetTheme` non optionnel et la
  validation du catalogue (`FORMAT.md` § 7) vérifie sa présence : **pas de
  repli à coder pour un nom vide**. Un test de couverture sur les 28 séances
  réelles (`theme.name.trim().isNotEmpty`) remplace le repli (une branche
  morte serait un stub). Si malgré tout le nom était vide, la ligne tombe sur
  `sheetPartLabel` seul (garde `isEmpty`, 1 test) pour ne jamais afficher un
  titre vide.
- Sous-titre : `sheetPartLabel(part, partCount)` + séparateur + **titre de
  technique** (`group.title`, « Quantité demi-bille »). La roadmap écrit
  « Demi-bille » ; le champ réel est « Quantité demi-bille » (YAML fédéral) :
  on garde le titre réel, sans abréger (aucune troncature inventée).
  Nouvelle clé `catalogueRowSubtitle(part, parts, technique)`.
- Le titre de la page détail (`sheetFullTitle`, « Quantité demi-bille, séance
  1/2 ») **ne change pas** : le nom évocateur reste dans `_ThemeBlock` avec son
  badge `[Prop]`. Les scénarios existants qui lisent ce titre restent verts.
- Sémantique de ligne : `title` + `subtitle` + n, lus d'un trait par le
  `ListTile` ; la clé `sheet:<id>` est conservée.

### 3.3 Marqueur de parcours par groupe

**Règle unique, non dupliquée.** La règle « faite » (saisie du groupe avec
`sheetId` et au moins un passage, datée d'aujourd'hui ou avant) est extraite
telle quelle de `suggestSheet` en une fonction pure
`givenSheets({groupSessions, attemptCountBySession, today}) →
Map<SheetId, DateTime>` (dans `features/suggest_session/domain`), **appelée par
`suggestSheet` et par le parcours**. Le refactor est couvert par les tests
existants de `suggestSheet` (doivent rester verts sans modification) plus un
test direct de `givenSheets`. La séance « recommandée ensuite » est
`SuggestNextSheet(...)` **tel quel** (ADR 0009), jamais recalculée.

- Nouveau cas d'usage `GetGroupJourney(groupId)` →
  `GroupJourney { Map<SheetId, DateTime> done, SheetId? next, bool noStudents }`
  dans `features/suggest_session/domain`. Élèves attendus = membres du groupe
  au jour courant (`Group.membersOn(today)`), horloge injectée. Groupe sans
  élève → `noStudents = true`, `next = null`, `done` quand même renseigné
  (`SuggestNextSheet` lèverait `noStudents`) ; groupe inconnu → `NotFound`
  (le catalogue ignore alors le groupe).
- Marqueur par séance : `JourneyMark { done, next, upcoming }` (enum dans
  `shared/lib`, lu par `shared/ui` et par `browse_sheets` sans lien latéral).
  **Précédence : `next` > `done` > `upcoming`.** Si toutes les parties de la
  notion sont faites (`kind == repeat`), la séance proposée reste ▶ (cohérence
  avec l'onglet Suggestion, qui la propose « déjà donnée le … ») ; les autres
  parties de la technique sont ✓.
- **Cas « plusieurs parties »** : un marqueur **par séance** (donc par partie),
  jamais par technique ; une technique peut mêler ✓ ✓ ○ ; une seule séance du
  catalogue entier est ▶ (celle de la notion principale du groupe). Une partie
  sautée (partie 2 faite, partie 1 non) reste ○ ; une saisie sans `sheetId` ou
  sans passage, ou une séance seulement planifiée, ne compte pas (S2, S5, S7).
  Notion sans séance (`quantites-de-billes`, `trajectoires-blanche`, cas
  nominal ADR 0009) : aucun ▶, les ✓ restent.
- **Sélecteur de groupe** (nouveau, dans l'en-tête, sous le sous-titre) :
  `ChoiceChip` « Aucun groupe » (défaut, aucun marqueur) + un chip par groupe
  des saisons en cours (`currentGroups`, comme le planificateur). **État
  d'écran**, jamais stocké ; valeur initiale lue dans `/catalogue?group=<id>`
  (identifiant inconnu → « Aucun groupe »). Le groupe choisi est repassé dans
  l'adresse du détail (`group=`) pour que le retour restaure la sélection.
- **Rendu** : `JourneyMarker` (widget `shared/ui`, 48 dp, icône **et** libellé
  sémantique : `check_circle` « Faite », `play_circle` « Recommandée ensuite »,
  `radio_button_unchecked` « À venir » ; formes distinctes, bleu-tapis
  `secondary`, jamais le rouge ni la couleur seule), en `leading` du
  `ListTile`. Sans groupe, pas de `leading` (aucune colonne vide).
  Légende d'une ligne sous le sélecteur (`catalogueJourneyLegend`).
- **Composition sans import latéral** : `GroupJourneyCubit` vit dans
  `features/suggest_session/presentation` (comme `NextSheetCubit`) ;
  `SheetCatalogueView` (`browse_sheets`) reçoit seulement
  `Map<SheetId, JourneyMark> marks` et des groupes `(GroupId, String)` via
  des types de `shared/lib` ; `pages/sheet_catalogue` instancie les deux et les
  relie. `browse_sheets` n'importe jamais `suggest_session`.

### 3.4 Frise des phases tapable

- `_Outline` (`ActionChip` « Aller à ») est supprimé ; `PhaseTimeline` prend sa
  place **sous la ligne « n min au total (approximatif) » de `_AudienceBar`**,
  donc sous la bascule de public. Cette ligne porte déjà la pastille `[Prop]`
  « minutes » : les minutes de la frise (calculées, `[Prop]`) sont couvertes
  par ce badge voisin et par le `ProposalBadge` de chaque en-tête de phase.
- Entrées : 5 phases dans l'ordre `SessionPhase.values`, libellés
  `sheetJump*` existants (« Rappel » / « Accueil » en première séance,
  « Théorie », « Exercices », « Jeu », « Bilan »), minutes =
  `timing.phaseMinutes[phase]` du public affiché (la frise suit la bascule).
- **Ancres** : les `GlobalKey` de `_PhaseSection` déjà en place ;
  `onSelected(i)` → `_jumpTo(SessionPhase.values[i])` (`Scrollable
  .ensureVisible`, durée nulle si animations désactivées : code existant
  réutilisé). Clés des segments `phase-1` à `phase-5` (existantes, step
  `I tap the phase {n}` déjà écrit).
- **État** : `currentIndex = -1` (aucun segment « courant »). La frise du détail
  est une table des matières, pas un indicateur de progression ; elle n'est pas
  collante, donc une phase « courante » synchronisée au défilement serait
  invisible dès qu'on défile. Pas d'écouteur de défilement, pas d'état. Les
  segments restent des boutons (`Semantics.button`, ≥ 48 dp, défilement
  horizontal sous 5 × 48 dp).

### 3.5 Deux colonnes dès 720 dp

- Seuil : **largeur de fenêtre ≥ 720 dp** (`MediaQuery.sizeOf`), le même
  `wideBreakpoint` que `AppNavigation` (cohérent : rail + carte à deux
  colonnes apparaissent ensemble). Le détail passe à `ResponsiveBody(maxWidth:
  1100)` (paramètre `maxWidth` ajouté à `ScrollPage`, défaut 720 inchangé pour
  les autres pages), sinon le contenu plafonne à 688 dp (§ 2).
- `_ExerciseCard` ≥ 720 dp : `Row` — **schéma à gauche** (`flex 5`, plafonné par
  `SheetIllustrationView.maxWidth`), texte à droite (`flex 6`) : taux, passes,
  mise en place, consigne, attendu, erreurs. En dessous : colonne unique
  actuelle. Même contenu, même ordre de lecture (schéma avant texte), mêmes
  clés `exercise:<id>`.
- Seules les cartes d'exercice changent (R13) ; le reste de la page reste en
  colonne unique, plafonnée à 760 dp de texte pour la lisibilité. Aucun
  `Row` sans `Expanded`/`Flexible` (pas de débordement à 320 dp : test
  `narrow_layout`).

### 3.6 Menu ⋮ « Signaler une proposition »

- `ScrollPage` gagne un paramètre `actions` (liste de widgets en fin de la ligne
  du retour). Le détail y pose un `PopupMenuButton` (infobulle « Plus
  d'actions », 48 dp) avec une entrée **« Signaler une proposition »**, visible
  pour toute séance (les 28 contiennent du `[Prop]`).
- **Comportement unique sur toutes les plateformes, sans dépendance** : copie
  dans le presse-papiers (`Clipboard.setData`, `flutter/services`) d'un texte
  fixe `sheetReportText(id, title)` (« Proposition à relire — séance
  demi-bille-1 (Quantité demi-bille, séance 1/2) »), puis `SnackBar`
  « Identifiant copié : demi-bille-1 » (région live, annoncé). Aucun
  `mailto:` : l'ouvrir exige `url_launcher` (nouvelle dépendance, interdite sans
  décision écrite) ou du code web conditionnel, et **aucune adresse de
  destinataire n'existe** dans le dépôt. Échec du presse-papiers (rare) : le
  `SnackBar` affiche l'identifiant en clair (`sheetReportFailed(id)`), jamais
  d'erreur muette.
- Provisoire jusqu'au lot 16 (même texte à brancher sur le workflow de
  validation). Voir `[U-5]`.

### 3.7 Retrait du bouton « Suggestion par groupe »

- Supprimés : le bouton `OutlinedButton.icon`, le paramètre `onOpenSuggestion`
  de `SheetCataloguePage`, son câblage dans le routeur, la clé
  `catalogueSuggestion` (fr + en, régénération gen-l10n). L'onglet
  « Suggestion » de la destination « Séances » (U6, `/session`) est l'unique
  accès, comme à l'accueil (`onOpenSuggestion` de `HomePage`, inchangé).
- **20 scénarios** (hors `session_catalogue.feature`) enchaînent « I tap
  {'Sessions'} » puis « I tap {'Group suggestion'} » : `proposal_blocks` (3),
  `screen_navigation` (2), `suggested_session_screen` (14), plus 1 dans
  `session_catalogue`. Ils sont migrés mécaniquement vers « I tap
  {'Suggestion'} » (texte de l'onglet, identique fr/en, présent sur
  `/catalogue`) ; aucun comportement testé ne change. Fait **dans un
  commit/lot à part** (§ 7, lot F) pour isoler le bruit.

### 3.8 Origine de « Préparer » : paramètre de route

- **Paramètre d'adresse, pas d'état** : `from=` (déjà présent) élargi à
  l'énumération `SheetOrigin { catalogue, planner, today }` dans `app/`
  (`AppRoutes`). Un état en mémoire serait perdu au rechargement web et
  casserait les liens profonds ; la route est la seule source (même principe
  que le bilan d'U7). Valeurs d'adresse : `planner` (inchangée), `today`
  (nouvelle), absent = catalogue.
- `AppRoutes.sheet(id, {audience, SheetOrigin origin = catalogue, GroupId?
  group})`. L'ancien booléen `fromPlanner` est supprimé (4 appelants :
  routeur ×3, `AppRoutes`), remplacé par `origin: SheetOrigin.planner` ; **les
  adresses produites pour `planner` sont identiques** (`?from=planner`), donc
  tous les liens profonds existants sont inchangés.
- **Analyse défensive** : `SheetOrigin.parse(String?)` ; toute valeur inconnue
  → `catalogue` (jamais une adresse libre, cf. `_guideReturn`).
- Retours : `today` → `AppRoutes.home`, libellé `navHome` (« Aujourd'hui ») ;
  `planner` → `/planner`, `plannerTitle` ; `catalogue` →
  `/catalogue` (+ `?group=` si présent), `catalogueTitle`. Le paramètre de
  la page `SheetDetailPage.fromPlanner` devient `origin` + `backLabel` calculé
  par le routeur (la page ne connaît pas `AppRoutes`).
- Appelants : `HomePage.onPrepare` → `origin: today` ; planificateur,
  suggestion, catalogue inchangés en dehors du type. Les liens
  « Lancer » / « Planifier » du détail ne portent pas `from` (inchangé).

## 4. Slices FSD et composition

| Couche | Fichier / slice | Changement |
|---|---|---|
| shared/lib | `journey_mark.dart`, `group_choice.dart` | `enum JourneyMark` ; `GroupChoice(GroupId, String)` (types sans logique, chacun dans son fichier) |
| shared/ui | `journey_marker.dart` (+ cas Widgetbook), `scroll_page.dart` (`maxWidth`, `actions`) | marqueur 48 dp accessible ; paramètres facultatifs |
| shared/l10n | `app_fr.arb`, `app_en.arb` | clés § 8 ; suppression de `catalogueSuggestion`, `sheetReadOnly`, `sheetOutline` ; `catalogueSummary` sans « lecture seule » |
| entities/session_sheet | `needs_review.dart` | `reviewPointCount` |
| features/browse_sheets | `sheet_catalogue_view.dart`, `sheet_detail_view.dart`, `sheet_detail_sections.dart` (+ `review_labels.dart`) | ligne, badge, groupe + marques en paramètres, frise, deux colonnes, note détaillée |
| features/suggest_session | `domain/given_sheets.dart`, `domain/get_group_journey.dart`, `domain/group_journey.dart`, `presentation/bloc/group_journey_cubit.dart` | règle extraite + cas d'usage + cubit |
| pages/sheet_catalogue | page | compose `SheetCatalogueBloc` + `GroupJourneyCubit`, sélecteur de groupe, sous-titre d'en-tête ; sans `onOpenSuggestion` |
| pages/sheet_detail | page | `origin`, `backLabel`, menu ⋮, largeur 1100 |
| app | `router.dart` | `SheetOrigin`, `AppRoutes.sheet`, `AppRoutes.catalogueFor(group)`, câblage |

Imports vers le bas uniquement ; **aucun import entre `browse_sheets` et
`suggest_session`** : la page `sheet_catalogue` lit l'état des deux et passe
des types `shared/lib`. `domain` reste en Dart pur, horloge `Clock` injectée
(jamais `DateTime.now()`).

## 5. Scénarios BDD à écrire d'abord (`session_catalogue.feature` sauf mention)

À écrire, steps implémentés, **vus rouges pour de vraies assertions** avant tout
code. Nouveaux steps à prévoir (aucun n'existe) : `the session {} shows {} points
to validate`, `the session {} has no review badge`, `the review badge of {}
explains {}`, `the session {} is marked {done|next|upcoming}`, `no session is
marked`, `the session {} has the title {}`, `I choose the group {}`, `the
group {} has given the session {}` (variante avec/sans passage : steps
`a_session_is_recorded_…` existants à réutiliser), `the detail columns are
{one|two}`, `the clipboard holds {}`. Réutilisés : `the screen is {} by {}`,
`I tap the phase {}`, `the phase {} is on screen`, `the element {} is marked as
a proposal/sourced`.

Catalogue (R12)
1. *Le titre d'une ligne est le nom évocateur de la séance* (« Le partage du
   gâteau » en titre, « Séance 1/2 · Quantité demi-bille » en sous-titre).
2. *Une séance à valider porte un seul badge avec le nombre de points* (jeu de
   test des fixtures : n attendu par séance ; ni badge de source ni badge « Proposition » sur la ligne ; les badges neutres des motifs mineurs sont attendus en plus).
3. *La pastille « Source fédérale » n'est plus dans la liste mais reste dans le
   détail.*
4. *Le badge explique ses motifs ; les propositions mineures ont leur badge
   neutre* (tooltip du badge : motifs qui comptent ; posture-1 : badge
   « Théorie : proposition » en plus de « 2 points à valider », décision U-1).
5. *Une séance sans point à valider n'a pas de badge « à valider », mais son
   badge neutre de proposition mineure en liste (demi-bille-1 : règle de lien)
   et ses propositions signalées dans le détail.*
6. *Les filtres et le badge s'accordent sur le catalogue réel* (18 séances à
   valider = 18 badges ; 11 jeux).
7. *L'en-tête dit la taille du catalogue et que les noms sont des
   propositions* (remplace l'assertion « · read-only » de deux scénarios).
8. *Sans groupe, aucune ligne n'a de marqueur.*
9. *Avec un groupe, les séances faites sont cochées et la suivante est
   recommandée* (posture-1 ✓, posture-2 ▶, le reste ○).
10. *Une saisie sans passage ne compte pas comme faite* (et séance planifiée
    non saisie : ○).
11. *Une technique à plusieurs parties a un marqueur par partie* (✓ ✓ ○ ; une
    seule ▶ dans tout le catalogue).
12. *Toutes les parties faites : la proposée reste recommandée* (repeat, ▶ sur
    la séance de la tête, ✓ sur les autres).
13. *Une notion sans séance du catalogue n'a pas de séance recommandée.*
14. *Un groupe sans élève montre les séances faites seulement.*
15. *Le groupe choisi survit à l'ouverture d'une séance et au retour.*
16. *Les marqueurs sont annoncés* (étiquettes « Faite », « Recommandée
    ensuite », « À venir »).
17. *Le bouton « Suggestion par groupe » a disparu, l'onglet Suggestion mène à
    la suggestion* (remplace « The group suggestion stays one tap away »).

Détail (R13)
18. *La frise des phases est sous la bascule de public et mène à la phase*
    (remplace « The outline jumps to the game and back » ; plus de texte
    « Go to »).
19. *Les minutes de la frise suivent le public* (90 → 120, somme égale).
20. *La phrase « lecture seule » a disparu* (remplace l'assertion de « A session
    is read-only … » ; l'assertion « the content cannot be edited » est
    conservée).
21. *La carte d'exercice passe sur deux colonnes dès 720 dp* (fenêtre 719 → une
    colonne, 720 → deux, schéma à gauche ; sans débordement).
22. *« Signaler une proposition » copie l'identifiant de la séance.*

Origine (`home.feature`, `session_catalogue.feature`)
23. *« Préparer » depuis Aujourd'hui revient à Aujourd'hui* (remplace la fin de
    « Prepare from the home opens the catalogue session »).
24. *Ouverte depuis Planifiées, la séance revient à Planifiées* (inchangé en
    comportement, scénario de non-régression explicite).
25. *Ouverte depuis le catalogue, la séance revient au catalogue.*
26. *Une origine inconnue retombe sur le catalogue* (`?from=evil`).
27. *Un lien profond sans origine est inchangé.*

## 6. Points qui demandent une décision `[U]` de l'animateur

| N° | Question | Proposition par défaut |
|---|---|---|
| U-1 | Séance à n = 0 mais avec `[Prop]` mineurs (théorie, règle de lien) : badge neutre ou rien en liste ? | **Tranché par l'animateur : le badge neutre est rétabli** (un par motif mineur, sur toute ligne qui en a). La mention texte neutre proposée par défaut est rejetée et supprimée |
| U-2 | Unité de « n » : types de contenu à relire (0 à 4) ou éléments individuels (chaque exercice `[Prop]`) ? | Types de contenu (stable, cohérent avec filtre et indicateur) ; le détail liste les éléments |
| U-3 | Nom évocateur `[Prop]` en titre : une ligne fixe d'en-tête suffit-elle, ou un badge `[Prop]` sur chaque ligne ? | Ligne fixe d'en-tête (pas de répétition) |
| U-4 | Séance déjà donnée par tout le groupe (repeat) : ▶ ou ✓ ? | ▶ (cohérent avec l'onglet Suggestion) |
| U-5 | « Signaler une proposition » : adresse de courriel de destination et acceptation d'une dépendance (`url_launcher`) ? | **Tranché : copie de l'identifiant seulement ; le courriel relève du lot 16** (ADR si dépendance) |
| U-6 | Groupe sélectionné du catalogue mémorisé d'une session à l'autre (réglage) ? | Non : état d'écran, restauré par l'adresse au retour du détail |
| U-7 | Garder « · lecture seule » dans « 14 techniques · 28 séances » ? | Non (cohérent avec la suppression dans le détail) |
| U-8 | Frise collante (toujours visible en défilant) ? | Non en U8 (le guide a déjà sa frise) |
| U-9 | « Lancer » depuis Aujourd'hui doit-il aussi revenir à Aujourd'hui (aujourd'hui : Planifiées) ? | **Tranché : à traiter avec le guide (U4), hors lot, documenté seulement** (risque R5) |

## 7. Lots d'implémentation (ordre, chacun avec BDD rouge d'abord, `check.sh --full` vert)

- **A. Règles pures.** `reviewPointCount` (+ invariant avec `needsReview` sur les
  28 séances réelles), `givenSheets` extraite de `suggestSheet` (tests
  existants inchangés verts), `GroupJourney`/`GetGroupJourney`, `SheetOrigin`.
  TDD unitaire seul (pas de BDD : aucun comportement visible).
- **B. Lignes du catalogue.** Scénarios 1 à 7 : titre, sous-titre, badge unique,
  tooltip, retrait des pastilles, sous-titre d'en-tête, note des noms. Tests
  de widget de `SheetCatalogueView` (réécriture), `review_labels`.
- **C. Détail.** Scénarios 18 à 22 : frise, note détaillée, suppression de la
  phrase, deux colonnes (`ScrollPage.maxWidth`), menu ⋮ (`ScrollPage.actions`).
- **D. Origine.** Scénarios 23 à 27 : `AppRoutes.sheet`, `SheetOrigin`, page
  détail, `HomePage.onPrepare`.
- **E. Parcours.** Scénarios 8 à 16 : `GroupJourneyCubit`, sélecteur, marqueur
  (`JourneyMarker`), passage de `group=`.
- **F. Retrait du bouton.** Scénario 17 + migration mécanique des 20 scénarios
  (`Group suggestion` → `Suggestion`) ; suppression de la clé et du câblage.
  Peut passer **avant B** pour isoler le bruit de scénarios.
- **G. Fin.** Widgetbook (`JourneyMarker`, ligne de catalogue, détail deux
  colonnes), `narrow_layout` à 320 dp et texte 200 %, docs (`roadmap.md`,
  `architecture.md`, `design-system.md`, `navigation-plan.md`, `testing.md`,
  `aujourdhui-plan.md` U-12 tranché, ce plan en « livré », `ux/` si besoin).
  Vérification Playwright web (mémoire `tester-app-web-playwright`).

Ordre conseillé : A → F → B → C → D → E → G (E en dernier : le plus coûteux,
seul à ajouter un cas d'usage et un cubit).

## 8. Clés l10n (fr + en, identiques)

Ajoutées : `catalogueReviewPoints(n)`, libellés des badges neutres des motifs
mineurs (`catalogueMinorTheory`, `catalogueMinorGameLink`) et leur infobulle
`catalogueMinorHint`,
`catalogueRowSubtitle(part, parts, technique)`, `catalogueNamesNote`,
`catalogueGroupLabel`, `catalogueGroupNone`, `journeyDone`, `journeyNext`, `journeyUpcoming`, `catalogueJourneyNoStudents`,
`sheetReviewHeading(n)`, `sheetMenuTooltip`, `sheetReport`, `sheetReportText`,
`sheetReportCopied(id)`, `sheetReportFailed(id)`, `sheetBackToToday` (si
`navHome` ne suffit pas). Retirées : `catalogueSuggestion`, `sheetReadOnly`,
`sheetOutline`, `catalogueReasonTheory`, `catalogueReasonGameLink` (remplacées par `catalogueMinor*`). Les motifs qui comptent gardent `catalogueReason*`. La légende des marqueurs n'a pas d'intitulé (`catalogueJourneyLegend` non créée). Aucun glyphe
décoratif en dur (✓ ▶ ○ sont des `Icon`).

## 9. Risques

- **R1 – refactor de la règle « faite »** : un écart changerait la séance
  suggérée. Parade : `givenSheets` extrait sans réécriture, tests
  d'`suggestSheet` inchangés comme filet, un cas de table partagé.
- **R2 – seuil de 720 dp** : sans `maxWidth` plus large, jamais déclenché
  (§ 2). Parade : scénario 21 aux bornes 719/720.
- **R3 – 20 scénarios dépendent du bouton retiré** : migration mécanique isolée
  (lot F) ; un échec après migration signale un vrai écart, pas du bruit.
- **R4 – marqueur et coût** : `SuggestSession` charge progrès et passages du
  groupe à chaque sélection ; calcul à la demande, annulé si le groupe change
  (`isClosed`/dernier appel gagne), échec = pas de marqueur et message
  `FailureMessage`, jamais de page d'erreur.
- **R5 – retour du guide** (soldé par U4, voir [guide-mener-plan.md](guide-mener-plan.md) § 6) : « Lancer » depuis Aujourd'hui envoie le guide
  (session planifiée) qui revient à Planifiées (`fromPlanner = sessionId !=
  null`) ; le guide perd aussi `from` et `group` (il ouvre la séance sans
  origine). Incohérent avec le nouveau « Préparer » ; **décision `[U-9]` : à
  traiter avec le guide (U4), hors lot, documenté seulement, rien codé.** → **Soldé par U4 (2026-10-16).**
- **R6 – provenance** : le titre de ligne est un `[Prop]`. Parade : note
  d'en-tête, détail inchangé, scénarios 3 à 5 ; relu par
  `relecteur-pedagogique`/`architecte-fsd`/`testeur-bdd` en contexte séparé.
- **R7 – presse-papiers** : refusé sur certains navigateurs hors geste
  utilisateur ; l'appel part d'un tap, repli d'affichage de l'identifiant.
- **R8 – tooltip tactile** : appui long seulement ; la même information est
  dans la sémantique et dans le détail (jamais l'unique voie).
- **R9 – largeur 1100 du détail** : lignes de texte longues. Parade :
  plafond de 760 dp pour le texte courant, deux colonnes seulement pour les
  cartes d'exercice.

## 10. Scénarios et tests existants impactés

**`session_catalogue.feature`** (réécriture ciblée) : « The menu leads to the 14
techniques… » (assertion `· read-only`) ; « The group suggestion stays one tap
away » (remplacé) ; « A session is read-only … » (assertion de la phrase) ;
« The outline jumps to the game and back » (texte « Game »/« Recall » →
frise) ; « The French interface shows no language notice » (`· lecture
seule`) ; « The filter keeps only the sessions to validate » et « Each session
says what is to validate … » (step `shows the review reason`, clé
`review:<id>:<motif>` remplacée par le badge unique) ; « A session opens from
the catalogue and leads back to it » (reste vert, vérifier la clé de retour).
**Autres features** : `proposal_blocks` (3), `screen_navigation` (2),
`suggested_session_screen` (14) pour `Group suggestion` ; `home.feature`
« Prepare from the home opens the catalogue session » et les scénarios qui
supposent le retour vers Planifiées ; `navigation.feature` (tabs) à revérifier.
**Steps** : `the_session_is_marked_to_validate*`, `…shows_the_review_reason`
(à remplacer ou adapter), `the_phase_is_on_screen` et `i_tap_the_phase`
(réutilisés). **Unitaires** : `sheet_catalogue_view_test`,
`sheet_catalogue_page_test`, `sheet_detail_view_test`,
`sheet_detail_page_test`, `sheet_catalogue_test`, `shell_routes_test`
(inchangé attendu), tests de `AppRoutes` (nouveau constructeur `sheet`),
`home_page_test` (`onPrepare`), `suggest_sheet` (filet), `needs_review`.
**Widgetbook / garde-fous** : cas d'usage `JourneyMarker` exigé par
`check_widgetbook` ; `check_l10n` (clés fr = en, aucun littéral) ; couverture
≥ seuil sur les fichiers ajoutés.

## 11. Définition de « terminé »

`scripts/check.sh --full` vert ; scénarios 1 à 27 présents et verts après avoir
été constatés rouges (le dire, et dire ceux non constatés) ; revue séparée
(`architecte-fsd`, `testeur-bdd`) ; aucun `TODO`, `skip`, stub ; `[U-1]` à
`[U-9]` tranchés ou leur défaut assumé par écrit dans la section
« Réalisation » de ce plan ; roadmap et ADR index à jour (pas d'ADR sauf `[U-5]`
avec dépendance : prochain numéro libre **0015**).

## 12. Réalisation (écarts au plan)

- **Décisions `[U-1]` à `[U-9]`** : U-1 **badge neutre rétabli** par motif
  mineur (décision de l'animateur ; la mention texte `minor-note` appliquée
  par défaut est supprimée, ainsi que son step) ; U-2 « n » = types de contenu
  (0 à 4) ; U-3 ligne fixe d'en-tête `catalogueNamesNote` ; U-4 ▶ sur la
  séance proposée même si tout est fait ; U-5 copie de l'identifiant
  seulement, **pas de courriel ni de dépendance** (donc pas d'ADR, courriel au
  lot 16, décision de l'animateur) ; U-6 groupe choisi = état d'écran,
  restauré par `?group=` ; U-7 « lecture seule » retiré ; U-8 frise non
  collante ; U-9 retour du guide inchangé, à traiter avec le guide (hors lot).
- **Libellé du sous-titre** : « Séance k/n · <titre de la technique> » (le titre
  réel, « Quantité demi-bille »), comme prévu en § 3.2.
- **Groupes du sélecteur** : cas d'usage `ListJourneyGroups` et
  `GroupJourneyCubit.load({initial})` ajoutés (non prévus au § 4) ; l'échec de
  chargement est gardé dans l'état et dit sous le sélecteur
  (`catalogue-journey-failure`), sans page d'erreur.
- **Retour du détail** : la page reçoit `backLabel` (calculé par le routeur),
  plus de booléen `fromPlanner`. « Préparer » d'« Aujourd'hui » utilise
  `SheetOrigin.today` (report U-12 d'U7 soldé).
- **Frise des phases** : `PhaseTimeline` réutilisée telle quelle (`currentIndex`
  -1) ; sa hauteur suit désormais l'échelle du texte (le débordement à 200 %
  est apparu en branchant la frise sur 320 dp).
- **Étape BDD `I tap the phase`** : amène le segment à l'écran et attend la fin
  du défilement animé (la frise est sous le pli à 800 × 600).
- **Scénarios** : 13 (catalogue vide, aucun ▶), 14 (groupe sans élève : séances
  faites cochées, aucune recommandée) et l'échec de lecture des groupes sont
  couverts en BDD (rouge vu par neutralisation temporaire des clés d'affichage),
  en plus des tests unitaires.
- **Largeur du détail** : page à 1100 dp ; les blocs de texte (`_Readable`) sont
  plafonnés à 760 dp, seules les cartes d'exercice profitent de la largeur
  (test de géométrie à 1280 dp).
- **Guide** : ~~« Lancer » ouvre le guide sans `from` ni `group`…~~ **U-9 soldé
  par U4** (2026-10-16) : le détail lance le guide avec `via` (son origine) et
  `group`, le guide revient au détail avec son origine et son groupe, et
  « Lancer » depuis Aujourd'hui revient à Aujourd'hui (`from=today`).
- **Double lecture du parcours** : `GetGroupJourney` lit les passages des
  séances du groupe, puis `SuggestNextSheet` (donc `SuggestSession`) relit
  séances et passages. La supprimer exigerait de changer la signature du cas
  d'usage partagé de la suggestion (règle `givenSheets`, ADR 0009) pour y
  injecter des données déjà lues : écarté, une seule sélection de groupe à la
  fois, données locales ; documenté plutôt que dupliqué.
- **`GroupChoice`** vit dans son propre fichier `shared/lib/group_choice.dart`.
- **Rouges** : badge mineur (rétabli) constaté rouge par neutralisation de la
  boucle des motifs mineurs ; frise à 200 % sur 320 dp, « sans groupe, aucun
  marqueur », précédence ▶ > ✓ et « notion sans séance » (scénario réel avec le
  catalogue de test privé de `posture-1`) constatés rouges par mutation
  temporaire, puis annulée.
- **Fichiers clés** : `shared/ui/journey_marker.dart`, `scroll_page.dart`
  (`maxWidth`, `actions`), `features/browse_sheets/presentation/ui/`
  (`sheet_catalogue_view.dart`, `review_labels.dart`, `sheet_detail_*`),
  `features/suggest_session/domain/list_journey_groups.dart`,
  `pages/sheet_catalogue`, `pages/sheet_detail`, `app/router.dart`.


### Parcours web du lot (agent précédent) et constats

Parcours fait sur un build web release de l'arbre non commité, à 390, 1280 et
320 dp, avec des données réelles (groupe enfants, deux élèves, posture-1 faite,
posture-2 planifiée) ; console du navigateur sans erreur ni avertissement ;
aucun défaut bloquant. Le texte à 200 % n'est pas testable depuis un navigateur
(couvert par le test de widget). Constats :

1. **Frise, segments étroits** : l'unité « min » est volontairement retirée
   sous 72 dp (`_minutesUnitWidth`, antérieur à U8) ; l'étiquette sémantique la
   porte. **Corrigé** : l'infobulle du segment disait « Notion · 15 » sans
   unité ; elle passe par `sessionDurationMinutes` (test
   `the tooltip of a segment carries the unit`, rouge constaté par mutation).
2. **Aucun groupe repris** : « Préparer » depuis Aujourd'hui ouvre le détail
   sans `group=`, et « Planifier cette séance » depuis le détail n'y reprend pas
   le groupe (le planificateur affiche « Aucun groupe »). Hors périmètre U8
   (§ 3 point 3 : seul le retour vers Aujourd'hui est demandé). **Soldé par U4** pour
   « Planifier cette séance » (`AppRoutes.plan(..., group)` présélectionne le
   groupe planifiable et son public l'emporte) ; **reste ouvert** : « Préparer »
   depuis Aujourd'hui, faute de marqueur de groupe sans groupe de catalogue.
3. **Aujourd'hui, séance du jour déjà saisie** : une saisie le jour J marque
   « faites » toutes les séances planifiées ce jour-là pour le groupe (ADR
   0007, comportement existant) ; Aujourd'hui peut alors annoncer « Aucune
   séance n'est planifiée » alors qu'une autre reste planifiée le même jour.
   Hors U8, consigné dans [aujourdhui-plan.md](aujourdhui-plan.md) § 12.
4. **Barre du bas à 320 dp** : « Aujourd'hui » se coupe en « Aujourd'h / ui ».
   Hors U8, consigné dans [aujourdhui-plan.md](aujourdhui-plan.md) § 12.
