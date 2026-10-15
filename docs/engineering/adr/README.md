# Décisions d'architecture (ADR)

| N° | Décision |
|----|----------|
| 0001 | Persistance locale drift ; Firebase plus tard |
| 0002 | Design system : Widgetbook 3.x séparé, thème FFB/Blackball |
| 0003 | Suivi des élèves : domaine pur, règles déterministes |
| 0004 | Catalogue de séances (14 techniques, 28 séances), blocs d'entraînement `[Prop]` ajoutés, lecture seule, lancement guidé |
| 0005 | Illustrations du joueur (personnage), de la cible sur la blanche et du dosage (plan amplitude × vitesse) |
| 0006 | Historique des séances saisies (`/record`), formulaire en `/record/new`, correction en place et suppression renumérotée des passages, assiduité |
| 0007 | Séance planifiée datée et par groupe, saisie qui note sa séance du catalogue, lien planifiée ↔ saisie dérivé (même groupe, même jour), schéma v4 |
| 0008 | Positionnement initial : bloc acquis sans passage (état distinct stocké, compté dans n/72, saute la suggestion, réversible), schéma v5 (livré) |
| 0009 | Suggestion ↔ catalogue : séance du catalogue proposée depuis la suggestion (règle déterministe, aucune migration), **accepté et livré**, arbitrages S1 à S8 intégrés |
| 0010 | Rôles de couleur : bleu-tapis pour les états (`secondary`), rouge FFB en accent (`BrandColors`), `SectionCard.emphasis`, logo FFB derrière un drapeau de thème, icônes de navigation dédiées ; amende l'ADR 0002 décision 2 |
| 0011 | Créneau d'exercice de rappel : à partir de la 2e séance, un emplacement d'entraînement dont l'exercice est choisi à l'exécution parmi les séances précédentes d'après le suivi des élèves (décision 7 `[U]` du 2026-10-15) |

Recherches sources : `../research/`.
