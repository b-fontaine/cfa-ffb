# Roadmap

Rédigée le 2026-10-13 après un tour complet du dépôt (connaissances, ADR, plans,
application) et un test de l'application en web (Chrome, 1280 × 800 puis
390 × 844). Elle liste ce qui reste ouvert et ce qui manque, par horizon ; elle
ne remplace ni les ADR (décisions) ni les plans (exécution). Chaque lot livré
est retiré d'ici et consigné dans l'ADR ou le plan concerné.

## État de départ (2026-10-13)

- Connaissances : 5 PDF `[S]`, 14 fiches techniques, catalogue d'entraînement
  15 blocs / 70 exercices (72 avant le retrait de `bille-fantome-2` le 2026-10-15 ; dont 2 blocs `[Prop]`), 94 pages de diagrammes YAML,
  28 séances du catalogue (`fiches.dart --complete` vert, 29 avant le retrait de `bille-fantome-2` le 2026-10-15), environ 245 points
  `uncertainties`.
- Application : 9 entités, 10 features, 15 pages, 5 ADR, 197 scénarios BDD,
  drift v3, sauvegarde JSON, Widgetbook séparé ; `scripts/check.sh --fast`
  vert ; build web release en 40 s.
- Test web : parcours complet sans erreur console (élève → catalogue → détail →
  séance guidée → présentation → notation → retour au guide à la même étape →
  fiche élève avec courbe).

## Frictions constatées au test

