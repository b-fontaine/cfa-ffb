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
| F1 | ~~En présentation, la légende du bas est tronquée à 1280 × 800 ; les commandes du lecteur sont coupées~~ — corrigé par le lot **U3** (**livré le 2026-10-16**, [plan](presentation-plan.md), [ADR 0017](adr/0017-plein-ecran-port-controleur-partage.md) ; légende entière et barre basse visibles à 1280 × 800, 900 × 600 et 390 × 844, mesuré au navigateur) ; **reste** : en paysage sur téléphone (844 × 390) la scène défile pour atteindre les commandes et la légende | `pages/sheet_presentation` |
| F2 | ~~Diagramme bille fantôme : l'étiquette « Bille fantôme » chevauche la ligne de visée et la bille ; le cercle fantôme disparaît sous la pointe de flèche ; même défaut sur les repères numérotés (« 3 », « 5 » sous la trajectoire)~~ — corrigé par le lot **U2** (livré le 2026-10-15, voir [design-system.md](design-system.md#lisibilité-des-schémas-lot-u2-r5-corrige-f2)) ; **restes mesurés** : un schéma à 310 px et la présentation sous 900 px sur les schémas denses (« Limites connues ») | `shared/ui/ghost_aim_diagram`, `table_diagram` |
| F3 | Guide : l'en-tête (titre, public, thème, barre d'étape, minuteur, boutons) occupe ~45 % de l'écran desktop et ~60 % sur mobile ; le schéma d'exercice est sous la ligne de flottaison — traité par le lot **U4** (**livré le 2026-10-16**, [plan](guide-mener-plan.md), [ADR 0015](adr/0015-guide-mener-route-modes-origine.md) ; en-tête compact de ~160 dp, schéma mesuré visible sans défiler à 390 × 844 et 1280 × 800 ; parcours web fait, voir [plan § 18](guide-mener-plan.md)) | `pages/sheet_guide` |
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
| **U3** Présentation plein écran : **livré le 2026-10-16, parcours web fait** ([plan](presentation-plan.md), [ADR 0017](adr/0017-plein-ecran-port-controleur-partage.md)) | `DiagramStage` (légende réservée, schéma sur le reste, mode compact, défilement sous le minimum), port `FullscreenController` (web `dart:js_interop`, mobile immersif), bouton « Plein écran » (présentation) et entrée du menu ⋮ du guide, touche `F`, « Tournez l'appareil », motif de tapis derrière la scène ; **reste** : iPhone Safari (pas d'API, entrée masquée) ; le plein écran a été vérifié hors ligne dans Chromium au lot 15 ([plan](hors-ligne-plan.md)) ; PWA installée sur Android et Android natif non vérifiés (dont la sortie du mode immersif décidée par le système, à suivre par `SystemChrome.setSystemUIChangeCallback`) | F1, lot 13 |
| **U4** Guide en mode « Mener » : **livré le 2026-10-16, parcours web fait** ([plan](guide-mener-plan.md), [ADR 0015](adr/0015-guide-mener-route-modes-origine.md)) | route hors shell, en-tête compact + frise des phases, schéma en premier, sections repliées, badges de provenance masqués sauf mode « Relecture » (provenance toujours annoncée aux lecteurs d'écran), minuteur en en-tête (temps restant, ton, vibration), barre basse Précédent / Noter / Suivant, « Terminer » confirmé ; solde U-9 (retour à l'origine, groupe conservé) ; **plein écran natif reporté à U3** (livré), hors ligne vérifié au lot 15 | F3, lot 12, U-9 |
| **U6** Navigation recentrée | destinations « Aujourd'hui / Élèves / Résultats / Séances (Planifiées · Catalogue · Suggestion) / Plus (Sauvegarde, Réglages) » ; rappel de sauvegarde | F8 (emplacement du lot 9) |
| ~~**U7**~~ Accueil « Aujourd'hui » et bilan de fin de séance : **livré le 2026-10-15** ([plan](aujourdhui-plan.md)) | séance en cours à reprendre, prochaine séance planifiée (Préparer / Lancer), alertes, semaine, sauvegarde ; à « Terminer », bilan des passages et proposition de la séance suivante | accueil statique |
| ~~**U8**~~ Catalogue et détail en mode « Préparer » : **livré le 2026-10-16** ([plan](catalogue-preparer-plan.md)) | nom évocateur en titre, badge « n points à valider » (motifs majeurs en infobulle et dans le détail) + un badge neutre par proposition mineure (U-1), marqueur de parcours par groupe (✓ / ▶ / ○), frise des phases tapable dans le détail, carte d'exercice à deux colonnes dès 720 dp, menu ⋮ « Signaler une proposition », origine « Aujourd'hui » du détail ; le bouton « Suggestion par groupe » est retiré (audit C1 à C5, D1 à D4) | catalogue d'étiquettes, « Aller à », report U-12 d'U7 |
| ~~**U9**~~ Fiche élève, vue élève et vue de groupe : **livré le 2026-10-16** ([plan](fiche-eleve-plan.md), [ADR 0013](adr/0013-acquittement-des-alertes.md), [ADR 0014](adr/0014-fiche-en-parcours-vue-eleve-et-vue-de-groupe.md)) | parcours en cases (technique × exercice), en-tête en cours / prochain / alerte, courbes repliées, vue « à montrer à l'élève », carte de chaleur technique × élève, assiduité et alertes de groupe, acquittement d'une alerte ; le lot **10b** (séance en cours persistée) est **livré le 2026-10-17**, seule la note de jeu reste reportée (voir le point 10) | « 0 sur 70 », lot 10a (vues) |

## Correctif D1 : identité d'une saisie (2026-10-16)

