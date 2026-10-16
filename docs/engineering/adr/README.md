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
| 0012 | Réglages du club : `RulesConfig` lu à la valeur courante (fabrique + `RulesStore`), table `app_settings` (schéma v7), réglages dans la sauvegarde (format v2) ; accepté |
| 0013 | Acquittement d'une alerte (« Vu ») : entité liée au dernier passage de l'exercice, table `alert_acknowledgements` (schéma v8), sauvegarde v3 ; masque la surveillance, pas le rappel ; accepté (domaine, persistance et interface livrés) |
| 0014 | Fiche en parcours (cases, en-tête, courbes repliées, menu de positionnement), vue « à montrer à l'élève » hors du cadre de navigation (garantie de type), vue de groupe (carte de chaleur doublée d'alternatives textuelles, assiduité, alertes de groupe) ; accepté et livré |
| 0015 | Guide en mode « Mener » : route de premier niveau (ni rail ni barre en séance), modes Mener / Relecture (état du cubit reflété dans `?mode=`, provenance toujours accessible), origine directe `from` et origine du détail `via`, `group` conservé de bout en bout (solde de U-9) ; accepté |
| 0016 | Identité d'une saisie par (groupe, jour, séance du catalogue) : corrige le lien dérivé planifiée ↔ saisie sans migration ; accepté |

Recherches sources : `../research/`.
