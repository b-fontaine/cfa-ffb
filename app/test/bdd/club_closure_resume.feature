# Clôture de saison dans un club synchronisé : toutes les coupures possibles et
# les refus (FB8, partie A). Le club est petit pour que chaque scénario joue la
# clôture entière ; le grand club est dans club_closure.feature.
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français.
Feature: Clore une saison dans un petit club synchronisé, coupure après coupure

  Background:
    Given un club synchronisé de {2} groupes de {4} élèves ayant chacun {3} passages

  Scenario: Interrompre la clôture après chaque lot possible, puis reprendre, donne toujours le même état
    Then chaque coupure de la clôture, {2} élèves effacés par groupe, se reprend à l'état d'un seul lot

  Scenario: Perdre l'accusé de chaque lot possible, puis reprendre, donne toujours le même état
    Then chaque accusé perdu de la clôture, {2} élèves effacés par groupe, se reprend à l'état d'un seul lot

  Scenario: Une clôture sans reconduction ni suppression de séances planifiées
    When le directeur clôt la saison sans suite ni suppression, en effaçant {2} élèves par groupe
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot, sans suite ni suppression

  Scenario: Aucun élève à effacer : la clôture reconduit tout le monde
    When le directeur clôt la saison en effaçant {0} élèves par groupe
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire
    And aucun marqueur d'opération ne reste

  Scenario: Une saison déjà close est refusée sans rien écrire
    When le directeur clôt la saison en effaçant {2} élèves par groupe
    And le directeur clôt à nouveau la saison
    Then la seconde clôture est refusée avec le motif {'seasonAlreadyClosed'} sans rien écrire

  Scenario: Une clôture déjà commencée n'est pas relancée avec d'autres choix : elle se reprend avec les siens
    When le directeur clôt la saison en effaçant {2} élèves par groupe, connexion coupée après {1} lots
    And le directeur tente de clore à nouveau la saison en effaçant {0} élèves par groupe
    Then la seconde clôture est refusée avec le motif {'closurePending'} sans rien écrire
    When le directeur reprend la clôture
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire
    And aucun marqueur d'opération ne reste

  Scenario: Une clôture termine l'effacement en cours d'un autre auteur, qui se termine ensuite sans marqueur orphelin
    Given un administrateur a commencé d'effacer un élève, connexion coupée après {1} lots
    When le directeur clôt la saison en effaçant {0} élèves par groupe
    Then la clôture est terminée
    When l'administrateur reprend l'effacement de cet élève
    Then l'effacement de cet élève est terminé
    And aucun marqueur d'opération ne reste

  Scenario: Un élève qui n'est pas concerné par la clôture est refusé sans rien écrire
    When le directeur clôt la saison en effaçant un élève inconnu
    Then la clôture est refusée comme introuvable et rien n'est écrit

  Scenario: Plus de 390 élèves à effacer sont refusés avant toute écriture
    Given un club synchronisé de {1} groupes de {400} élèves ayant chacun {0} passages
    When le directeur clôt la saison en effaçant {400} élèves par groupe
    Then la clôture est refusée avec le motif {'tooManyToErase'} et rien n'est écrit