**Livré** ([plan](lien-saisie-planifiee-plan.md), [ADR 0016](adr/0016-identite-de-la-saisie-par-groupe-jour-et-seance.md)) :
une saisie est identifiée par (groupe, jour, séance du catalogue), règle pure
`recordFor` partagée par `ListSessions` et `OpenOrResumeSession`. Aucune
migration, sauvegarde inchangée (format 3). Les saisies dont la séance avait
été réécrite avant le correctif ne sont pas récupérables.

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
- ~~règle d'enregistrement du bloc de rappel~~ : **déplacée le 2026-10-16**
  dans `features/run_sheet/domain` (`RunPlan.recordBlocksFor`, testée en
  unitaire) ; `pages/sheet_guide` ne fait plus qu'appeler la règle.

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
   - ~~architecture : règle du bloc de rappel de la saisie dans
     `pages/sheet_guide`~~ → `RunPlan.recordBlocksFor` (2026-10-16) ;
     ~~`chooseRecallExercise` ne filtre pas sur le public~~ → filtre
     `weight.isShownFor(audience)` ajouté (commit 3508d2e), décision consignée
     dans l'ADR 0011 ;
   - ~~tests : V28 (poids 0, bornes de `passes`, `order` 1 et 2 en positif),
     rejets du parseur de `recall_slot`, `student_pass_row.dart`~~ : faits
     (V28 et parseur en 3508d2e, complétés le 2026-10-16 ; `student_pass_row`
     : ligne compacte avec passages saisis, limite atteinte, exercice suivant) ;
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
  Reporté hors U1 : ~~bille n° 8 et motif de tapis (U7)~~ et ~~`NowCard`
  (U7)~~ livrés avec U7 (le motif de tapis est réutilisé par U3),
  ~~`DiagramStage` (U3)~~ livré avec U3 ; `StudentChip` a été livré avec U5.
  Les écrans touchés par les lots 7 et 8 : fiche élève reprise par U9
  (**livré**), séance suggérée par U8.

## H1 — La boucle de saison complète (priorité)

5. ~~Historique des séances saisies~~ (F5) : **livré le 2026-10-14** —
   [ADR 0006](adr/0006-historique-et-correction-des-passages.md),
   [plan](historique-seances-plan.md). ~~Reste l'assiduité **du groupe**~~ :
   **soldée avec U9** (vue de groupe).
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
   résultats » pré-rempli et « Planifier » (ouvre le planificateur).
   ~~La création directe d'une séance planifiée datée pour le groupe revient
   à U7, bilan de fin de séance.~~ **Soldé avec U7** : « Planifier » du bilan
   crée la séance planifiée datée et liée au groupe.
   - ~~**U6** Navigation recentrée~~ : livré (voir plus haut) ; le lot 9
     a pris place sous « Plus ».
9. ~~**Réglages** (F8)~~ : **livré le 2026-10-15** — [ADR 0012](adr/0012-reglages-du-club.md),
   [plan](reglages-plan.md). Écran persisté (drift v7 + sauvegarde JSON v2)
   pour `passesRequired`, seuil d'alerte, `recallStaleSessions`, part d'échec
   du groupe et délai du rappel de sauvegarde ; sous « Plus » (`/settings`),
   pas de sixième onglet ; « Rétablir les valeurs par défaut » avec
   confirmation ; les règles lisent la valeur courante (`RulesStore`).
   - ~~**U7** Accueil « Aujourd'hui » et bilan de fin de séance~~ : **livré le
     2026-10-15**, [plan](aujourdhui-plan.md). Accueil `NowCard` (séance en
     cours à reprendre, prochaine séance Préparer / Lancer, séances à noter,
     élèves à surveiller, 7 derniers jours, rappel de sauvegarde conservé,
     bille n° 8 et motif de tapis) ; à « Terminer », bilan `/record/:id/review`
     (passages, validations du jour, présents sans passage, élèves à
     surveiller, séance suivante du catalogue avec « Planifier » daté). Aucune
     migration, aucune dépendance, pas d'ADR. Restent `[U]` : plan § 11.
     ~~Alertes de groupe~~ : report **soldé avec U9** (carte « Alertes de
     groupe » sur « Aujourd'hui »).
10. Reste de l'ADR 0003, découpé :
    - ~~**10a**~~ : acquittement d'une alerte, vue de groupe (carte de chaleur
      technique × élève, assiduité du groupe) et alertes de groupe
      (`groupFailureSharePercent`) : **livré avec U9 le 2026-10-16** (fiche en
      parcours, vue « à montrer à l'élève », vue de groupe ;
      [ADR 0013](adr/0013-acquittement-des-alertes.md), schéma v8, sauvegarde
      v3, et [ADR 0014](adr/0014-fiche-en-parcours-vue-eleve-et-vue-de-groupe.md)).
      Les cases « acquis » s'appuient sur le lot 7 (ADR 0008).
    - ~~**10b**~~ séance en cours persistée : **livré le 2026-10-17** ([plan](seance-en-cours-plan.md),
      [ADR 0020](adr/0020-seance-en-cours-persistee-locale-hors-sauvegarde.md)) : compteurs, grille acquis, score, étape et
      minuteur (restauré en pause) dans une table `run_progress_entries`, schéma **v10**, **sauvegarde inchangée (v4)**, effacement
      RGPD par groupe, séance planifiée et saisie liés. Points `[U]` U10b-1 à U10b-5 **confirmés par l'animateur le 2026-10-17** (U10b-5, la note de
      jeu, par des étiquettes sans texte libre).
    - ~~**10b, reste**~~ *note de jeu* : **livrée le 2026-10-17** par **étiquettes prédéfinies, sans texte libre** (décision de
      l'animateur du même jour ; [plan](etiquettes-seance-plan.md),
      [ADR 0023](adr/0023-etiquettes-de-seance-liste-fermee-schema-v11-sauvegarde-v5.md)) : huit étiquettes `[Prop]`, saisies à l'étape
      « Bilan » du guide, passées à la saisie à « Terminer », corrigeables depuis le bilan ; schéma **v11**, sauvegarde **v5**. Le
      score A / B en cours reste non enregistré au bilan.
    - ~~**U8**~~ Catalogue et détail en mode « Préparer » : **livré le
      2026-10-16** ([plan](catalogue-preparer-plan.md)) ; le marqueur de
      parcours par groupe lit les données du lot 8 (ADR 0009). Reste le lot 16
      pour remplacer la copie de l'identifiant de « Signaler une proposition »
      par le workflow de validation.
    - Restent `[U]` d'U9 : voir [fiche-eleve-plan.md](fiche-eleve-plan.md) § 6.
