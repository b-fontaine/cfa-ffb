# Lot 11b (ADR 0019), domaine et persistance : clore une saison. L'archive est
# calculée avant l'effacement et ne nomme personne ; les élèves choisis sont
# effacés physiquement, les autres reconduits dans la saison suivante ; une
# saison close refuse toute nouvelle saisie ; la sauvegarde 4 porte la clôture
# et l'archive. « Aujourd'hui » est le 2026-10-12.
Feature: Clôture de saison

  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Hugo'}

  Scenario: Les propositions suivent l'activité et la durée de conservation
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo'}
    And {'Ana'} est inscrite au groupe {'Jeunes'} depuis le {'2025-09-15'}
    And une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-06'} avec {'Ana'}
    When je prépare la clôture de la saison
    Then la proposition pour {'Léa'} est de {'keep'} pour le motif {'carriedOver'}
    And la proposition pour {'Hugo'} est de {'erase'} pour le motif {'inactive'}
    And la proposition pour {'Ana'} est de {'erase'} pour le motif {'retentionExpired'}

  Scenario: Un élève qu'aucun groupe ne place est proposé à l'effacement
    Given {'Zoé'} est inscrite au club sans aucun groupe
    When je prépare la clôture de la saison
    Then la proposition pour {'Zoé'} est de {'erase'} pour le motif {'inactive'}
    And la proposition pour {'Léa'} est de {'erase'} pour le motif {'inactive'}

  Scenario: Les élèves effacés n'existent plus nulle part et l'archive ne nomme personne
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo, Hugo'}
    When je clos la saison le {'2026-10-12'} en effaçant {'Hugo'}
    Then {'Hugo'} n'existe plus nulle part
    And les présents de la séance du groupe {'Jeunes'} le {'2026-10-05'} sont {'Léa, Théo'}
    And l'archive ne nomme ni {'Léa, Théo, Hugo'}
    And la clôture a effacé {1} élèves et reconduit {2}

  Scenario: Les élèves reconduits gardent leur parcours et rejoignent la saison suivante
    Given {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    When je clos la saison le {'2026-10-12'} en effaçant {'Hugo'}
    Then {'Léa'} conserve {5} passages enregistrés
    And {'Léa'} est membre du groupe {'Jeunes'} de la saison suivante
    And {'Théo'} est membre du groupe {'Jeunes'} de la saison suivante
    And {'Hugo'} n'existe plus nulle part

  Scenario: L'archive donne les chiffres par public et ne détaille un exercice qu'à partir de trois élèves
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo, Hugo'}
    And {'Léa'} a réussi {1} passages sur {'posture 1'} lors de séances précédentes
    And {'Théo'} a réussi {1} passages sur {'posture 1'} lors de séances précédentes
    When je clos la saison le {'2026-10-12'} en effaçant {'Hugo'}
    Then l'archive de la saison compte {3} séances, {5} présences et {2} passages pour les {'enfants'}
    And l'archive de la saison compte {0} lignes d'exercice

  Scenario: Avec trois élèves distincts, l'exercice a sa ligne
    Given {'Léa'} a réussi {1} passages sur {'posture 1'} lors de séances précédentes
    And {'Théo'} a réussi {1} passages sur {'posture 1'} lors de séances précédentes
    And {'Hugo'} a réussi {1} passages sur {'posture 1'} lors de séances précédentes
    When je clos la saison le {'2026-10-12'} en effaçant {'Hugo'}
    Then l'archive de la saison compte {1} lignes d'exercice

  Scenario: Une saison close refuse la saisie, la planification, et l'inscription ouvre la saison suivante
    When je clos la saison le {'2026-10-12'} en effaçant {''}
    Then la saisie du groupe {'Jeunes'} le {'2026-10-12'} avec {''} est refusée avec le motif {'seasonClosed'}
    And la planification pour le groupe {'Jeunes'} le {'2026-10-12'} est refusée avec le motif {'seasonClosed'}
    When j'inscris {'Zoé'} en public {'enfants'}
    Then {'Zoé'} est membre du groupe {'Jeunes'} de la saison suivante

  Scenario: Une clôture anticipée ramène la fin de saison et supprime les séances planifiées postérieures
    Given la séance {'posture-1'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-05'}
    And la séance {'posture-2'} est planifiée pour le groupe {'Jeunes'} le {'2026-10-20'}
    When je clos la saison le {'2026-10-12'} en effaçant {''}
    Then la saison {'2026-2027'} se termine le {'2026-10-12'}
    And le club compte {1} séances planifiées

  Scenario: Une clôture déjà faite est refusée
    When je clos la saison le {'2026-10-12'} en effaçant {''}
    And j'essaie de clore à nouveau la saison le {'2026-10-13'}
    Then la clôture est refusée avec le motif {'seasonAlreadyClosed'}

  Scenario: Un échec en cours de clôture n'efface rien, n'écrit aucune archive et laisse la saison ouverte
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo, Hugo'}
    And l'effacement des passages d'un élève échouera
    When j'essaie de clore la saison le {'2026-10-12'} en effaçant {'Hugo'}
    Then la clôture a échoué sans rien changer
    And la saison {'2026-2027'} est ouverte
    And la saison n'a pas d'archive
    And le club compte {3} élèves et {0} passages

  Scenario: La sauvegarde porte la clôture et l'archive, et un fichier antérieur à la clôture est refusé
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo, Hugo'}
    And j'exporte une sauvegarde du club
    And je garde cette sauvegarde comme celle d'avant la clôture
    When je clos la saison le {'2026-10-12'} en effaçant {'Hugo'}
    And j'exporte une sauvegarde du club
    And j'importe cette sauvegarde dans un club vide
    Then la saison {'2026-2027'} est close le {'2026-10-12'}
    And l'archive de la saison compte {1} séances, {3} présences et {0} passages pour les {'enfants'}
    And le club compte {2} élèves et {0} passages
    When j'importe la sauvegarde d'avant la clôture
    Then l'import est refusé avec le motif {'backupReopensClosedSeason'}
    And la saison {'2026-2027'} est close le {'2026-10-12'}
    And le club compte {2} élèves et {0} passages
