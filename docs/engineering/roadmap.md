# Roadmap

Rédigée le 2026-10-13 après un tour complet du dépôt (connaissances, ADR, plans,
application) et un test de l'application en web (Chrome, 1280 × 800 puis
390 × 844). Elle liste ce qui reste ouvert et ce qui manque, par horizon ; elle
ne remplace ni les ADR (décisions) ni les plans (exécution). Chaque lot livré
est retiré d'ici et consigné dans l'ADR ou le plan concerné.

## État de départ (2026-10-13)

- Connaissances : 5 PDF `[S]`, 14 fiches techniques, catalogue d'entraînement
  15 blocs / 72 exercices (dont 2 blocs `[Prop]`), 94 pages de diagrammes YAML,
  29 séances du catalogue (`fiches.dart --complete` vert), 244 points
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
| F2 | Diagramme bille fantôme : l'étiquette « Bille fantôme » chevauche la ligne de visée et la bille ; le cercle fantôme disparaît sous la pointe de flèche ; même défaut sur les repères numérotés (« 3 », « 5 » sous la trajectoire) — traité par le lot **U2** | `shared/ui/ghost_aim_diagram`, `table_diagram` |
| F3 | Guide : l'en-tête (titre, public, thème, barre d'étape, minuteur, boutons) occupe ~45 % de l'écran desktop et ~60 % sur mobile ; le schéma d'exercice est sous la ligne de flottaison — traité par le lot **U4** | `pages/sheet_guide` |
| F4 | Saisie : le sélecteur d'exercice est un bouton sans libellé accessible, au libellé tronqué sur mobile — traité par le lot **U5** | `pages/record_session` |
| F5 | ~~Onglet « Résultats » : aucun historique des séances saisies ; impossible de relire, corriger ou supprimer un passage~~ — corrigé (ADR 0006) | `pages/record_history` |
| F6 | ~~Séance planifiée sans date ni groupe, non liée à la saisie (décision 10 de l'ADR 0004, assumée mais visible)~~ — corrigé (ADR 0007) | `pages/session_planner` |
| F7 | Séance suggérée : « Pas de rappel » pour les enfants (`recallCount = 0`, voulu) alors que la fiche élève affiche une notion à rappeler ; rien ne l'explique à l'écran | `pages/suggested_session` |
| F8 | Les seuils (`passesRequired`, alertes, `recallStaleSessions`) sont dans `RulesConfig.standard()` sans écran de réglages — livré sous la destination « Plus » du lot **U6** | `app/di` |

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
| **U1** Fondations du design system | ADR 0010 (le numéro 0008 est pris par le positionnement initial, 0009 par la suggestion ↔ catalogue) : bleu-tapis en `secondary`, rouge FFB en accent (`BrandColors`) ; `SectionCard.emphasis` ; logo FFB derrière un drapeau (ADR 0002, décision 5) ; icônes de navigation ; composants `PassDots`, `TimerChip`, `PhaseTimeline`, `StepAppBar` | états « sélectionné » roses, piste rouge en sombre |
| **U2** Lisibilité des schémas | annotations hors trajectoire, halo, queue non coupée, repères à la taille de la blanche, médaillon `inset` (quantité de bille), étiquettes ≥ 16 px en présentation | F2 |
| **U3** Présentation plein écran | `DiagramStage` (table sur la plus grande dimension, légende réservée, contrôles en barre basse), plein écran natif, « tournez l'appareil » | F1, lot 13 |
| **U4** Guide en mode « Mener » | route hors shell, en-tête compact + frise des phases, schéma en premier, sections repliées, badges de provenance masqués sauf mode « Relecture », minuteur en en-tête, barre basse Précédent / Noter / Suivant | F3, lot 12 |
| **U5** Saisie rapide en grille | grille élève × passage avec `PassDots`, sélecteur d'exercice nommé et non tronqué, liste compacte sur téléphone, historique groupé par élève, feuille basse depuis le guide | F4 |
| **U6** Navigation recentrée | destinations « Aujourd'hui / Élèves / Résultats / Séances (Planifiées · Catalogue · Suggestion) / Plus (Sauvegarde, Réglages) » ; rappel de sauvegarde | F8 (emplacement du lot 9) |
| **U7** Accueil « Aujourd'hui » et bilan de fin de séance | séance en cours à reprendre, prochaine séance planifiée (Préparer / Lancer), alertes, semaine, sauvegarde ; à « Terminer », bilan des passages et proposition de la séance suivante | accueil statique |
| **U8** Catalogue et détail en mode « Préparer » | nom évocateur en titre, badge unique « n points à valider », marqueur de parcours par groupe, frise des phases dans le détail, deux colonnes | : |
| **U9** Fiche élève, vue élève et vue de groupe | parcours en cases (technique × exercice), en-tête en cours / prochain / alerte, courbes repliées, vue « à montrer à l'élève », heat-map technique × élève et assiduité du groupe | « 0 sur 72 », lot 10 (vues) |

## H0 — Clore ce qui est ouvert

1. Lot L8 « finition » de l'ADR 0004 (seul lot non livré) : `check.sh --fast`
   en `--complete`, docs (`progression-par-cycles.md`, glossaire).
   L'accessibilité (F4) et la tablette paysage (F3) passent aux lots U5 et U4.
2. Revue T8 du plan tailles et illustrations : `architecte-fsd`, `testeur-bdd`,
   `relecteur-pedagogique`, dans un contexte séparé.
3. Corriger F7 (un texte « pas de rappel : une notion par séance enfants »).
   F1 et F2 sont absorbés par U3 et U2, pour ne pas corriger deux fois.
4. ~~Faire trancher par l'animateur~~ — **tranché le 2026-10-14** : D5 =
   **ajouter** l'illustration `contact_height` ; questions 2 à 4 de
   `docs/knowledge/08-lacunes-et-questions-ouvertes.md` (unité « séance »,
   dimensionnement groupes / saison, synchronisation) : recommandations de
   l'assistant suivies, à consigner dans ce fichier. Reste à **réaliser** D5
   dans `tailles-et-illustrations-plan.md`. D2 (ligne de départ à 1,6 `[FFB]`)
   est **réalisée** : les positions YAML, absolues, sont inchangées.
   Les questions Q1 à Q8 du plan UX sont **tranchées** `[U]` le 2026-10-14
   (toutes dans le sens recommandé : voir
   [ux/plan-ux-proposition.md § 6](ux/plan-ux-proposition.md)).

Lots UX en H0 :

- **U1** Fondations du design system : prérequis de tout nouvel écran, sans
  dépendance fonctionnelle. Les lots 7 et 8 ont été livrés avant lui : les
  écrans qu'ils ont touchés (fiche élève, séance suggérée) seront repris par
  U9 et U8, qui absorbent cette reprise.
- **U2** Lisibilité des schémas : court, sans dépendance, au cœur de la
  précision pédagogique.

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
   - **U5** Saisie rapide en grille, en tête de H1 : la saisie est l'action la
     plus fréquente de la saison ; sa grille rend le lien séance ↔ saisie du
     lot 6 utilisable en salle. Dépend de U1.
7. ~~Positionnement initial / bloc acquis~~ : marquer un bloc comme acquis sans
   passage (élèves non débutants, rentrée) ; sinon la suggestion repart de
   « posture » et la fiche affiche « 0 / 72 » toute la saison. **Livré le
   2026-10-14** — [ADR 0008](adr/0008-positionnement-initial-bloc-acquis.md),
   [plan](positionnement-initial-plan.md). Décisions : action sur la fiche élève
   par bloc, état distinct stocké (date + source « positionnement », pas de
   passage fictif), bloc entier (15 blocs), compté dans « n / 72 » et saute
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
   - **U6** Navigation recentrée, ensuite : « Aujourd'hui / Élèves /
     Résultats / Séances / Plus » ; à livrer avant le lot 9, qui prend place
     sous « Plus ». Dépend de U1.
9. **Réglages** (F8) : écran persisté (drift + sauvegarde) pour
   `passesRequired`, seuil d'alerte, `recallStaleSessions`, part d'échec du
   groupe ; sous la destination « Plus » (U6), pas de sixième onglet.
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

16. Workflow de validation des `[Prop]` : 18 séances sur 29 « à valider »,
    12 jeux adaptés ; marque « relu » persistante (point ouvert n° 1 du plan
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
H0 : U1 → U2 → F7 → revue T8 → réaliser D5 (les questions ouvertes sont tranchées)
H1 : U5 → U6 → 9 → U7 → 10 + U9 + U8 → 11   (5 à 8 livrés)
H2 : U4 → U3 → 14 → 15
H3 : 16 (avec le mode Relecture de U4) → 17 → 18 → 19 → 20
H4 : 21 → 22 (+ rappels) → 23
```

U1 d'abord parce que tout en dépend et qu'il n'a aucune dépendance ; U5 tôt
parce que la saisie est l'action quotidienne et que le lot 6 (livré) lui
fournit groupe, date et séance du catalogue ; les lots 7 et 8 sont livrés
(ADR 0008 et 0009), U7 a donc déjà toutes les données qu'il affiche et U8
son marqueur de parcours ; U4 et U3 avant la première séance réelle en
salle.