11. ~~**Saisons et groupes**~~ : **livré le 2026-10-16** ([plan](saisons-groupes-plan.md),
    [ADR 0019](adr/0019-cloture-de-saison-archive-agregee-et-effacement-en-lot.md)),
    sur les défauts proposés des points `[U]` U11-1 à U11-15 (à confirmer par
    l'animateur) :
    - **11a** groupes : plusieurs groupes par public (nom unique dans la
      saison), créer / renommer / supprimer (vide et sans séance), choix du
      groupe à l'inscription et au changement de public, « Changer de groupe »
      (`MoveStudent`, historique conservé) ; aucune migration.
    - **11b** clôture, domaine : `Season.closedOn` et `isOpenOn`, archive
      agrégée non nominative (seuil de 3 élèves), `CloseSeason` en une seule
      unité de travail (archive avant effacement), schéma **v9**, sauvegarde
      **v4**.
    - **11c** clôture, écrans : assistant (`/seasons/:id/close`), « Saisons
      passées » (`/seasons`), carte « Clôturer la saison » sur « Aujourd'hui ».
    La durée de conservation `[Prop]` de l'[ADR 0001](adr/0001-persistance-locale-drift.md)
    est remplacée par la décision FB 8 (saison en cours + suivante).

## H2 — Usage en salle

12. ~~Guide : en-tête repliable ou compact en séance (F3), schéma en premier,
    deux colonnes en tablette paysage.~~ **Remplacé par U4** (même intention,
    périmètre élargi à la cause : mode « Mener » dédié).
13. ~~Présentation : l'étape complète (consigne + schéma) en plein écran, zoom
    sur le diagramme, légende jamais tronquée (F1).~~ **Remplacé par U3, livré
    le 2026-10-16** (hors périmètre : zoom sur le diagramme, étape complète avec
    consigne).
14. ~~Impression / export PDF d'une séance du catalogue~~ (feuille de l'animateur,
    fiche résultats papier identique au PDF fédéral) : **livré le 2026-10-17**
    ([plan](export-pdf-plan.md), [ADR 0021](adr/0021-export-pdf-feuille-animateur-et-fiche-resultats.md)) :
    `pdf` bas niveau, scène d'impression en domaine pur (deux rendus : PDF et
    aperçu), schémas en vectoriel, bouton sur le détail et dans le guide, page
    d'export hors du cadre ; la fiche résultats reprend la grille fédérale (0 à
    16), pas des pastilles (point U14-1). **Reste** : impression directe non
    automatisable (à vérifier à la main), Safari iPhone et PWA Android non
    vérifiés, PDF non balisé, impression système sur mobile natif (ADR à part),
    dessin des illustrations qui ne sont pas des schémas de table. Défaut
    constaté puis **corrigé le 2026-10-17** : sur le web, l'export de sauvegarde
    affichait « Export annulé. » et n'enregistrait pas la sauvegarde faite
    (`FilePickerBackupFiles`, même cause que `PdfFiles`).
