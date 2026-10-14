# Lots UX / UI : détail, scénarios et décisions

Statut : **intégré à [roadmap.md](../roadmap.md)** le 2026-10-14 (section
« Lots UX / UI », insertion dans les horizons, ordre recommandé révisé), après
la livraison des lots 5 (ADR 0006) et 6 (ADR 0007). La roadmap fait foi pour
l'ordre ; ce document garde le détail de chaque lot, les scénarios BDD à
écrire d'abord et les décisions tranchées par l'animateur (§ 6, validées le
2026-10-14). Les lots existants gardent
leur numéro ; les lots UX sont numérotés **U1 à U9**. Fondements :
[audit-ux-ui.md](audit-ux-ui.md) et
[recommandations-design.md](recommandations-design.md). Chaque lot livré
donne lieu à son plan d'exécution et à son ADR, puis est retiré de la roadmap.

## 1. Ce que la roadmap actuelle ne couvre pas

La roadmap traite l'interface par frictions ponctuelles (F1 à F8) et par
lots fonctionnels. Trois besoins restent sans lot :

1. **Un point d'entrée vivant** (« Aujourd'hui ») : l'application n'a pas de
   raison d'être ouverte en dehors d'une action déjà décidée.
2. **Un mode « en salle »** cohérent (guide, présentation, saisie) : les
   frictions F1, F3, F4 sont des symptômes d'une seule cause, l'absence de
   mode dédié ; les corriger une à une laissera la cause.
3. **Une base de design system saine** (rôles de couleur, hiérarchie de
   surfaces, identité sans logo) : chaque nouvel écran hérite aujourd'hui des
   roses d'état et du logo non autorisé.

## 2. Lots proposés

| Lot | Contenu | Recommandations | Effort | Dépend de |
|---|---|---|---|---|
| **U1** Fondations du design system (**livré le 2026-10-14**) | ADR 0010 (0008 et 0009 sont prises par les lots 7 et 8) ; rôles de couleur (bleu-tapis en `secondary`, `BrandColors`) ; `SectionCard.emphasis` ; retrait du logo derrière un drapeau ; icônes de navigation ; `PassDots`, `TimerChip`, `PhaseTimeline`, `StepAppBar` avec tests, use cases et feuille Widgetbook « Rôles de couleur » | R1, R2, R3 (partiel), R4 (partiel) ; voir « Hors U1 » en § 4 | M | : |
| **U2** Lisibilité des schémas | annotations hors trajectoire, halo, queue non coupée, repères à la taille de la blanche, médaillon `inset`, étiquettes ≥ 16 px en présentation ; corrige F2 | R5 | M | : |
| **U3** Présentation plein écran | `DiagramStage`, plein écran natif, bandeau de légende réservé, flèches latérales, bandeau « tournez l'appareil » ; corrige F1 et le lot 13 | R10 | M | U1, U2 |
| **U4** Guide en mode « Mener » | route hors shell, `StepAppBar` + `PhaseTimeline`, schéma en premier, sections repliées, badges masqués sauf « Relecture », minuteur en en-tête, barre basse à trois actions ; corrige F3 et le lot 12 | R7, R9 | L | U1 |
| **U5** Saisie rapide en grille | grille élève × passage avec `PassDots` et `StudentChip`, sélecteur d'exercice nommé et non tronqué, liste compacte sur téléphone, historique groupé, feuille basse depuis le guide ; corrige F4 | R11 | L | U1 |
| **U6** Navigation recentrée | destinations « Aujourd'hui / Élèves / Résultats / Séances (onglets) / Plus » ; réglages (F8) sous « Plus » ; rappel de sauvegarde | R6, R12 (onglets) | M | U1 |
| **U7** Accueil « Aujourd'hui » et bilan de fin de séance | `NowCard`, séance en cours, prochaine séance, alertes, semaine, sauvegarde ; écran de bilan à « Terminer » avec proposition de la séance suivante | R8, § 4.4 | L | U6, lots 6 et 8 (livrés : date, groupe, « Résultats saisis », séance suivante) |
| **U8** Catalogue et détail en mode « Préparer » | hiérarchie des lignes, badge unique de relecture, marqueur de parcours par groupe, `PhaseTimeline` dans le détail, deux colonnes | R12, R13 | M | U1, lot 8 (livré : marqueur) |
| **U9** Fiche élève, vue élève et vue de groupe | parcours en cases, en-tête « en cours / prochain / alerte », courbes repliées, vue « à montrer à l'élève », heat-map de groupe et assiduité | R14, R15 | M | U1, lot 7 (livré), lot 10 |

Reporté depuis U1 : bille n° 8 et motif de tapis (U7, U3), `StudentChip` (U5),
`NowCard` (U7), `DiagramStage` (U3).

Chaque lot suit `dev-feature` : scénarios `.feature` d'abord (voir § 4),
puis TDD, revue `architecte-fsd` + `testeur-bdd` dans un contexte séparé,
`scripts/check.sh --full` vert, `design-system.md` et `guide-animateur.md`
mis à jour.

## 3. Insertion dans les horizons

### H0 — Clore ce qui est ouvert