| # | Constat | Où |
|---|---|---|
| F1 | En présentation, la légende du bas est tronquée à 1280 × 800 ; les commandes du lecteur sont coupées — traité par le lot **U3** | `pages/sheet_presentation` |
| F2 | ~~Diagramme bille fantôme : l'étiquette « Bille fantôme » chevauche la ligne de visée et la bille ; le cercle fantôme disparaît sous la pointe de flèche ; même défaut sur les repères numérotés (« 3 », « 5 » sous la trajectoire)~~ — corrigé par le lot **U2** (livré le 2026-10-15, voir [design-system.md](design-system.md#lisibilité-des-schémas-lot-u2-r5-corrige-f2)) ; **restes mesurés** : un schéma à 310 px et la présentation sous 900 px sur les schémas denses (« Limites connues ») | `shared/ui/ghost_aim_diagram`, `table_diagram` |
| F3 | Guide : l'en-tête (titre, public, thème, barre d'étape, minuteur, boutons) occupe ~45 % de l'écran desktop et ~60 % sur mobile ; le schéma d'exercice est sous la ligne de flottaison — traité par le lot **U4** | `pages/sheet_guide` |
| F4 | ~~Saisie : le sélecteur d'exercice est un bouton sans libellé accessible, au libellé tronqué sur mobile~~ — corrigé par le lot **U5** (livré le 2026-10-15, [plan](saisie-grille-plan.md)) | `pages/record_session` |
| F5 | ~~Onglet « Résultats » : aucun historique des séances saisies ; impossible de relire, corriger ou supprimer un passage~~ — corrigé (ADR 0006) | `pages/record_history` |
| F6 | ~~Séance planifiée sans date ni groupe, non liée à la saisie (décision 10 de l'ADR 0004, assumée mais visible)~~ — corrigé (ADR 0007) | `pages/session_planner` |
| F7 | ~~Séance suggérée : « Pas de rappel » pour les enfants (`recallCount = 0`, voulu) alors que la fiche élève affiche une notion à rappeler ; rien ne l'explique à l'écran~~ — corrigé (H0) : la carte « Rappel » explique, pour les enfants, qu'une séance porte une seule notion | `pages/suggested_session` |
| F8 | ~~Les seuils (`passesRequired`, alertes, `recallStaleSessions`) sont dans `RulesConfig.standard()` sans écran de réglages~~ — corrigé par le lot **9** (livré le 2026-10-15, [plan](reglages-plan.md), [ADR 0012](adr/0012-reglages-du-club.md)) : écran « Réglages » sous « Plus » | `app/di` |

## Lots UX / UI (audit du 2026-10-14)

L'[audit UX / UI](ux/audit-ux-ui.md) et ses
[recommandations](ux/recommandations-design.md) ramènent les frictions F1 à
F4 et une vingtaine de constats à trois causes : un seul mode d'affichage pour
préparer, mener et montrer ; des jetons de couleur où le rouge FFB joue le
rôle d'état ; aucun point d'entrée « maintenant ». Les lots **U1 à U9**
ci-dessous (détail, scénarios BDD et décisions tranchées `[U]` :
[ux/plan-ux-proposition.md](ux/plan-ux-proposition.md)) sont insérés dans les
horizons avec les lots numérotés ; ils suivent les mêmes règles (BDD puis TDD,
revues séparées, `check.sh --full`).

| Lot | Contenu | Remplace / corrige |
|---|---|---|
| **U3** Présentation plein écran | `DiagramStage` (table sur la plus grande dimension, légende réservée, contrôles en barre basse), plein écran natif, « tournez l'appareil » | F1, lot 13 |
| **U4** Guide en mode « Mener » | route hors shell, en-tête compact + frise des phases, schéma en premier, sections repliées, badges de provenance masqués sauf mode « Relecture », minuteur en en-tête, barre basse Précédent / Noter / Suivant | F3, lot 12 |
| **U6** Navigation recentrée | destinations « Aujourd'hui / Élèves / Résultats / Séances (Planifiées · Catalogue · Suggestion) / Plus (Sauvegarde, Réglages) » ; rappel de sauvegarde | F8 (emplacement du lot 9) |
| **U7** Accueil « Aujourd'hui » et bilan de fin de séance | séance en cours à reprendre, prochaine séance planifiée (Préparer / Lancer), alertes, semaine, sauvegarde ; à « Terminer », bilan des passages et proposition de la séance suivante | accueil statique |
| **U8** Catalogue et détail en mode « Préparer » | nom évocateur en titre, badge unique « n points à valider », marqueur de parcours par groupe, frise des phases dans le détail, deux colonnes | : |
| **U9** Fiche élève, vue élève et vue de groupe | parcours en cases (technique × exercice), en-tête en cours / prochain / alerte, courbes repliées, vue « à montrer à l'élève », heat-map technique × élève et assiduité du groupe | « 0 sur 70 », lot 10 (vues) |

## Audit des séances du 2026-10-15

Décisions `[U]` 7 à 9 (`docs/knowledge/08-lacunes-et-questions-ouvertes.md`).
Lots : **1** structure du catalogue (bille fantôme en une séance, 28 séances,
livré) ; **2** créneau d'exercice de rappel (ADR 0011, livré) ; **3** contenu
(attaque au centre, allègement de posture-1 et puissance-1, exercice 3 du
bloc posture, reformulations, gloses et notes animateur, une mécanique par
jeu), **livré** ; **4** schémas (personnage de posture, cran « légèrement
au-dessus », loupe de la bille fantôme, fantôme sur les flèches, flèches de
départ du contact), **livré**.

Reste ouvert :

- gloses et notes animateur : les séparer **formellement** du contenu des
  sections (décision à prendre) ;
- fusion de `mot-fantome` (décision à prendre) ;
- figure du gaucher en séance 1 ;
- périmètre « fantôme sur les flèches » : séances 02 à 04 seulement ;
- règle d'enregistrement du bloc de rappel (bloc principal et bloc de rappel
  de la saisie), écrite dans `pages/sheet_guide`, à déplacer vers
  `features/run_sheet/domain` (par exemple un getter pur testé en TDD) ; en
  attente de la fin du lot U5, qui touche la même page.

## H0 — Clore ce qui est ouvert

1. ~~Lot L8 « finition » de l'ADR 0004 : `check.sh --fast` en `--complete`,
   docs (`progression-par-cycles.md`, glossaire).~~ Livré (le garde-fou
   exécutait déjà `fiches.dart --complete`). L'accessibilité (F4) et la tablette paysage (F3) passent aux lots U5 et U4.
