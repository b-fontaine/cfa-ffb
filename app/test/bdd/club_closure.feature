# Clôture de saison dans un club synchronisé (FB8, partie A, ADR 0019 et ADR
# 0024 décision 19) : un grand club (plus de 1500 écritures, donc impossible en
# une unité de travail de 500) se clôt par lots idempotents reprenables. Le
# résultat est celui d'une clôture en un seul lot (comparé à `CloseSeason` sur
# des dépôts en mémoire) ; l'archive est écrite AVANT tout effacement ;
# interrompre n'importe où puis reprendre donne l'état final attendu.
# Le club est un faux Firestore en mémoire qui applique les garde-fous des règles
# que l'opération doit respecter (voir club_erasure.feature) ; les règles
# réelles sont jouées par scripts/rules_test/operations.test.mjs.
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français.
Feature: Clore une saison dans un grand club synchronisé

  Background:
    Given un club synchronisé de {2} groupes de {25} élèves ayant chacun {40} passages

  Scenario: Clôturer un grand club par lots donne le même état qu'en un seul lot
    When le directeur clôt la saison en effaçant {18} élèves par groupe
    Then la clôture est terminée
    And la clôture a écrit plus de {1500} écritures
    And aucun lot n'a dépassé {400} écritures
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire
    And aucun marqueur d'opération ne reste
    And les élèves effacés n'existent plus nulle part

  Scenario: L'archive est écrite avant tout effacement de donnée d'élève
    When le directeur clôt la saison en effaçant {18} élèves par groupe
    Then l'archive est écrite avant le premier effacement de donnée d'élève
    And la fiche d'un élève effacé est supprimée après toutes ses données

  Scenario: Interrompre après la déclaration des élèves à effacer, puis reprendre
    When le directeur clôt la saison en effaçant {18} élèves par groupe, connexion coupée après {1} lots
    Then la clôture est interrompue
    And les élèves à effacer sont marqués en cours d'effacement et aucun n'est encore purgé
    And le marqueur d'opération du directeur est au lot {1}
    When le directeur reprend la clôture
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire

  Scenario: Interrompre pendant la purge des élèves, puis reprendre
    When le directeur clôt la saison en effaçant {18} élèves par groupe, connexion coupée après {6} lots
    Then la clôture est interrompue
    And l'archive est écrite et la saison est close
    And la purge des élèves à effacer est commencée sans être finie
    When le directeur reprend la clôture
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire
    And les élèves effacés n'existent plus nulle part

  Scenario: Interrompre juste avant le dernier lot, puis reprendre
    When le directeur clôt la saison en effaçant {18} élèves par groupe, connexion coupée après {10} lots
    Then la clôture est interrompue
    When le directeur reprend la clôture
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire
    And aucun marqueur d'opération ne reste

  Scenario: Une présence ajoutée par un appareil retardataire après la purge est retirée avant la suppression des fiches
    When le directeur clôt la saison, {18} élèves effacés par groupe, présence retardataire après la purge
    Then la clôture est terminée
    And les élèves effacés n'existent plus nulle part
    And aucun marqueur d'opération ne reste

  Scenario: Une clôture interrompue se retrouve à la reprise sans rien redemander
    When le directeur clôt la saison en effaçant {18} élèves par groupe, connexion coupée après {6} lots
    Then le marqueur de clôture retrouve la saison, le jour et les deux choix du directeur
    And aucun marqueur ne cite d'élève
    When un autre appareil du directeur reprend la clôture trouvée
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire

  Scenario: Deux appareils du directeur qui closent en même temps convergent
    When deux appareils du directeur closent la saison, {18} élèves effacés par groupe
    Then les deux clôtures sont terminées
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire
    And aucun marqueur d'opération ne reste

  Scenario: Le directeur et un administrateur qui closent en même temps ne s'écrasent pas
    When le directeur et un administrateur closent la saison, {18} élèves effacés par groupe
    Then les deux clôtures sont terminées
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire
    And aucun marqueur d'opération ne reste

  Scenario: Un administrateur qui termine la clôture interrompue n'écrase pas l'archive du directeur
    When le directeur clôt la saison en effaçant {18} élèves par groupe, connexion coupée après {1} lots
    And un administrateur clôt la saison, {18} élèves effacés par groupe
    And le directeur reprend la clôture
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire
    And aucun marqueur d'opération ne reste

  Scenario: Le plafond d'écritures du jour suspend la clôture, qui reprend le lendemain
    Given le plafond d'écritures d'une opération est de {1200} par jour
    When le directeur clôt la saison en effaçant {18} élèves par groupe
    Then la clôture est suspendue pour aujourd'hui
    When le lendemain, le directeur reprend la clôture
    Then la clôture est terminée
    And l'état du club est celui d'une clôture en un seul lot sur des dépôts en mémoire

  Scenario: Un enseignant ne clôt pas la saison
    Given le compte connecté est un enseignant du groupe {'Groupe1'}
    When le compte tente de clore la saison en effaçant {2} élèves par groupe
    Then la clôture est refusée et rien n'est écrit