- Le point 3 (« corriger F1, F2 et F7 ») devient : **F7** seul en H0 (texte
  « pas de rappel : une notion par séance enfants ») ; **F1** et **F2** sont
  absorbés par U3 et U2, pour ne pas corriger deux fois.
- Le lot L8 « finition » garde la partie documentation ; la partie
  accessibilité (F4) et tablette paysage (F3) passent dans U5 et U4.
- **Ajout U1** en H0 : c'est un prérequis de tout nouvel écran et il n'a
  aucune dépendance fonctionnelle. Le faire avant les lots 6 et 7 évite de
  livrer la séance planifiée datée et le positionnement initial avec les
  anciens jetons, puis de les reprendre.
- **Ajout U2** en H0 : correction de lisibilité des schémas, courte, sans
  dépendance ; elle sert la précision pédagogique, qui est le cœur du projet.

### H1 — La boucle de saison complète

- Les lots 5 à 8 sont **livrés** (ADR 0006 à 0009) ; les lots 9, 10, 11
  restent, dans le même ordre. Les lots 7 et 8 ont été livrés avant U1 : la
  fiche élève (bloc acquis) et la séance suggérée (séance du catalogue
  proposée) seront reprises avec le design system par U9 et U8.
- Le lot 6 fournit déjà ce que U7 consomme : séances planifiées triées par
  date, groupe, lien dérivé « Résultats saisis » (`PlannedSessionSummary`).
  U7 n'a plus qu'à exposer « prochaine » et « en cours » (`RunSheetSessions`).
- Le lot 9 (réglages) est livré **sous la destination « Plus »** (U6) plutôt
  que comme sixième onglet ; U6 est donc placé avant le lot 9.
- **Ajout U5** en tête de H1 : la saisie est l'action la plus fréquente de la
  saison ; sa grille rend le lien séance ↔ saisie (lot 6) utilisable en salle.
- **Ajout U7** après le lot 9 : l'accueil « Aujourd'hui » n'a de sens qu'avec
  une séance datée et une suggestion reliée au catalogue, toutes deux livrées
  (lots 6 et 8).
- **Ajout U9** avec le lot 10 (vues de groupe, acquittement) ; le lot 7
  (positionnement initial, livré) lui fournit les cases « acquis ».
- **Ajout U8** avec U9 : le lot 8 (livré) fournit le marqueur de parcours.

### H2 — Usage en salle

- Les lots 12 et 13 sont **remplacés** par U4 et U3 (même intention,
  périmètre élargi à la cause).
- Le lot 14 (impression / PDF) reste ; il profite de `PassDots` (fiche
  résultats papier identique à la fédérale).
- Le lot 15 (hors-ligne / PWA) reste ; U3 (plein écran natif) et U4 (mode
  immersif) doivent être testés en PWA installée.

### H3 — Contenu et connaissances

- Le lot 16 (workflow de validation des `[Prop]`) s'appuie sur le commutateur
  « Relecture » de U4 et le badge unique de U8 : la relecture devient un mode
  explicite, ce qui rend possible une marque « relu » persistante.
- Le lot 17 (validation des diagrammes « comparer au PDF ») profite de U2.

### H4 — Technique et distribution