2. ~~Revue T8 du plan tailles et illustrations~~ : **faite le 2026-10-15**
   (`architecte-fsd`, `testeur-bdd`, `relecteur-pedagogique`, contextes
   séparés ; `check.sh --full` vert, couverture lignes 98,5 %). Aucun
   bloquant. Constats corrigés : ADR 0005 amendé (D5 réalisée),
   `architecture.md` (ADR 0011, 70 exercices), README du catalogue (18
   séances « à valider » sur 28). Constats **ouverts** :
   - architecture : règle du bloc de rappel de la saisie dans
     `pages/sheet_guide` (voir l'audit des séances) ; `chooseRecallExercise`
     ne filtre pas sur le public (sans effet aujourd'hui : les 28 fiches
     pèsent les deux publics ; à trancher dans l'ADR 0011 ou à filtrer) ;
   - tests : V28 (poids 0, bornes de `passes`, `order` 1 et 2 en positif),
     rejets du parseur de `recall_slot`, `student_pass_row.dart` (11 lignes
     non couvertes) ;
   - contenu `[Prop]` : `amplitude-vitesse` sous une section `[S]` en
     `coule-1`, `hauteur-contact` vu des enfants en `bille-pleine-1`, règles
     facultatives empilées en `retro-1` et `retro-4`, `taille-billes` montré
     aux enfants en `bille-fantome-1`, contradiction texte `[S]` / légende
     en `rebond-bande-1`.
3. ~~Corriger F7 (un texte « pas de rappel : une notion par séance enfants »).~~
   Livré. F1 est absorbé par U3 pour ne pas corriger deux fois ; F2 est corrigé par
   U2 (livré).
4. ~~Faire trancher par l'animateur~~ — **tranché le 2026-10-14** : D5 =
   **ajouter** l'illustration `contact_height` ; questions 2 à 4 de
   `docs/knowledge/08-lacunes-et-questions-ouvertes.md` (unité « séance »,
   dimensionnement groupes / saison, synchronisation) : recommandations de
   l'assistant suivies, à consigner dans ce fichier. D5 est **réalisé**
   (`contact_height`, `tailles-et-illustrations-plan.md` § 3.4). D2 (ligne de départ à 1,6 `[FFB]`)
   est **réalisée** : les positions YAML, absolues, sont inchangées.
   Les questions Q1 à Q8 du plan UX sont **tranchées** `[U]` le 2026-10-14
   (toutes dans le sens recommandé : voir
   [ux/plan-ux-proposition.md § 6](ux/plan-ux-proposition.md)).

Lots UX en H0 :

- ~~**U1** Fondations du design system~~ : **livré le 2026-10-14**,
  [ADR 0010](adr/0010-roles-de-couleur-bleu-tapis-et-accent.md) (bleu-tapis
  en `secondary`, `BrandColors`, `SectionCard.emphasis`, logo derrière
  `showFfbLogo`, icônes de navigation, `PassDots`, `TimerChip`,
  `PhaseTimeline`, `StepAppBar`, feuille Widgetbook « Rôles de couleur »).
  Reporté hors U1 : bille n° 8 et motif de tapis (U7, U3), `NowCard` (U7),
  `DiagramStage` (U3) ; `StudentChip` a été livré avec U5.
  Les écrans touchés par les lots 7 et 8 (fiche élève, séance suggérée) seront
  repris par U9 et U8.

## H1 — La boucle de saison complète (priorité)

5. ~~Historique des séances saisies~~ (F5) : **livré le 2026-10-14** —
   [ADR 0006](adr/0006-historique-et-correction-des-passages.md),
   [plan](historique-seances-plan.md). Reste l'assiduité **du groupe** (lot 10).
6. ~~Lier séance planifiée ↔ saisie ↔ séance du catalogue~~ (F6, lot L9 de
   l'ADR 0004) : **livré le 2026-10-14** —
   [ADR 0007](adr/0007-lien-seance-planifiee-saisie-catalogue.md),
   [plan](seance-planifiee-plan.md). Date et groupe sur la séance planifiée,
   « Noter les résultats » pré-rempli depuis le guide comme depuis la liste,
   la saisie et l'historique nomment la séance du catalogue. La liste expose
   déjà date, groupe et « Résultats saisis » : ce sont les données du lot U7.
   - ~~**U5** Saisie rapide en grille~~ : **livré le 2026-10-15**,
     [plan](saisie-grille-plan.md). Une ligne par élève avec `PassDots`,
     sélecteur d'exercice nommé et non tronqué, liste compacte sous 600 dp,
     historique groupé par élève, saisie en feuille basse depuis le guide.
   - ~~**U6** Navigation recentrée~~ : **livré le 2026-10-15**,
     [plan](navigation-plan.md) (cinq destinations, « Séances » à onglets,
     « Plus » → Sauvegarde, rappel de sauvegarde sur « Aujourd'hui » après 30
     jours ou des passages saisis ; schéma drift v6). L'entrée « Réglages »
     est livrée par le lot 9 ; « À propos et sources » reste reporté faute de
     contenu (aucune entrée sans écran).
7. ~~Positionnement initial / bloc acquis~~ : marquer un bloc comme acquis sans
   passage (élèves non débutants, rentrée) ; sinon la suggestion repart de
   « posture » et la fiche affiche « 0 / 70 » toute la saison. **Livré le
   2026-10-14** — [ADR 0008](adr/0008-positionnement-initial-bloc-acquis.md),
   [plan](positionnement-initial-plan.md). Décisions : action sur la fiche élève
   par bloc, état distinct stocké (date + source « positionnement », pas de
   passage fictif), bloc entier (15 blocs), compté dans « n / 70 » et saute
   l'ordre de suggestion (libellé « acquis au positionnement », ordre rebond
   puis rejet inchangé), réversible, un passage daté du même jour ou après
   reprend la main sur son exercice seulement (le reste du bloc reste acquis).
8. ~~Suggestion ↔ catalogue~~ : la séance suggérée propose la séance du
   catalogue correspondante (partie suivante non faite par le groupe).
   **Livré le 2026-10-14** — [ADR 0009](adr/0009-suggestion-seance-du-catalogue.md),
   [plan](suggestion-catalogue-plan.md). Décisions : l'exercice de tête décide
   (S1), « faite » = saisie avec séance et passage (S2, S7), notion sans séance
   = repli explicite (S8), guide lancé avec le groupe (S6) ; aucune migration.
   Actions livrées : « Ouvrir », « Lancer la séance guidée », « Saisir les
   résultats » pré-rempli et « Planifier » (ouvre le planificateur ; la
   création directe d'une séance planifiée datée pour le groupe revient à U7,
   bilan de fin de séance).
   - ~~**U6** Navigation recentrée~~ : livré (voir plus haut) ; le lot 9
     a pris place sous « Plus ».
9. ~~**Réglages** (F8)~~ : **livré le 2026-10-15** — [ADR 0012](adr/0012-reglages-du-club.md),
   [plan](reglages-plan.md). Écran persisté (drift v7 + sauvegarde JSON v2)
   pour `passesRequired`, seuil d'alerte, `recallStaleSessions`, part d'échec
   du groupe et délai du rappel de sauvegarde ; sous « Plus » (`/settings`),
   pas de sixième onglet ; « Rétablir les valeurs par défaut » avec
   confirmation ; les règles lisent la valeur courante (`RulesStore`).
   - **U7** Accueil « Aujourd'hui » et bilan de fin de séance, ensuite.
     Dépend de U6 ; les lots 6 et 8 dont il affiche les données sont livrés
     (séance datée, séance suivante proposée dans le bilan).
10. Reste de l'ADR 0003 : acquittement d'une alerte, note de jeu de la séance,
    vues de groupe (carte de chaleur bloc × élève, assiduité), compteurs
    d'initiation et de jeu persistés. **Livré avec U9** (fiche élève en
    parcours, vue « à montrer à l'élève », vue de groupe) ; les cases
    « acquis » s'appuient sur le lot 7 (livré, ADR 0008).
    - **U8** Catalogue et détail en mode « Préparer », avec U9 : le lot 8 est
      livré, le marqueur de parcours par groupe a ses données.
11. **Saisons et groupes** : clôture de saison (archiver, effacer les mineurs en
    lot), plusieurs groupes par public, déplacer un élève de groupe.

## H2 — Usage en salle

12. ~~Guide : en-tête repliable ou compact en séance (F3), schéma en premier,
    deux colonnes en tablette paysage.~~ **Remplacé par U4** (même intention,
    périmètre élargi à la cause : mode « Mener » dédié).
13. ~~Présentation : l'étape complète (consigne + schéma) en plein écran, zoom
    sur le diagramme, légende jamais tronquée (F1).~~ **Remplacé par U3.**
14. Impression / export PDF d'une séance du catalogue (feuille de l'animateur,
    fiche résultats papier identique au PDF fédéral) ; s'appuie sur `PassDots`
    (U1) pour la fiche résultats.
15. Hors-ligne : vérifier le PWA (service worker, sqlite3.wasm / OPFS) sans
    réseau ; installation sur l'écran d'accueil ; le plein écran (U3) et le
    mode immersif (U4) sont à tester en PWA installée.

## H3 — Contenu et connaissances

16. Workflow de validation des `[Prop]` : 18 séances sur 28 « à valider »
    (jeu, exercice, initiation ou rappel `[Prop]`, § 5.3 de `FORMAT.md`),
    11 jeux adaptés ; marque « relu » persistante (point ouvert n° 1 du plan
    catalogue) ou export des remarques de l'animateur vers le YAML. S'appuie
    sur le mode « Relecture » (U4) et le badge unique du catalogue (U8, en
    H1 puisque le lot 8 est livré).
17. Validation des diagrammes par l'animateur (lecture ≈ 0,15 case, jamais
    contrôlée) : mode « comparer au PDF page N ».
