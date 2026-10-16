Feature: Bilan de fin de séance

  # Lot U7 (domaine) : ce que la séance donnée a produit, et la séance
  # suivante proposée puis planifiée pour le groupe. « Aujourd'hui » est le
  # 2026-10-12 (un lundi).
  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}

  Scenario: Le bilan nomme la séance, le groupe, la date et les présents
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande le bilan de la dernière saisie
    Then le bilan porte sur la séance {'posture-1'} du groupe {'Jeunes'} le {'2026-10-12'} avec {2} présents

  Scenario: Le bilan compte les passages saisis par exercice
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande le bilan de la dernière saisie
    Then le bilan compte {1} passages dont {1} réussis
    And le bilan compte {1} passages dont {1} réussis pour {'posture 1'}

  Scenario: Un exercice validé par cette saisie est listé avec l'élève
    Given {'Léa'} a réussi {4} passages sur {'posture 1'} lors de séances précédentes
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande le bilan de la dernière saisie
    Then {'Léa'} a validé {'posture 1'} grâce à cette séance

  Scenario: Un exercice validé lors d'une séance précédente n'est pas listé
    Given {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande le bilan de la dernière saisie
    Then le bilan ne compte aucune validation

  Scenario: Les présents sans passage sont nommés
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande le bilan de la dernière saisie
    Then les présents sans passage sont {'Théo'}

  Scenario: Les présents ayant une alerte active sont à surveiller
    Given {'Théo'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande le bilan de la dernière saisie
    Then {'Théo'} est à surveiller dans le bilan pour {'posture 1'}

  Scenario: Les ex aequo sont dans le même ordre à l'accueil et au bilan
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Zoé'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'alex'}
    And {'Zoé'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And {'alex'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When j'ouvre l'accueil du jour
    And je demande le bilan de la dernière saisie
    Then les élèves à surveiller sont {'Zoé, alex'}
    And les élèves à surveiller du bilan sont {'Zoé, alex'}

  Scenario: Une saisie sans passage n'a ni passages ni validations
    Given la séance {'posture-1'} du catalogue est ouverte au groupe {'Jeunes'} le {'2026-10-12'} sans passage
    When je demande le bilan de la dernière saisie
    Then le bilan compte {0} passages dont {0} réussis
    And les présents sans passage sont {'Léa, Théo'}

  Scenario: Une saisie inconnue n'a pas de bilan
    When je demande le bilan de la saisie {'inconnue'}
    Then le bilan est refusé car la séance est introuvable

  Scenario: La séance suivante du catalogue est la partie qui suit
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande la séance suivante du bilan
    Then la séance suivante proposée est {'posture-2'}

  Scenario: La date proposée est le même jour de la semaine, la semaine suivante
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande le bilan de la dernière saisie
    Then la date proposée est le {'2026-10-19'}

  Scenario: Une date passée est avancée au prochain même jour de la semaine
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-05'}
    When je demande le bilan de la dernière saisie
    Then la date proposée est le {'2026-10-19'}

  Scenario: Planifier crée une séance datée pour le groupe
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande la séance suivante du bilan
    And je planifie la séance suivante le {'2026-10-19'}
    Then la séance {'posture-2'} figure dans les séances planifiées du groupe {'Jeunes'} le {'2026-10-19'}

  Scenario: Une séance déjà planifiée est reconnue dans le bilan
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    And la séance {'posture-2'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-19'}
    When je demande le bilan de la dernière saisie
    Then la séance {'posture-2'} est déjà planifiée le {'2026-10-19'}

  Scenario: Une date après la fin de la saison est refusée
    Given la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When je demande la séance suivante du bilan
    And je planifie la séance suivante le {'2027-07-05'}
    Then la planification est refusée car la date est hors saison