- Ajouter aux rappels périodiques (lot 22) les deux rappels sobres de
  [recommandations § 4](recommandations-design.md#4-envie-de-revenir) :
  veille de séance planifiée et sauvegarde ancienne.

## 4. Critères d'acceptation et scénarios BDD par lot

Les scénarios ci-dessous sont des titres de `.feature` à écrire avant tout
code ; les existants (`session_guide.feature`, `record_results.feature`,
`navigation.feature`, `student_sheet.feature`, `design_system.feature`) sont
adaptés plutôt que dupliqués.

**U1** (livré le 2026-10-14, [ADR 0010](../adr/0010-roles-de-couleur-bleu-tapis-et-accent.md))

- `design_system.feature` : « Les états sélectionnés de la navigation, des
  puces et des segments utilisent le conteneur bleu-tapis, dans les deux
  thèmes » ; « La piste d'une barre de progression n'est jamais rouge » ;
  « Le logo FFB n'est pas affiché quand le thème ne porte pas de ressource de
  marque » ; « Une pastille de `PassDots` tapée bascule et le texte x/n suit ».
- `contrast_test.dart` étendu à `BrandColors`.

*Hors U1 / reporté* (livré en partie : R3 et R4 ne sont pas complets) :

- R3, signe de l'application en bille n° 8 (icône d'application, en-tête de
  l'accueil, état vide) : **U7** (accueil, état vide).
- R3, motif de tapis (`BallColors.cloth` à 6 %, grille 8 × 4) : **U7** (en-tête
  de l'accueil) et **U3** (mode présentation).
- R4, `StudentChip` : **U5** (grille de saisie) ; `NowCard` : **U7** ;
  `DiagramStage` : **U3**.

**U2**

- `exercise_diagram.feature` : « Aucune étiquette de repère ne recouvre une
  trajectoire sur le schéma des six repères » (test géométrique sur les
  rectangles d'étiquettes et les segments) ; « La queue reste dans la table » ;
  « En présentation, les étiquettes mesurent au moins 16 px ».

**U3**

- `session_guide.feature` (présentation) : « La légende est visible sans
  défilement à 1 280 × 800 et à 390 × 844 » ; « Les commandes du lecteur sont
  entièrement visibles » ; « En paysage, la table occupe au moins 80 % de la
  hauteur disponible » ; « Fermer revient à la même étape ».

**U4**

- `session_guide.feature` : « Le schéma d'une étape exercice est visible sans
  défilement à 390 × 844 » ; « La barre de navigation principale n'est pas
  affichée pendant la séance » ; « Les badges de provenance sont masqués en
  mode Mener et affichés en mode Relecture » ; « Le guide lancé depuis le
  détail sans séance planifiée s'ouvre en mode Relecture » ; « Le minuteur
  change de ton à moins d'une minute et au dépassement » ; « Terminer est
  confirmé » ; tous les scénarios existants de reprise, sommaire, retour à la
  même étape restent verts.

**U5**

- `record_results.feature` : « Le sélecteur d'exercice porte un nom
  accessible et son libellé n'est pas tronqué à 390 dp » ; « Dix élèves
  présents tiennent sur un écran de 844 dp » ; « Taper quatre pastilles sur
  six puis Saisir enregistre 4 sur 6 et marque la ligne réussie » ; « Un
  troisième passage est refusé avec le message existant » ; « Depuis le
  guide, la feuille de saisie s'ouvre sur l'exercice courant et le guide reste
  à la même étape » ; les scénarios de correction et de suppression (ADR
  0006) restent verts.

**U6**

- `navigation.feature` : « Les cinq destinations sont Aujourd'hui, Élèves,
  Résultats, Séances, Plus » ; « Séances propose Planifiées, Catalogue,
  Suggestion » ; « Plus contient Sauvegarde et Réglages » ; « Un bandeau
  rappelle la sauvegarde après 30 jours ou après des passages saisis ».

**U7**

- `home.feature` (nouveau) : « Sans séance planifiée, l'accueil propose de
  planifier ou de voir la suggestion » ; « Avec une séance commencée, l'accueil
  propose Reprendre à l'étape en cours » ; « La prochaine séance datée est
  affichée avec Préparer et Lancer » ; « Une alerte active d'un élève est
  listée » ; « Terminer la séance affiche le bilan avec les passages saisis et
  propose la séance suivante ».

**U8**

- `session_catalogue.feature` : « Le titre d'une ligne est le nom évocateur de
  la séance » ; « Une séance à valider porte un seul badge avec le nombre de
  points » ; « Avec un groupe choisi, la prochaine séance recommandée est
  marquée » ; « Le sommaire du détail est une frise des phases ».

**U9**

- `student_sheet.feature` : « Le parcours affiche une ligne par technique et
  une case par exercice » ; « Un bloc acquis au positionnement initial est
  plein » ; « Une alerte peut être acquittée » ; « La vue à montrer à l'élève
  n'affiche ni alerte ni note d'animateur » ; `students.feature` : « La vue de
  groupe affiche technique × élève et l'assiduité ».

## 5. Ordre recommandé (révisé)

```
H0 : U1 → U2 → F7 → revue T8 → questions ouvertes (D2, D5, unité « séance »)
H1 : U5 → 7 → 8 → U6 → 9 → U7 → 10 + U9 → 11
H2 : U4 → U3 → 14 → 15
H3 : 16 (avec Relecture de U4) → U8 → 17 → 18 → 19 → 20
H4 : 21 → 22 (+ rappels) → 23
```

Justification : U1 d'abord parce que tout en dépend et qu'il n'a pas de
dépendance ; U5 tôt parce que la saisie est l'action quotidienne et que le
lot 6, livré, lui fournit groupe, date et séance du catalogue ; U4 et U3
avant la première séance réelle en salle, comme la roadmap le demandait déjà
pour 12 et 13 ; U7 quand les données qu'il affiche existent.

## 6. Décisions tranchées par l'animateur `[U]` (2026-10-14)

Les huit recommandations ci-dessous ont été **validées telles quelles**. Elles
s'imposent aux lots U1 à U9 ; toute remise en cause passe par un ADR.

| # | Question | Décision `[U]` |
|---|---|---|
| Q1 | Bleu-tapis pour les états et rouge en accent (ADR 0010) ? | **oui** |
| Q2 | Retirer le logo FFB tant que l'autorisation n'est pas écrite ? | **oui**, derrière un drapeau de thème |
| Q3 | Destination « Plus » (sauvegarde + réglages) à la place de « Sauvegarde » ? | **oui** |
| Q4 | Mode « Relecture » par défaut quand le guide est lancé sans séance planifiée ? | **oui** |
| Q5 | Saisie en pastilles (une par essai) plutôt qu'au compteur ? | **oui**, le compteur reste pour « tentatives » |
| Q6 | Vue « à montrer à l'élève » : prénom et parcours seulement ? | **oui** |
| Q7 | Rappels natifs (veille de séance, sauvegarde) en H4 ? | **oui**, désactivables |
| Q8 | Nom de la destination d'accueil ? | **« Aujourd'hui »** |
