# ADR 0003 — Suivi des élèves : domaine pur et règles déterministes

- Statut : accepté (2026-10-11), d'après `research/suivi-eleves-domaine.md` ; domaine implémenté (2026-10-12), sans interface ni persistance.
- Décision :
  1. Domaine en **Dart pur** : catalogue (YAML versionné), élèves, groupes, saisons, séances, passages, bilans de maturité.
  2. Règles = **fonctions pures** (exercice suivant, alerte 3 échecs consécutifs, notion à rappeler, séance suggérée 90/120 min). Les seuils sont de la **configuration**, pas des constantes.
  3. Le changement de public (enfants → adultes) est **toujours manuel** `[U]` ; le bilan de maturité n'est qu'une aide.
  4. Le catalogue est copié depuis `docs/knowledge/03-exercices/catalogue-entrainement.yaml` vers un asset de l'app par script ; un contrôle déterministe vérifie l'égalité (source unique de vérité = `docs/knowledge`).
- **Tranché par l'animateur `[U]` (2026-10-11)** :
  - Un exercice est validé après **plusieurs passages réussis, 5 le plus souvent** (`passesRequired`, défaut 5, réglable) ; un seul passage ne suffit pas. Les scénarios BDD 3, 4 et 6 de `research/suivi-eleves-domaine.md` supposaient 1 passage : ils sont à réécrire avec 5.
  - Ordre d'enseignement : **rebond sur bande puis rejet naturel** (`teaching_order` du catalogue).
- Reste à faire trancher : unité « séance » des nombres conseillés (une séance de groupe = 90 ou 120 min ?).

## Mise en œuvre (2026-10-12)

- Placement FSD : entités `exercise_catalog`, `exercise_result`, `student`, `season`, `group`, `session_record`, `maturity_assessment` ; features `record_results`, `suggest_session`, `assess_maturity`, `change_audience`, `track_progress` ; noyau partagé Dart pur dans `shared/lib` (voir `architecture.md`).
- Écart assumé : les passages (`ExerciseAttempt`) sont stockés à part de `SessionRecord` (ils portent `sessionId`) ; le plafond de 2 passages par exercice et par séance est vérifié par `RecordAttempt`.
- Non implémenté : acquittement explicite d'une alerte, `birthYear` facultatif (données minimales), note de jeu de la séance, vues de groupe (carte de chaleur, assiduité).
- La persistance drift et le test de contrat commun aux implémentations de repository sont en place (ADR 0001, `test/contract/`).