18. Ingérer les règles officielles du Blackball (FFB / WPA) et le contenu du
    billard de bronze.
19. Compléments `[Prop]` à sourcer : échauffement, sécurité, matériel enfant,
    les six techniques sans jeu `[S]`.
20. Niveaux techniques 2 et 3 : en attente des PDF.

## H4 — Technique et distribution

21. Déploiement web depuis la CI : fait (`firebase-hosting-merge.yml` publie
    `main` sur Firebase Hosting, `firebase-hosting-pull-request.yml` ouvre un
    canal de prévisualisation par PR, même recette de build que `ci.yml`) ;
    reste le build Android signé (plateforme prioritaire).
22. Synchronisation multi-appareils (Firebase derrière les repositories, ADR
    0001) seulement si la question ouverte n° 4 est tranchée « oui » ; sinon
    rappel périodique de sauvegarde et export en fin de séance, plus deux
    rappels natifs sobres et désactivables : veille d'une séance planifiée
    (« Préparer la séance de demain ») et sauvegarde de plus de 30 jours.
23. Dette : `scripts/` sans `pubspec.yaml`, build `--wasm`, mutation testing
    retiré (à réévaluer).

## Ordre recommandé

```
H0 : ~~F7~~ → ~~revue T8~~ (faite, constats ouverts ci-dessus) → ~~réaliser D5~~ réalisé (les questions ouvertes sont tranchées ; U2 livré)
H1 : ~~U5~~ → ~~U6~~ → 9 → U7 → 10 + U9 + U8 → 11   (5 à 8 livrés)
H2 : U4 → U3 → 14 → 15
H3 : 16 (avec le mode Relecture de U4) → 17 → 18 → 19 → 20
H4 : 21 → 22 (+ rappels) → 23
```

U1 (livré) a posé les fondations dont tout dépend ; U5 tôt
parce que la saisie est l'action quotidienne et que le lot 6 (livré) lui
fournit groupe, date et séance du catalogue ; les lots 7 et 8 sont livrés
(ADR 0008 et 0009), U7 a donc déjà toutes les données qu'il affiche et U8
son marqueur de parcours ; U4 et U3 avant la première séance réelle en
salle.