15. ~~Hors-ligne : vérifier le PWA (service worker, sqlite3.wasm / OPFS) sans
    réseau ; installation sur l'écran d'accueil ; plein écran et mode immersif~~
    **Livré le 2026-10-16** ([plan](hors-ligne-plan.md),
    [ADR 0018](adr/0018-hors-ligne-service-worker-precache-versionne.md)) :
    service worker maison avec précache versionné de tout le build (l'ancien,
    celui de Flutter, se désinscrivait : aucun usage hors ligne), CanvasKit et
    police de repli servis par l'application (`scripts/build_web.sh`), manifeste
    complet (nom, couleurs du thème, icônes `any` et `maskable` de l'application,
    orientation libre, `lang: fr`), bannière « nouvelle version disponible »
    jamais appliquée d'office, initialisation Firebase non bloquante, garde-fous
    `scripts/pwa.dart check` (dans `check.sh --fast`) et `verify` (build, CI et
    déploiement). Parcours Chromium fait : élève créé, serveur arrêté,
    rechargement, données et présentation plein écran présents, installabilité
    sans erreur, mise à jour sans perte de la saisie. **Reste** : iPhone / iPad
    Safari, Android avec PWA installée (non vérifiés, pas d'appareil), SDK Firebase
    web encore chargé depuis `gstatic.com` en ligne (à reprendre en FB1 / FB5),
    parcours hors ligne non automatisé en CI, sortie du mode immersif décidée
    par le système sur Android natif (reste d'U3).

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
22. ~~Synchronisation multi-appareils seulement si la question ouverte n° 4
    est tranchée « oui »~~ : **tranchée « oui, via Firebase »** (le 2026-10-16 `[U]`,
    **confirmée le 2026-10-17**), avec un périmètre élargi (comptes, clubs, rôles) ;
    le lot 22 est **rattaché à H5** (l'horizon ci-dessous) et n'a plus d'existence propre. Restent ici les deux rappels natifs sobres et désactivables :
    veille d'une séance planifiée (« Préparer la séance de demain ») et
    sauvegarde de plus de 30 jours (ce dernier devient sans objet pour un
    compte synchronisé).
23. ~~Dette : `scripts/` sans `pubspec.yaml`, build `--wasm`, mutation testing
    retiré~~ **Traitée le 2026-10-17** ([ADR 0022](adr/0022-dette-outillage-scripts-wasm-mutation.md)) :
    `scripts/` est un paquet analysé avec `very_good_analysis` (21 écarts
    corrigés) ; `--wasm` évalué, il compile et fonctionne mais reste mono-fil
    sans COOP/COEP (qui menacent Firebase Auth, H5) et exige un précache
    refait : **non adopté**, à réexaminer après l'ADR d'authentification de H5
    et sur mesure de performance ; mutation testing **maintenu hors
    périmètre** (mutation ciblée à la main), condition de réexamen écrite.
    Aussi corrigé ce jour : l'export de sauvegarde sur le web (voir lot 14).

## H5 — Firebase : comptes, clubs, rôles et synchronisation

Décision `[U]` du 2026-10-16 (répond « oui » à la question ouverte n° 4 de
`docs/knowledge/08-lacunes-et-questions-ouvertes.md`). Elle change le cadrage
de l'[ADR 0001](adr/0001-persistance-locale-drift.md) (« un seul animateur »,
« aucune donnée ne quitte l'appareil ») et la règle « Persistance : local
d'abord » d'`AGENTS.md` : les deux sont **amendés par l'[ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md)**
(lot FB0, en cours), ainsi que les ADR 0006, 0016, 0018, 0019 et 0020.
Recherche préalable : [research/firebase.md](research/firebase.md) (versions à
revalider, Linux non supporté, Auth traité aux États-Unis, région Firestore
irréversible).

### Besoins `[U]`

1. **Authentification** : chaque utilisateur a un compte.
2. **Multi-écoles** : une école = un club ; un club a un nombre **illimité**
   de groupes.
3. **Profils** : élève, enseignant, directeur de club, administrateur ;
   l'administrateur a **tous les droits**.
4. **Firestore** comme stockage, avec des accès sécurisés (règles Firestore).
5. **Synchronisation multi-appareils** : une modification faite par
   l'enseignant se répercute sur les appareils de tous ses élèves.

### Matrice des droits (validée le 2026-10-16, décisions 6 et 7)

| Action | Élève ou parent | Enseignant | Directeur | Admin |
|---|---|---|---|---|
| Lire sa fiche, son parcours, les séances planifiées de ses groupes | ✓ | ✓ | ✓ | ✓ |
| Lire les élèves et résultats d'un groupe | — | ses groupes | son club | tous |
| Saisir des passages, planifier, positionner, acquitter une alerte | — | ses groupes | son club | tous |
| Créer, renommer, archiver un groupe ; y affecter élèves et enseignants | — | — | son club | tous |
| Inviter un élève | — | ses groupes | son club | tous |
| Inviter un enseignant, changer un rôle dans le club | — | — | son club | tous |
| Réglages du club (`RulesConfig`), clôture de saison | — | — | son club | tous |
| Créer un club, nommer un directeur, nommer un administrateur | — | — | — | ✓ |

Un utilisateur peut appartenir à plusieurs clubs avec un rôle par club
(un enseignant qui intervient dans deux écoles) ; l'administrateur est un
rôle global, hors club.

### Modèle de données (tranché par l'[ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md), décision 14)

```
admins/{uid}                                  administrateurs globaux (console, jamais écrits par l'application)
clubs/{clubId}                                nom, saison courante
clubs/{clubId}/settings/main                  réglages du club (RulesConfig), document unique
clubs/{clubId}/members/{uid}                  rôle (student | guardian | teacher | director), groupIds, studentIds
clubs/{clubId}/invitations/{code}             code à usage unique (get seul, jamais list)
clubs/{clubId}/seasons/{seasonId}             saison, closedOn
clubs/{clubId}/groups/{groupId}               seasonId (champ), public, nom, teacherUids
clubs/{clubId}/memberships/{studentId_from}   appartenance datée d'un élève à un groupe
clubs/{clubId}/students/{studentId}           prénom + initiale (bornés), public
clubs/{clubId}/sessions/{id}                  séance planifiée (groupe, date, séance du catalogue)
clubs/{clubId}/records/{id}                   saisie (id déterministe si séance du catalogue, ADR 0016 amendé)
clubs/{clubId}/attempts/{id}                  un passage par document, passIndex dérivé (ADR 0006 amendé)
clubs/{clubId}/acquisitions|assessments|acknowledgements/{id}
clubs/{clubId}/archives/{season_public}       archive agrégée non nominative
```

`seasonId` est toujours un champ, jamais un ancêtre du chemin ; les documents
de données portent `groupId`, `studentId` et `seasonId` dénormalisés. Le
tableau « document × rôle × règle » est dans l'ADR 0024. Le catalogue, les
fiches et les diagrammes restent des **assets** de l'application (ils
viennent de `docs/knowledge`, pas de Firestore). Les identifiants UUID,
`createdAt` et `updatedAt` de l'ADR 0001 servent tels quels ; la suppression
est physique par défaut (`deletedAt` seulement s'il a un sens métier).

### Lots

| Lot | Contenu | Dépend de |
|---|---|---|
| **FB0** Décisions et conformité — **en cours** | **Fait** : [ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) « Firebase source de vérité » (amende ADR 0001, 0006, 0016, 0018, 0019, 0020 et `AGENTS.md` ; modèle de données, matrice des droits, rôles, sort de drift, A1 à A12, B1 à B9, C1 à C7 sur défauts) ; `firebase.json` et `firestore.rules` alignés (`europe-west9`, e-mail seul, refus par défaut). **Reste** : livrables de conformité en **projets « à valider »** (registre, AIPD en brouillon, notice d'information fr/en, durées de conservation, DPA Google) ; base `(default)` **créée par l'animateur en `europe-west9` le 2026-10-17 (fait, région effective à constater dans la console `[à confirmer]`)** ; **côté animateur** : publier `firebase.json` et `firestore.rules`, contrôler dans la console les fournisseurs d'Auth et les règles publiés, relever le quota gratuit de la région (désormais visible), `flutterfire configure`, formule Spark ; désigner qui valide la conformité (fédération ou DPO) | — |
| **FB1** Socle — **fait le 2026-10-17 sauf le reste ci-dessous** | **Planifié au départ** : dépendances FlutterFire (`shared_preferences` reportée au lot qui crée le port clé/valeur et son test), environnements (`--dart-define=FIREBASE_EMULATOR`, valeur sûre par défaut, release qui refuse l'émulateur ; previews de PR sans Firestore), initialisation dans `app/di`, `package.json` épinglé + Node + Java + Firebase CLI en CI (échec explicite si absents), garde-fou « règles Firestore » : tests de matrice et de refus par défaut contre l'émulateur (`@firebase/rules-unit-testing`) dans `scripts/check.sh --full`, suppression de `app/linux`, retrait de macOS et Windows de `firebase_options`, job CI `flutter build apk --debug`, ports `CurrentUser` / `ActiveClubScope` dans `shared` ; **Fait (détail)** : `package.json` + `package-lock.json` épinglés (`firebase-tools` 15.34.0, `@firebase/rules-unit-testing` 6.0.0, `firebase` 13.0.0), `firebase.json` (bloc `emulators`), `scripts/rules_test.sh` + `scripts/rules_test/` (refus par défaut, 188 cas), branché dans `check.sh --full` (`--fast` inchangé) et `setup.sh` ; CI : Node 24, Java 21, `npm ci`, job `build-android` ; `firebase_auth`, `cloud_firestore` (`shared_preferences` retirée à la relecture : aucun usage ni test avant le port clé/valeur de la décision 23) ; `FirebaseEnvironment` (défaut sûr : l'émulateur seulement si demandé, **y compris en debug**, précision de l'ADR 0024 ; release refuse), `FirebaseStartup` / `FirebaseGateway` dans `app/di` (résultat attendable par l'`AuthCubit` de FB2, non bloquant au démarrage) ; `app/linux` supprimé, macOS et Windows retirés de `firebase_options` et `app/firebase.json`, `Taskfile` (`DEVICE=chrome`) ; `platform_privacy_test` mis à jour (ADR 0025). **Reste** : ~~ports `CurrentUser` / `ActiveClubScope` dans `shared`~~ (livrés avec FB2) ; ~~**SDK web servi localement** (B7 : décision FB5)~~ (livré en FB5a, 2026-10-19 : carte d'import, voir ADR 0024 notes FB5a) ; Java 21 non exécuté en local (poste en Java 27, CI en 21, à constater au premier passage) ; Auth exercée de bout en bout dans le build web compilé (`scripts/web_smoke.sh`, FB2) ; Firestore exercée par les tests de règles (FB1, FB3) et la graine ; les dépôts de données restent locaux jusqu'à FB4 ; côté animateur : actions de console de FB0 (publier `firebase.json` et `firestore.rules`, contrôler Auth et règles publiés, `flutterfire configure` pour regénérer `firebase_options` sans macOS ni Windows) | FB0 |
| FB0 |
| **FB2** Authentification — **fait le 2026-10-17 sauf le reste ci-dessous** | **Planifié** : entité `account`, feature `sign_in` (connexion par e-mail et mot de passe, déconnexion, mot de passe oublié), redirection go_router tant que non connecté, sélection du club actif si plusieurs ; pas de Linux (décision 4). **Fait (détail, [auth-plan.md](auth-plan.md))** : ports `CurrentUser` / `ActiveClubScope` / `ClubSwitchGuard` / `KeyValueStore` dans `shared/lib` (sans Firebase) ; `entities/account` (`Account`, `AuthRepository`, `AuthFailureCode` distinct d'`InvariantCode`, `FirebaseAuthRepository` derrière le port `AuthSdk`, double en mémoire) et `entities/membership` (`MembershipsSource`, `ActiveClubMemory`) ; `features/sign_in` (connexion, **adresse vérifiée exigée**, renvoi du courriel de vérification, mot de passe oublié, inscription fermée par code avec mot de passe d'au moins 10 caractères qui ne crée que le compte, `PendingInvitations` en point d'extension de FB3) et `features/select_club` (club actif retenu **par compte** avec `shared_preferences` derrière `KeyValueStore`, effacé à la déconnexion, bascule interdite pendant une séance guidée) ; `AuthCubit` (`unknown`, `signedOut`, `noClub`, `ready`, `indisponible`) qui attend `FirebaseStartup.ready`, écran de démarrage localisé, redirection `go_router` (aucune route sans compte, retour à l'adresse demandée), `KeyedSubtree(clubId)`, démarrage hors ligne avec session persistée et club retenu ; pages et widgets avec use cases Widgetbook, textes fr et en ; 24 scénarios BDD (`authentication.feature`), tests unitaires, tests de l'émulateur **Auth** (`auth_emulator.test.mjs`, dans `scripts/rules_test.sh`), **fumée du build web compilé** avec le vrai SDK (`scripts/web_smoke.sh`, dans `check.sh --full` et la CI) et suite de contrat `AuthRepository` ; `AuthCubit` qui borne l'attente de démarrage (20 s, puis « indisponible ») ; les BDD existants s'exécutent connectés (`UiWorld`). **Reste** : ~~implémentation Firestore de `MembershipsSource` et consommation du code d'invitation gardé~~ (livrées avec FB3) ; **côté animateur, console Firebase** : un seul fournisseur actif, **protection contre l'énumération d'adresses à activer**, modèles de courriel (vérification, réinitialisation), domaines autorisés, `flutterfire configure` ; le serveur n'impose que 6 caractères de mot de passe (les 10 sont une règle de l'application) ; ~~web hors ligne tant que le SDK vient de `gstatic.com`~~ (SDK servi en local depuis FB5a ; le web hors ligne exige encore `DATA_BACKEND=firestore` et la session persistée) ; appareils réels Android et iOS non exercés | FB1 |
| **FB3** Clubs, rôles, invitations — **fait le 2026-10-17 sauf le reste ci-dessous** | **Planifié** : entités `club` et `membership`, écrans « Mon club » (directeur : groupes illimités, enseignants, élèves) et « Administration » (admin : clubs, directeurs) ; invitations par code (inscription fermée, ADR 0024 décision 24) ; lier un compte élève à une fiche `student` existante ; navigation et actions filtrées par rôle ; **règles Firestore** et leurs tests, cas par cas de la matrice (dont l'invité sans `member`) ; **critère de sortie : garde-fou ci-dessous (première invitation d'un vrai élève)**. **Fait (détail, [clubs-roles-plan.md](clubs-roles-plan.md))** : `firestore.rules` **complètes** (16 collections de l'ADR, matrice rôle × action, invitations à usage unique par lot `getAfter` / `existsAfter`, bornes de champs, refus par défaut, `admins` jamais en écriture, budget de `get()` mesuré à 6 sur 10) et leurs tests contre l'émulateur (`matrix`, `invitations`, `escalation`, `bounds`, `default_deny`, `model_coverage`, `budget`, `seed` : grille de 12 acteurs, isolation entre clubs, entre groupes d'un club, entre enfants, réutilisation, expiration, mauvais club, mauvais rôle, e-mail non vérifié, élévation de privilège) ; **mutations à la main** de la copie des règles consignées dans [testing.md](testing.md) ; entités `club`, `membership` (+ `Member`, périmètre groupes et fiches), `invitation` (code Base32 de 12 caractères, 48 h / 7 j, révocable) ; port `DocumentStore` (lot atomique) avec double en mémoire et adaptateur Firestore (seul `app/platform` importe `cloud_firestore`) ; `StoreMembershipsSource` remplace `NoMembershipsSource` ; consommation du code gardé à l'inscription (`AcceptInvitation`, `/join/<code>`, lot atomique) ; pages « Mon club », « Inviter », « Rejoindre un club », « Administration », « Mes enfants » / « Ma progression » ; garde de route par rôle (`roleRedirect`) **et** menus filtrés ; club « Démo » ordinaire (C6) ; **graine des émulateurs** (`scripts/seed_emulator.mjs`) ; 23 scénarios BDD (`clubs_roles.feature`) ; Widgetbook ; index d'exemption `members.uid`. **Découpage avec FB4 (écrit)** : les groupes et élèves restent gérés dans « Élèves » (drift) ; « Mon club » ne gère que l'équipe, les familles, les invitations et le nom ; la première invitation d'un élève publie sa fiche minimale (`StudentDirectory`). **Reste** : **côté animateur : déployer les règles et les index (`firebase deploy --only firestore:rules,firestore:indexes`) : date de déploiement À FAIRE PAR L'UTILISATEUR, rien n'a été déployé** ; créer le document vide `admins/{uid}` et le premier club (voir le plan) ; FB4 (listes serveur d'élèves et de groupes, donc la vue d'un parent sur son propre appareil) ; affectation des groupes d'un membre existant ; **relecture du 2026-10-18** : règles resserrées (liste blanche de champs, élève du groupe de l'enseignant), démarrage à froid sur un lien d'invitation, règle de retrait d'un membre portée par le domaine, projet `demo-cfa-ffb` pour l'application sous émulateur, `FirestoreSdkAccess` testé ; parcours navigateur application + émulateurs + graine (`scripts/emulator_e2e.sh`, mode debug : le build compilé n'accepte pas l'émulateur, testing.md « Piège ») ; le build compilé n'exerce toujours pas Firestore ; garde-fou de mise en production | FB2 |
| **FB4** Repositories Firestore — **fait le 2026-10-18 en trois parties, SAUF la bascule de production, reportée après FB7 (voir [repositories-firestore-plan.md](repositories-firestore-plan.md))** | **Partie 1 faite** : erreurs d'ouverture de session distinguées (accès refusé sans « Réessayer » / service injoignable avec) ; garde-fou d'index (`tool/check_indexes.dart`, `check.sh --fast`) ; fondation (`ClubPaths`, `ClubStore` : club résolu à chaque appel, `DocumentStore.query`, `DataBackend` drift par défaut) ; suite de contrat élèves + groupes + réglages sur Firestore (faux en mémoire) et test Node contre l'émulateur et les vraies règles (`repositories.test.mjs`) ; dépôts Firestore **settings, student, group (+ appartenances)** ; règle `audienceHistory` (+ test + mutations). **Partie 2 faite** : `UnitOfWork` Firestore (un lot atomique de 500 écritures au plus, erreur explicite au-delà, lecture de ses propres écritures, `CompositeUnitOfWork` avec drift) ; création d'élève par un enseignant tranchée (fiche et appartenance dans **un** lot, règle des appartenances ouverte à l'enseignant **pour une fiche neuve de son groupe seulement**, règle des fiches inchangée ; test de règle + mutations) ; dépôts Firestore **saisons, archives, séances planifiées, saisies** (contrat sur drift + mémoire + Firestore faux, `planning.test.mjs` contre les vraies règles, aucun nouvel index) ; identifiant déterministe d'une saisie liée (`sittingId`, décision 18) ; bornes du domaine (libellé de saison et nom de groupe ≤ 80, titre ≤ 120, ≤ 60 présents, séance sans groupe). **Tranché le 2026-10-18** : groupe obligatoire pour une séance planifiée (invariant dans `PlanSession`, écran qui l'exige ; **reprise au FB7** des séances sans groupe déjà dans drift, restées lisibles) ; transfert d'une saisie libre vers une séance du catalogue = la confirmation actuelle, la saisie garde son UUID, doublon rare assumé (décision 18 amendée) ; ouverture concurrente d'une saisie convergente (`createdAt` posé par la création seulement, présents par `ArrayUnion` à l'ouverture concurrente seulement, la reprise les remplace ; lecture d'un document absent sans oracle d'existence) ; appartenance d'un enseignant liée à son contenu ; borne de 64 sur l'identifiant d'une saisie. **Partie 3 faite le 2026-10-18 (FB4c, [ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) notes FB4c)** : **`passIndex` dérivé** (décision 17, ADR 0006 amendé : le rang d'un passage se dérive de l'ordre d'enregistrement, ni stocké ni renuméroté ; `ExerciseAttempt` et `ExerciseResult.derive` changent ; colonne drift retirée, schéma v12 ; sauvegarde toujours lisible en v1 à v5, le rang dérivé reste écrit dans le fichier) ; dépôts Firestore **passages (un document par passage, ajout seul), blocs acquis, bilans, acquittements** (« Vu » partagé par club avec l'`uid` de l'animateur, B5) avec contrat sur drift + mémoire + Firestore faux et `progress.test.mjs` contre les vraies règles (règles resserrées : `createdAt` du serveur exigé sur un passage, correction limitée aux billes, `createdBy` = uid d'un acquittement) ; lecture par rôle (parent et élève : blocs acquis de la fiche liée seulement ; bilans et alertes exclus) ; aucun index composite à déclarer (`tool/check_indexes.dart` vert) ; `CompositeUnitOfWork` qui **n'attend plus l'accusé du serveur** dans la transaction drift (envoi suivi à part, port `SendStatus` pour FB5) ; `RulesStore` **rechargé à l'activation et à la bascule de club** (réglages du club séparés des préférences d'appareil) ; contrat complet `RepositoryHarness` joué sur les dépôts Firestore de **tous** les dépôts de données (limites dites dans testing.md) ; `SuggestedSessionPage.onPlan` typé (groupe obligatoire) avec scénarios de routeur ; forme des identifiants figée (`mayProbeAbsent`) ; import sans saisie sous Firestore figé. **Décision de l'utilisateur (2026-10-18) : la bascule de production n'a PAS lieu dans FB4.** `DATA_BACKEND` reste **`drift` par défaut** jusqu'à ce que **FB7 (migration)** soit livré ; la bascule fera l'objet d'un **lot dédié après FB7**. **Reste, hors FB4** : lot de bascule (après FB7), sauvegarde et `StudentEraser` côté serveur (FB7, FB8), `watch…` et pastille « envoi en attente » (FB5), clôture reprenable (FB7), parcours navigateur avec dépôts Firestore, saison courante du club. **Planifié au départ** : une implémentation Firestore par dépôt de données (16 interfaces `*_repository.dart`, dont 3 d'assets ; 13 de données, dont `run_progress` (local, ADR 0024 décision 23) et `backup_marker` (local, sans objet après B5) ; soit 11 dépôts Firestore, tous en `Future`, aucun en `Stream`), portées par club ; la suite de contrat existante (garde-fou de l'ADR 0001) tourne aussi contre l'émulateur ; les implémentations in-memory restent pour les BDD | FB3 |
| **FB5** Synchronisation temps réel et hors-ligne — **partie A (infrastructure) faite le 2026-10-19 ; reste la partie B** | **Partie A faite (FB5a, 2026-10-19, [ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md) notes FB5a)** : SDK web servi en local (carte d'import, copies épinglées SHA-256, précachées, `scripts/sync_firebase_sdk.dart --check` dans `check.sh --fast`, B7 levé) ; persistance hors ligne activée explicitement sur web, multi-onglets, cache vidé à la déconnexion et au changement de compte (`LocalDataGuard`, déconnexion refusée tant que des envois sont en attente sans confirmation), avertissement appareil partagé ; pastille « À jour / Envoi en attente (n) / Hors ligne » (`SendStatus` + `ConnectivityStatus`, web seulement pour le réseau) ; **écritures hors ligne sans lecture du serveur** (bloc acquis, bilan, « Vu » : `DocumentStore.peek` + propriétaire porté par les règles ; saisie **libre** créée hors ligne) ; déploiement CI des règles et des index ([deploiement-firestore.md](deploiement-firestore.md), étapes de l'utilisateur à faire, jamais exécuté contre le projet réel). **Reste (partie B)** : méthodes `watch…` et cubits abonnés, règle de conflit documentée, scénario « la fiche se met à jour sans rechargement », écritures hors unité de travail non bloquantes, **saisie liée à une séance du catalogue hors ligne** (transaction `createIfAbsent`), indice de réseau natif, « prêt hors ligne », parcours navigateur hors ligne réel. **Planifié au départ** : pastille « envoi en attente » lue sur `SendStatus` (FB4c : `CompositeUnitOfWork` valide localement sans attendre le serveur, l'envoi est suivi à part, `lastFailure` pour un refus tardif) ; écritures hors unité de travail à rendre non bloquantes de la même façon ; **bloquant de bascule : créer un bloc acquis, un bilan ou un « Vu » est impossible hors ligne** (`StudentData.upsert` lit le document cible avant d'écrire ; à créer sans lecture, propriétaire résolu depuis le cache, ADR 0024 notes FB4c, relecture) ; création d'une saisie (transaction `createIfAbsent`, impossible hors ligne) ; méthodes `watch…` (flux) sur les repositories lus par plusieurs appareils, cubits abonnés aux flux, persistance hors-ligne activée sur web (désactivée par défaut), indicateur « synchronisé / en attente / hors-ligne », règle de conflit documentée ; scénario BDD : l'enseignant planifie ou saisit, la fiche de l'élève se met à jour sans rechargement | FB4 |
| **FB6** Espace élève | accueil élève en lecture seule : sa fiche en parcours et la vue « à montrer à l'élève » (ADR 0014) devenues sa page, prochaines séances planifiées de ses groupes ; aucune donnée d'un autre élève | FB5 |
| **FB7** Migration des données locales | **à livrer AVANT la bascule de production (décision du 2026-10-18 : drift reste le backend par défaut jusqu'à FB7 ; la bascule est un lot dédié après FB7)** ; **l'import d'une sauvegarde est non supporté avec `DATA_BACKEND=firestore` jusqu'ici** (`ServiceFailure` `unsupported`, rien d'écrit : une saisie se crée par transaction, impossible dans un lot) ; import d'une sauvegarde JSON (format 5, formats 1 à 5 lus ; l'import doit écrire `recordedAt` **strictement croissant dans l'ordre du fichier** : `createdAt == request.time` est exigé même d'un directeur ou d'un administrateur, donc tous les passages importés ont la même date serveur et seul `recordedAt` (puis l'identifiant) fixe leur ordre) dans un club par le directeur, l'administrateur ou l'enseignant sur ses groupes ; correspondance des groupes ; contrôle d'intégrité ; le format de sauvegarde reste l'export de portabilité | FB4 |
| **FB8** Cycle de vie RGPD | suppression d'un compte et de ses données, effacement d'un élève (aujourd'hui local, `UnitOfWork` ; demain lots reprenables, ADR 0024 décision 19), clôture de saison par club (rejoint le lot 11), export des données d'un élève (droit d'accès), App Check ; **critère de sortie : garde-fou ci-dessous ([ADR 0025](adr/0025-comptes-et-donnees-de-mineurs-conformite.md))** | FB3, FB4 |

Le lot **11** (saisons et groupes) est à mener **dans** FB3 / FB8 plutôt
qu'avant : « plusieurs groupes par public » devient « groupes illimités par
club », et la clôture de saison doit s'appliquer aux données Firestore.

### Décisions `[U]` du 2026-10-16 (questions de FB0)

1. **Source de vérité : Firestore seul**, avec son cache hors-ligne. drift
   est retiré une fois FB7 (migration) livré ; aucun mode « sans compte ».
2. **Comptes élèves : compte parent rattaché.** Le parent crée le compte
   avec son adresse et voit la fiche de son enfant ; un élève de 15 ans ou
   plus peut avoir son propre compte (âge du consentement numérique à
   vérifier en FB0).
3. **Formule Spark (gratuite).** Pas de Cloud Functions : invitations par
   lien ou code à usage unique, purge de fin de saison lancée depuis
   l'application, **rôles stockés dans Firestore** (documents `members` lus
   par `get()` dans les règles ; administrateurs dans `admins/{uid}`, créés à
   la main dans la console).
4. **Plateformes : Android, iOS et web.** Linux est abandonné ; Windows reste
   un poste de développement ; sur ordinateur, on passe par le navigateur.
5. **Connexion : e-mail et mot de passe**, avec « mot de passe oublié » ; le
   lien magique pourra s'ajouter plus tard.
6. **Invitations** : l'enseignant invite dans ses groupes, le directeur dans
   tout le club, l'administrateur partout.
7. **Visibilité : l'enseignant ne voit que ses groupes** ; le directeur voit
   tout son club.
8. **Conservation : la saison en cours et l'année suivante**, puis
   effacement ; effacement à la demande à tout moment (remplace la durée
   `[Prop]` de l'ADR 0001).

Les points laissés ouverts le 2026-10-16 (détail du modèle, invitations, parent
à plusieurs enfants, conformité) sont **tranchés par l'ADR 0024**.

### Garde-fou de mise en production (ADR 0024 décision 12, précisé par [ADR 0025](adr/0025-comptes-et-donnees-de-mineurs-conformite.md) décision 3)

FB1 à FB5 se développent sous émulateurs et avec des comptes de test, sur
l'unique projet `animation-billard` (previews de PR sans Firestore). **Aucune
base de production n'accueille de vrai élève, parent ou enseignant avant que
l'AIPD soit validée et que la notice d'information, le registre, l'accord de
sous-traitance (DPA) et la procédure d'exercice des droits soient validés,
le responsable de traitement étant désigné par écrit** : l'agent n'en rédige
que des projets marqués « à valider » (livrables : [conformite/README.md](conformite/README.md)) ;
**validation : la fédération ou un DPO, désigné par l'animateur**. Le garde-fou
n'est levé que par une **décision `[U]` datée**, consignée dans
`conformite/README.md`. Responsable de traitement visé : chaque club,
l'éditeur étant sous-traitant ; une fédération, si elle se manifeste, peut
devenir responsable unique (**à valider : l'animateur**). Ce jalon est hors
code et s'ajoute aux critères de sortie de FB3 (première invitation d'un vrai
élève) et de FB8.

### Vérifié à la source le 2026-10-17

Quotas Spark de Firestore (1 GiB, 20 000 écritures, 50 000 lectures et 20 000
suppressions par jour, pas de Functions) et âge de 15 ans (CNIL, article 45) :
confirmés, sources dans l'ADR 0024. Restent à vérifier : quota gratuit propre à
`europe-west9` (à relever dans la console, la base étant créée), TTL sur Spark (FB8).

## Restes ouverts au 2026-10-17

Récapitulatif central ; le détail est dans le plan de chaque lot.

- **Décisions de l'animateur** : toutes tranchées le 2026-10-17. Confirmés sur leur défaut : les `[U]` des lots **U3** (U3-1 à
  U3-4), **10b** (U10b-1 à U10b-5), **11** (15 points), **14** (U14-1 à U14-12), ainsi que « Noter » aux seules étapes d'exercice,
  le lien explicite `plannedSessionId` (**D1** : saisie sans séance du catalogue = saisie de la planifiée du jour) et l'export
  avant clôture (U11-9, proposé, non bloquant). Tranchés autrement : **note de jeu** par étiquettes prédéfinies, sans texte libre
  (livrée, ADR 0023) ; **question n° 4 : oui, via Firebase** (lot 22 rattaché à H5) ; **minuteur dépassé : pas de rouge**
  (livré, `inverseSurface` avec sablier, aligné sur l'ADR 0010).
- **Non vérifié sur appareil** : iPhone / iPad Safari, PWA installée sur
  Android, Firefox et Safari bureau, vibration du minuteur, Échap en plein écran,
  impression directe (`window.print()`), en-têtes `no-cache` sur Firebase Hosting.
- **Défauts connus** : schéma de table à 844 × 390 qui défile ; groupe sans
  membre du jour (grilles vierges, sans message) ; libellé « Aujourd'hui » coupé
  à 320 dp ; titres tronqués à 390 dp dans le guide (E3) ; segment « Bilan » de la
  frise étroit (E4) ; dernière présence absente de la liste des élèves (E1) ;
  double lecture dans `GetGroupJourney` ; importer un fichier d'avant une
  clôture rétablit les élèves effacés (limite assumée, ADR 0019).
- **Tests à compléter** : mutant `kIsWeb` de `FilePickerBackupFiles.platform()`
  (test sur Chrome), service worker sans test de navigateur automatisé, BDD de
  U3, 11, 10b et 14 validés par mutation et non par rouge préalable (les étiquettes de séance, elles, ont leurs rouges : plan § 7).
- **Contenu (H3)** : lots 16 à 20 ; restes de l'audit des séances et cinq
  contenus `[Prop]` de la revue T8 (voir plus haut).
- **Technique** : lot 21 (clé de signature), 22, H5 ; `--wasm` à réexaminer
  après l'ADR d'authentification (ADR 0022).
- **Hors-ligne** : le SDK Firebase web est servi en local depuis FB5a ;
  indicateur « prêt hors ligne » non fait (FB5b).

## Ordre recommandé

```
H0 : ~~F7~~ → ~~revue T8~~ (faite, constats ouverts ci-dessus) → ~~réaliser D5~~ réalisé (les questions ouvertes sont tranchées ; U2 livré)
H1 : ~~U5~~ → ~~U6~~ → ~~9~~ → ~~U7~~ → ~~10a + U9~~ → ~~U8~~ → ~~10b~~ → 11   (5 à 9, U7, U8, U9, 10a et 10b livrés)
H2 : ~~U4~~ → ~~U3~~ → 14 → 15   (U4 et U3 livrés)
H3 : 16 (avec le mode Relecture de U4) → 17 → 18 → 19 → 20
H4 : 21 → 22 (rappels) → 23
H5 : FB0 → FB1 → FB2 → FB3 (+ lot 11) → FB4 → FB5 → FB6 ; FB7 et FB8 après FB4 ; **bascule de production (`DATA_BACKEND=firestore` par défaut) : lot dédié après FB7** (décision du 2026-10-18)
```

H5 peut démarrer en parallèle de H2 : FB0 est documentaire et demande
d'abord des actions de l'utilisateur (projet Firebase, conformité).

U1 (livré) a posé les fondations dont tout dépend ; U5 tôt
parce que la saisie est l'action quotidienne et que le lot 6 (livré) lui
fournit groupe, date et séance du catalogue ; les lots 7 et 8 sont livrés
(ADR 0008 et 0009), U7 a donc déjà toutes les données qu'il affiche et U8
son marqueur de parcours ; U4 et U3 avant la première séance réelle en
salle.
