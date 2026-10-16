# Lot 11a (ADR 0019), domaine : déplacer un élève d'un groupe à un autre du
# même public et de la même saison. L'appartenance d'origine est close la
# veille de la date d'effet, l'autre s'ouvre ce jour-là ; rien n'est copié :
# les passages suivent l'élève, les présences restent aux séances. « Aujourd'hui »
# est le 2026-10-12.
Feature: Déplacer un élève de groupe

  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And je crée le groupe {'Mercredi'} de public {'enfants'}

  Scenario: Le déplacement prend effet à la date choisie
    When je déplace {'Léa'} vers le groupe {'Mercredi'} le {'2026-10-12'}
    Then les membres du groupe {'Jeunes'} le {'2026-10-11'} sont {'Léa, Théo'}
    And les membres du groupe {'Jeunes'} le {'2026-10-12'} sont {'Théo'}
    And les membres du groupe {'Mercredi'} le {'2026-10-11'} sont {''}
    And les membres du groupe {'Mercredi'} le {'2026-10-12'} sont {'Léa'}

  Scenario: Le parcours de l'élève est identique avant et après
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    When je déplace {'Léa'} vers le groupe {'Mercredi'} le {'2026-10-12'}
    And j'ouvre la fiche de {'Léa'}
    Then {'Léa'} conserve {3} passages enregistrés
    And le club garde {1} acquittements en tout
    And l'en-tête n'a aucune alerte

  Scenario: L'assiduité de l'ancien groupe garde le passé, le nouveau compte à partir de la date
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo'}
    When je déplace {'Léa'} vers le groupe {'Mercredi'} le {'2026-10-08'}
    And une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-09'} avec {'Théo'}
    And une séance du groupe {'Mercredi'} a eu lieu le {'2026-10-10'} avec {'Léa'}
    And j'ouvre la grille du groupe {'Jeunes'}
    Then l'assiduité du groupe est de {3} présences sur {3} possibles en {2} séances
    When j'ouvre la grille du groupe {'Mercredi'}
    Then l'assiduité du groupe est de {1} présences sur {1} possibles en {1} séances

  Scenario: Une date antérieure à la dernière présence dans l'ancien groupe est refusée
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-08'} avec {'Léa'}
    When j'essaie de déplacer {'Léa'} vers le groupe {'Mercredi'} le {'2026-10-08'}
    Then l'opération sur les groupes est refusée avec le motif {'moveBeforeLastPresence'}
    And les membres du groupe {'Jeunes'} le {'2026-10-12'} sont {'Léa, Théo'}

  Scenario: Déplacer vers un groupe d'un autre public est refusé
    Given je crée le groupe {'Soir'} de public {'adultes'}
    When j'essaie de déplacer {'Léa'} vers le groupe {'Soir'} le {'2026-10-12'}
    Then l'opération sur les groupes est refusée avec le motif {'audienceMismatch'}
    And les membres du groupe {'Jeunes'} le {'2026-10-12'} sont {'Léa, Théo'}

  Scenario: Une saisie du jour du déplacement propose l'élève dans le groupe où il est membre
    When je déplace {'Léa'} vers le groupe {'Mercredi'} le {'2026-10-12'}
    And une séance du groupe {'Mercredi'} a eu lieu le {'2026-10-12'} avec {'Léa'}
    Then la saisie du groupe {'Jeunes'} le {'2026-10-12'} avec {'Léa'} est refusée avec le motif {'studentNotInGroup'}

  Scenario: Déplacer vers le groupe où l'élève est déjà membre est refusé
    When j'essaie de déplacer {'Léa'} vers le groupe {'Jeunes'} le {'2026-10-12'}
    Then l'opération sur les groupes est refusée avec le motif {'membershipAlreadyOpen'}

  Scenario: Un élève qui n'appartient plus à aucun groupe est replacé dans le groupe choisi
    Given {'Théo'} quitte le groupe {'Jeunes'} le {'2026-10-05'}
    When je déplace {'Théo'} vers le groupe {'Mercredi'} le {'2026-10-12'}
    Then les membres du groupe {'Mercredi'} le {'2026-10-12'} sont {'Théo'}
    And les membres du groupe {'Jeunes'} le {'2026-10-12'} sont {'Léa'}
