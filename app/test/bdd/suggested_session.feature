Feature: Séance suggérée

  Background:
    Given le club suit la saison {'2026-2027'}

  Scenario: Séance suggérée enfants
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Hugo'}
    And {'Léa, Théo'} ont validé tous les exercices avant {'demi-bille 2'}
    And {'Hugo'} a validé tous les exercices avant {'puissance 3'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa, Théo, Hugo'}
    Then la durée de la séance est de {90} minutes
    And la somme des phases est de {90} minutes
    And la notion principale est {'demi-bille'} avec {2} exercices distincts
    And le premier exercice est {'demi-bille 2'}

  Scenario: Séance adultes avec rappel
    Given le groupe {'Adultes'} de public {'adultes'} compte l'élève {'Marc'}
    And le groupe {'Adultes'} de public {'adultes'} compte l'élève {'Sophie'}
    And {'Marc, Sophie'} ont validé tous les exercices avant {'trois-quarts 1'}
    And {'Marc, Sophie'} ont obtenu {5} sur {8} à {'bille-pleine 3'} au dernier passage
    When je demande la séance suggérée du groupe {'Adultes'} pour {'Marc, Sophie'}
    Then la durée de la séance est de {120} minutes
    And la notion à rappeler est {'bille-pleine'}
    And aucun exercice n'est prévu plus de {2} fois

  # Lot 7 (ADR 0008) : un bloc acquis au positionnement est sauté, l'ordre
  # d'enseignement du reste est inchangé.
  Scenario: Un bloc acquis au positionnement par tout le groupe est sauté
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And {'Léa, Théo'} ont le bloc {'posture'} acquis au positionnement le {'2026-09-30'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa, Théo'}
    Then la notion principale est {'puissance'} avec {2} exercices distincts
    And le premier exercice est {'puissance 1'}

  Scenario: Un bloc acquis par un seul élève du groupe n'est pas sauté
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-09-30'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa, Théo'}
    Then la notion principale est {'posture'} avec {2} exercices distincts
    And le premier exercice est {'posture 1'}

  Scenario: Le rebond sur bande précède le rejet naturel
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'rebond-bande 1'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la notion principale est {'rebond-bande'} avec {2} exercices distincts

  Scenario: Le bloc rebond sur bande acquis, le rejet naturel suit
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'rebond-bande 1'}
    And {'Léa'} a le bloc {'rebond-bande'} acquis au positionnement le {'2026-09-30'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la notion principale est {'rejet-naturel'} avec {2} exercices distincts

  # Lot 8 (ADR 0009) : la séance suggérée propose la séance du catalogue
  # correspondante. « Donnée » = saisie du groupe avec séance du catalogue et
  # au moins un passage, datée d'aujourd'hui (le 2026-10-12) ou avant.
  Scenario: Sans séance donnée, la suggestion propose la partie 1
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'posture-1'}
    And la raison de la proposition est {'exercice de tête'}

  Scenario: Le public ne change pas la séance proposée
    Given le groupe {'Adultes'} de public {'adultes'} compte l'élève {'Marc'}
    When je demande la séance suggérée du groupe {'Adultes'} pour {'Marc'}
    Then la séance du catalogue proposée est {'posture-1'}
    And la durée de la séance est de {120} minutes

  Scenario: Une partie déjà donnée n'est pas reproposée
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-05'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'posture-2'}
    And la raison de la proposition est {'partie suivante'}
    And l'exercice de tête {'posture 1'} n'est pas dans la séance proposée
    And les exercices proposés sont {'posture 3, posture 4'}

  Scenario: Une partie sautée est reproposée
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'coule 1'}
    And la séance {'coule-2'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-05'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'coule-1'}
    And la raison de la proposition est {'exercice de tête'}

  # S1 (discriminant) : Léa et Hugo ont validé 1 à 4 de coule, Théo seulement
  # le 4. L'exercice de tête vaut 5 ; coule-1 n'est pas sans objet (Théo n'a
  # pas validé 1 à 3) mais ne contient pas la tête.
  Scenario: L'exercice de tête décide de la séance proposée
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Hugo'}
    And {'Léa, Hugo'} ont validé tous les exercices avant {'coule 5'}
    And {'Théo'} a validé tous les exercices avant {'coule 1'}
    And {'Théo'} a réussi {5} passages sur {'coule 4'} lors de séances précédentes
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa, Théo, Hugo'}
    Then la notion principale est {'coule'} avec {2} exercices distincts
    And le premier exercice est {'coule 5'}
    And la séance du catalogue proposée est {'coule-2'}
    And la raison de la proposition est {'exercice de tête'}

  Scenario: Toutes les parties faites, la partie de la tête est redonnée
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'coule 5'}
    And la séance {'coule-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-01'}
    And la séance {'coule-2'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-05'}
    And la séance {'coule-3'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-08'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'coule-2'}
    And la raison de la proposition est {'déjà donnée'}
    And la séance proposée a été donnée le {'2026-10-05'}

  Scenario: Plusieurs saisies pour une même partie, la plus récente date la partie
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'coule 5'}
    And la séance {'coule-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-01'}
    And la séance {'coule-2'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-03'}
    And la séance {'coule-2'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-09'}
    And la séance {'coule-3'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-08'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'coule-2'}
    And la séance proposée a été donnée le {'2026-10-09'}

  Scenario: Une partie dont tous les exercices sont validés est sautée
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'coule 5'}
    And la séance {'coule-2'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-05'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'coule-3'}
    And la raison de la proposition est {'partie suivante'}
    And l'exercice de tête {'coule 5'} n'est pas dans la séance proposée
    And les exercices proposés sont {'coule 7, coule 8'}

  Scenario: Une saisie sans séance du catalogue ne compte pas
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And une saisie du groupe {'Jeunes'} le {'2026-10-05'} sans séance du catalogue compte un passage
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'posture-1'}
    And la raison de la proposition est {'exercice de tête'}

  Scenario: Une saisie ouverte sans passage ne compte pas
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance {'posture-1'} du catalogue est ouverte au groupe {'Jeunes'} le {'2026-10-05'} sans passage
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'posture-1'}

  Scenario: Une saisie reprise le même jour avec une autre séance sans passage ne compte pas
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance {'posture-1'} du catalogue est ouverte au groupe {'Jeunes'} le {'2026-10-05'} sans passage
    And la saisie du groupe {'Jeunes'} du {'2026-10-05'} est reprise avec la séance {'posture-2'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'posture-1'}

  Scenario: Une saisie datée du futur ne compte pas
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-20'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'posture-1'}

  Scenario: Une séance planifiée non saisie ne compte pas
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-05'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'posture-1'}

  Scenario: Un identifiant de séance inconnu du catalogue est ignoré
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And une saisie du groupe {'Jeunes'} le {'2026-10-05'} compte un passage avec la séance inconnue {'inconnue-9'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'posture-1'}

  Scenario: Le rappel suggéré prime sur le rappel dérivé de la séance donnée
    Given le groupe {'Adultes'} de public {'adultes'} compte l'élève {'Marc'}
    And le groupe {'Adultes'} de public {'adultes'} compte l'élève {'Sophie'}
    And {'Marc, Sophie'} ont validé tous les exercices avant {'trois-quarts 1'}
    And {'Marc, Sophie'} ont obtenu {5} sur {8} à {'bille-pleine 3'} au dernier passage
    And la séance {'trois-quarts-1'} du catalogue a été donnée au groupe {'Adultes'} le {'2026-10-05'}
    When je demande la séance suggérée du groupe {'Adultes'} pour {'Marc, Sophie'}
    Then la séance du catalogue proposée est {'trois-quarts-2'}
    And la notion à rappeler est {'bille-pleine'}

  Scenario: Le bloc partagé quart-finesses commence par la séance quart
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'quart-finesses 1'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'quart-1'}

  Scenario: Le bloc partagé quart-finesses continue par la séance finesse
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'quart-finesses 1'}
    And la séance {'quart-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-05'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la séance du catalogue proposée est {'finesse-1'}
    And la raison de la proposition est {'partie suivante'}

  Scenario: Un bloc acquis par tout le groupe n'est pas proposé
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And {'Léa, Théo'} ont le bloc {'posture'} acquis au positionnement le {'2026-09-30'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa, Théo'}
    Then la séance du catalogue proposée est {'puissance-1'}

  # S8 : bloc sans séance du catalogue (cas nominal, teaching_order 8).
  Scenario: Un bloc sans séance du catalogue ne propose aucune séance
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'quantites-de-billes 1'}
    When je demande la séance suggérée du groupe {'Jeunes'} pour {'Léa'}
    Then la notion principale est {'quantites-de-billes'} avec {2} exercices distincts
    And aucune séance du catalogue n'est proposée
