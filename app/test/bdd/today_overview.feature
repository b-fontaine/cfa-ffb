Feature: Aujourd'hui, ce que l'animateur doit savoir à l'ouverture

  # Lot U7 (domaine) : la prochaine séance, les séances à noter, les élèves à
  # surveiller, la semaine et la séance guidée en cours. « Aujourd'hui » est le
  # 2026-10-12 (un lundi).
  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}

  Scenario: Sans séance planifiée, aucune séance n'est à venir
    When j'ouvre l'accueil du jour
    Then aucune séance n'est à venir
    And aucune séance n'est à noter

  Scenario: La prochaine séance est la première planifiée à partir d'aujourd'hui
    Given la séance {'posture-2'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-21'}
    And la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-14'}
    When j'ouvre l'accueil du jour
    Then la prochaine séance est {'posture-1'} le {'2026-10-14'}

  Scenario: Une séance planifiée aujourd'hui sans saisie est la prochaine
    Given la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-12'}
    When j'ouvre l'accueil du jour
    Then la prochaine séance est {'posture-1'} le {'2026-10-12'}

  Scenario: Une séance d'aujourd'hui déjà saisie n'est plus proposée
    Given la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-12'}
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When j'ouvre l'accueil du jour
    Then aucune séance n'est à venir

  Scenario: Les autres séances du même jour sont comptées
    Given la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-14'}
    And la séance {'posture-2'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-14'}
    When j'ouvre l'accueil du jour
    Then la prochaine séance est {'posture-1'} le {'2026-10-14'}
    And {1} autre séance a lieu le même jour

  Scenario: Une séance passée sans saisie des 7 derniers jours est à noter
    Given la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-08'}
    When j'ouvre l'accueil du jour
    Then aucune séance n'est à venir
    And la séance {'posture-1'} est à noter

  Scenario: Une séance passée il y a 7 jours est encore à noter, 8 jours non
    Given la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-05'}
    And la séance {'posture-2'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-04'}
    When j'ouvre l'accueil du jour
    Then la séance {'posture-1'} est à noter
    And la séance {'posture-2'} n'est pas à noter

  Scenario: Une séance passée déjà saisie n'est pas à noter
    Given la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-08'}
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-08'}
    When j'ouvre l'accueil du jour
    Then aucune séance n'est à noter

  Scenario: Aucun élève n'est à surveiller sans échecs consécutifs
    Given {'Léa'} a échoué {2} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre l'accueil du jour
    Then aucun élève n'est à surveiller

  Scenario: Trois échecs consécutifs mettent un élève à surveiller
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre l'accueil du jour
    Then {'Léa'} est à surveiller pour {'posture 1'} avec {3} échecs de suite au niveau {'attention'}

  Scenario: Cinq échecs consécutifs sont une alerte persistante
    Given {'Léa'} a échoué {5} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre l'accueil du jour
    Then {'Léa'} est à surveiller pour {'posture 1'} avec {5} échecs de suite au niveau {'persistante'}

  Scenario: Les alertes persistantes précèdent les alertes d'attention
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And {'Théo'} a échoué {5} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre l'accueil du jour
    Then les élèves à surveiller sont {'Théo, Léa'}

  Scenario: Un élève n'a qu'une ligne, avec ses autres alertes comptées
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And {'Léa'} a échoué {4} passages sur {'posture 2'} lors de séances précédentes
    When j'ouvre l'accueil du jour
    Then les élèves à surveiller sont {'Léa'}
    And {'Léa'} est à surveiller pour {'posture 2'} avec {4} échecs de suite au niveau {'attention'}
    And {'Léa'} a {1} autre alerte

  Scenario: Un exercice validé ne donne plus d'alerte
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre l'accueil du jour
    Then aucun élève n'est à surveiller

  Scenario: Un bloc acquis au positionnement masque l'alerte
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-10-10'}
    When j'ouvre l'accueil du jour
    Then aucun élève n'est à surveiller

  Scenario: Les 7 derniers jours comptent les passages saisis
    Given {'Léa'} a réussi {2} passages sur {'posture 1'} le {'2026-10-10'}
    And {'Théo'} a réussi {1} passages sur {'posture 2'} le {'2026-10-12'}
    When j'ouvre l'accueil du jour
    Then la semaine compte {3} passages, {0} validations et {2} séances

  Scenario: Le sixième jour précédent est dans la semaine, le septième non
    Given {'Léa'} a réussi {1} passages sur {'posture 1'} le {'2026-10-06'}
    And {'Léa'} a réussi {1} passages sur {'posture 1'} le {'2026-10-05'}
    When j'ouvre l'accueil du jour
    Then la semaine compte {1} passages, {0} validations et {1} séances

  Scenario: Une validation obtenue pendant la semaine est comptée
    Given {'Léa'} a réussi {4} passages sur {'posture 1'} lors de séances précédentes
    And {'Léa'} a réussi {1} passages sur {'posture 1'} le {'2026-10-09'}
    When j'ouvre l'accueil du jour
    Then la semaine compte {1} passages, {1} validations et {1} séances

  Scenario: Une validation plus ancienne n'est pas comptée
    Given {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    And {'Léa'} a réussi {1} passages sur {'posture 1'} le {'2026-10-09'}
    When j'ouvre l'accueil du jour
    Then la semaine compte {1} passages, {0} validations et {1} séances

  Scenario: Une séance guidée avec de la progression est en cours
    Given la séance guidée {'posture-1'} est commencée à l'étape {2}
    When j'ouvre l'accueil du jour
    Then la séance en cours est {'posture-1'} à l'étape {2}

  Scenario: Une séance guidée sans progression n'est pas en cours
    Given la séance guidée {'posture-1'} est commencée à l'étape {0}
    When j'ouvre l'accueil du jour
    Then aucune séance n'est en cours

  Scenario: Une séance guidée terminée n'est plus en cours
    Given la séance guidée {'posture-1'} est commencée à l'étape {2}
    And la séance guidée {'posture-1'} est terminée
    When j'ouvre l'accueil du jour
    Then aucune séance n'est en cours
