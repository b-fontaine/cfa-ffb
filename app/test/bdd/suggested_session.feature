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
