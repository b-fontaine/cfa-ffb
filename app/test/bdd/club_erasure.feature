# Effacement d'un élève dans un club synchronisé (FB8, partie A, ADR 0024
# décision 19, ADR 0025). Le droit à l'effacement est honoré à tout moment : la
# fiche passe à « en cours d'effacement » (plus aucune donnée nouvelle ne s'y
# rapporte), tout ce qui se rapporte à l'élève est purgé par lots reprenables
# de 400 écritures au plus (marqueur d'opération avancé dans le même lot), puis
# la fiche est supprimée EN DERNIER avec le marqueur : aucune trace nominative
# ne reste. Le club est un faux Firestore en mémoire qui applique les garde-fous
# des règles que l'opération doit respecter (marqueur propre à son auteur,
# donnée nouvelle refusée sur une fiche en cours d'effacement) ; les règles
# réelles sont jouées contre l'émulateur par
# scripts/rules_test/operations.test.mjs.
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français.
Feature: Effacer un élève dans un club synchronisé

  Background:
    Given un club synchronisé où le directeur gère l'élève {'Léa'} du groupe {'Mardi'} et l'élève {'Tom'}
    And {'Léa'} a {3} passages, {1} bilan, {1} acquittement, {1} bloc acquis et {2} présences
    And {'Tom'} a {2} passages, {1} bilan, {1} acquittement, {1} bloc acquis et {2} présences
    And un parent est lié à {'Léa'}

  Scenario: Le directeur efface complètement un élève
    When le directeur efface {'Léa'}
    Then {'Léa'} n'existe plus dans le club
    And aucun document du club ne se rapporte plus à {'Léa'}
    And les données de {'Tom'} sont intactes
    And aucun marqueur d'opération ne reste
    And la fiche de {'Léa'} est supprimée après toutes ses données

  Scenario: Le compte du parent lié à la seule fiche effacée quitte le club
    When le directeur efface {'Léa'}
    Then le compte du parent n'existe plus dans le club

  Scenario: Le compte de rôle élève lié à la fiche effacée quitte le club
    Given un compte élève est lié à {'Léa'}
    When le directeur efface {'Léa'}
    Then le compte élève n'existe plus dans le club

  Scenario: Un parent lié à deux élèves garde son compte, sans le lien effacé
    Given un parent est lié à {'Léa'} et à {'Tom'}
    When le directeur efface {'Léa'}
    Then le compte du parent n'est lié qu'à {'Tom'}

  Scenario: Les étiquettes de saisie, qui ne nomment personne, sont conservées
    Given la première saisie de {'Léa'} porte l'étiquette {'tooLong'}
    When le directeur efface {'Léa'}
    Then la première saisie de {'Léa'} garde l'étiquette {'tooLong'}

  Scenario: Reprendre un effacement interrompu donne le même résultat qu'un effacement complet
    When le directeur efface {'Léa'} mais la connexion est coupée après {1} lots
    Then l'effacement de {'Léa'} est interrompu et sa fiche est marquée en cours d'effacement
    And le marqueur d'opération du directeur est au lot {1}
    And aucun document du club ne contient le prénom de {'Léa'} hors de sa fiche
    When le directeur reprend l'effacement de {'Léa'}
    Then {'Léa'} n'existe plus dans le club
    And le club est identique à celui d'un effacement sans coupure

  Scenario: Un accusé perdu n'efface rien deux fois et la reprise converge
    When le directeur efface {'Léa'} mais l'accusé du lot {1} est perdu
    And le directeur reprend l'effacement de {'Léa'}
    Then {'Léa'} n'existe plus dans le club
    And le club est identique à celui d'un effacement sans coupure

  Scenario: Une donnée nouvelle est refusée pendant l'effacement et après
    When le directeur efface {'Léa'} mais la connexion est coupée après {1} lots
    And un appareil retardataire ajoute un passage pour {'Léa'}
    Then le serveur refuse cette donnée
    When le directeur reprend l'effacement de {'Léa'}
    And un appareil retardataire ajoute un passage pour {'Léa'}
    Then le serveur refuse cette donnée
    And {'Léa'} n'existe plus dans le club

  Scenario: Une présence ajoutée par un appareil retardataire après la purge est retirée avant la suppression de la fiche
    When le directeur efface {'Léa'} mais un appareil retardataire ajoute une présence de {'Léa'} après le lot {2}
    Then {'Léa'} n'existe plus dans le club
    And aucun document du club ne se rapporte plus à {'Léa'}
    And aucun marqueur d'opération ne reste

  Scenario: Un enseignant n'efface pas un élève
    Given le compte connecté est un enseignant du groupe {'Mardi'}
    When le compte tente d'effacer {'Léa'}
    Then l'effacement est refusé et rien n'est écrit

  Scenario: Deux appareils du directeur qui effacent en même temps convergent
    When deux appareils du directeur effacent {'Léa'} en même temps
    Then {'Léa'} n'existe plus dans le club
    And le club est identique à celui d'un effacement sans coupure
    And aucun marqueur d'opération ne reste

  Scenario: Un dossier de plus de 800 écritures s'efface par lots de 400 au plus
    Given {'Léa'} a au total {850} passages
    When le directeur efface {'Léa'}
    Then {'Léa'} n'existe plus dans le club
    And aucun lot n'a dépassé {400} écritures
    And l'effacement a pris au moins {4} lots

  Scenario: Le plafond d'écritures du jour suspend l'effacement, qui reprend le lendemain
    Given {'Léa'} a au total {850} passages
    And le plafond d'écritures d'une opération est de {500} par jour
    When le directeur efface {'Léa'}
    Then l'effacement est suspendu pour aujourd'hui et la fiche de {'Léa'} est marquée en cours d'effacement
    When le directeur reprend l'effacement de {'Léa'} le jour même
    Then l'effacement reste suspendu sans écriture de plus
    When le lendemain, le directeur reprend l'effacement de {'Léa'}
    Then {'Léa'} n'existe plus dans le club

  Scenario: Effacer un élève déjà effacé est refusé comme introuvable, sans rien écrire
    When le directeur efface {'Léa'}
    And le directeur efface {'Léa'}
    Then le second effacement est refusé comme introuvable
    And aucune écriture n'a été faite par le second effacement
