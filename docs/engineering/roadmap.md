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
| F1 | En présentation, la légende du bas est tronquée à 1280 × 800 | `pages/sheet_presentation` |
| F2 | Diagramme bille fantôme : l'étiquette « Bille fantôme » chevauche la ligne de visée et la bille ; le cercle fantôme disparaît sous la pointe de flèche | `shared/ui/ghost_aim_diagram`, `table_diagram` |
| F3 | Guide : l'en-tête (titre, public, thème, barre d'étape, minuteur, boutons) occupe ~45 % de l'écran desktop et ~60 % sur mobile ; le schéma d'exercice est sous la ligne de flottaison | `pages/sheet_guide` |
| F4 | Saisie : le sélecteur d'exercice est un bouton sans libellé accessible | `pages/record_session` |
| F5 | ~~Onglet « Résultats » : aucun historique des séances saisies ; impossible de relire, corriger ou supprimer un passage~~ — corrigé (ADR 0006) | `pages/record_history` |
| F6 | Séance planifiée sans date ni groupe, non liée à la saisie (décision 10 de l'ADR 0004, assumée mais visible) | `pages/session_planner` |
| F7 | Séance suggérée : « Pas de rappel » pour les enfants (`recallCount = 0`, voulu) alors que la fiche élève affiche une notion à rappeler ; rien ne l'explique à l'écran | `pages/suggested_session` |
| F8 | Les seuils (`passesRequired`, alertes, `recallStaleSessions`) sont dans `RulesConfig.standard()` sans écran de réglages | `app/di` |

## H0 — Clore ce qui est ouvert

1. Lot L8 « finition » de l'ADR 0004 (seul lot non livré) : accessibilité (F4),
   tablette paysage (F3), `check.sh --fast` en `--complete`, docs
   (`progression-par-cycles.md`, glossaire).
2. Revue T8 du plan tailles et illustrations : `architecte-fsd`, `testeur-bdd`,
   `relecteur-pedagogique`, dans un contexte séparé.
3. Corriger F1, F2 et F7 (un texte « pas de rappel : une notion par séance
   enfants »).
4. Faire trancher par l'animateur : D2 (ligne de départ 2,0 ou 1,6), D5
   (`contact_height`), unité « séance » des nombres conseillés, dimensionnement
   groupes / saison (questions 2 à 4 de `docs/knowledge/08-lacunes-et-questions-ouvertes.md`).

## H1 — La boucle de saison complète (priorité)

5. ~~Historique des séances saisies~~ (F5) : **livré le 2026-10-14** —
   [ADR 0006](adr/0006-historique-et-correction-des-passages.md),
   [plan](historique-seances-plan.md). Reste l'assiduité **du groupe** (lot 10).
6. **Lier séance planifiée ↔ saisie ↔ séance du catalogue** (lot L9 de l'ADR
   0004) : date et groupe sur la séance planifiée ; « Lancer » ouvre la saisie
   déjà renseignée ; la saisie sait quelle séance du catalogue elle note.
7. **Positionnement initial / bloc acquis** : marquer un bloc comme acquis sans
   passage (élèves non débutants, rentrée) ; sinon la suggestion repart de
   « posture » et la fiche affiche « 0 / 72 » toute la saison.
8. **Suggestion ↔ catalogue** : la séance suggérée pointe un bloc ; elle doit
   proposer la séance du catalogue correspondante (partie suivante non faite
   par le groupe).
9. **Réglages** (F8) : écran persisté (drift + sauvegarde) pour
   `passesRequired`, seuil d'alerte, `recallStaleSessions`, part d'échec du
   groupe.
10. Reste de l'ADR 0003 : acquittement d'une alerte, note de jeu de la séance,
    vues de groupe (carte de chaleur bloc × élève, assiduité), compteurs
    d'initiation et de jeu persistés.
11. **Saisons et groupes** : clôture de saison (archiver, effacer les mineurs en
    lot), plusieurs groupes par public, déplacer un élève de groupe.

## H2 — Usage en salle

12. Guide : en-tête repliable ou compact en séance (F3), schéma en premier,
    deux colonnes en tablette paysage.
13. Présentation : l'étape complète (consigne + schéma) en plein écran, zoom sur
    le diagramme, légende jamais tronquée (F1).
14. Impression / export PDF d'une séance du catalogue (feuille de l'animateur,
    fiche résultats papier identique au PDF fédéral).
15. Hors-ligne : vérifier le PWA (service worker, sqlite3.wasm / OPFS) sans
    réseau ; installation sur l'écran d'accueil.

## H3 — Contenu et connaissances

16. Workflow de validation des `[Prop]` : 18 séances sur 29 « à valider »,
    12 jeux adaptés ; marque « relu » persistante (point ouvert n° 1 du plan
    catalogue) ou export des remarques de l'animateur vers le YAML.
17. Validation des diagrammes par l'animateur (lecture ≈ 0,15 case, jamais
    contrôlée) : mode « comparer au PDF page N ».
18. Ingérer les règles officielles du Blackball (FFB / WPA) et le contenu du
    billard de bronze.
19. Compléments `[Prop]` à sourcer : échauffement, sécurité, matériel enfant,
    les six techniques sans jeu `[S]`.
20. Niveaux techniques 2 et 3 : en attente des PDF.

## H4 — Technique et distribution

21. Déploiement web depuis la CI (le build existe dans `ci.yml`, il n'est pas
    publié) ; build Android signé (plateforme prioritaire).
22. Synchronisation multi-appareils (Firebase derrière les repositories, ADR
    0001) seulement si la question ouverte n° 4 est tranchée « oui » ; sinon
    rappel périodique de sauvegarde et export en fin de séance.
23. Dette : `scripts/` sans `pubspec.yaml`, build `--wasm`, mutation testing
    retiré (à réévaluer).

## Ordre recommandé

6 → 7 (le lot 5 est livré ; sans lien planifié / saisi / catalogue ni
positionnement initial, le suivi ne tient pas une saison), H0 en parallèle par
petits lots (dont la revue T8), puis 12 et 13 avant la première séance réelle
en salle.
