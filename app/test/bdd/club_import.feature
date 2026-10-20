# Import d'une sauvegarde dans un club synchronisé (FB7, partie A : moteur,
# sans interface). Le club est un faux Firestore en mémoire qui applique les
# garde-fous des règles que le moteur doit respecter (marqueur d'import,
# création seule des passages) ; les règles réelles sont jouées contre
# l'émulateur par scripts/rules_test/import.test.mjs.
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français.
Feature: Importer une sauvegarde dans un club synchronisé

  Background:
    Given un club synchronisé vide
    And une sauvegarde de {2} groupes, {6} élèves et {3} séances par groupe avec {4} passages par élève et séance

  Scenario: Le directeur importe toute la sauvegarde en créant les groupes
    When le directeur importe la sauvegarde en créant tous les groupes
    Then le club compte {2} groupes et {6} élèves
    And le club compte {72} passages
    And les passages du club sont relus dans l'ordre du fichier
    And le marqueur d'import indique tous les lots terminés

  Scenario: Reprendre un import interrompu donne le même résultat qu'un import complet
    When le directeur importe la sauvegarde mais la connexion est coupée après {1} lots
    And le directeur reprend l'import
    Then le club est identique à celui d'un import complet

  Scenario: Rejouer le même fichier n'écrit rien
    When le directeur importe la sauvegarde en créant tous les groupes
    And le directeur prépare à nouveau l'import du même fichier
    Then le plan indique que le fichier est déjà importé
    And aucune écriture n'a été faite par ce second import

  Scenario: Une séance planifiée sans groupe exige une décision explicite
    Given la sauvegarde contient une séance planifiée sans groupe
    When le directeur prépare l'import en créant tous les groupes sans décision
    Then le plan demande une décision pour {1} séance sans groupe
    And aucune écriture n'a été faite
    When le directeur rattache cette séance au premier groupe du fichier
    Then le plan est prêt

  Scenario: Un enseignant n'importe que dans ses groupes
    Given le club compte un groupe existant {'Mardi'} confié à l'enseignant
    And le club compte un groupe existant {'Jeudi'} confié à un autre enseignant
    When l'enseignant prépare l'import en associant les groupes du fichier aux groupes existants {'Jeudi'} et {'Mardi'}
    Then le plan est bloqué pour le motif {'roleDenied'}
    And aucune écriture n'a été faite

  Scenario: Deux groupes du fichier ne sont jamais fusionnés sans choix explicite
    Given le club compte un groupe existant {'Mardi'} confié à l'enseignant
    When le directeur prépare l'import en associant les deux groupes du fichier au groupe existant {'Mardi'}
    Then le plan est bloqué pour le motif {'mergeNotConfirmed'}

  Scenario: Reprendre avec un autre rattachement de groupes est refusé car le plan a changé
    Given le club compte un groupe existant {'Jeudi'} confié à l'enseignant
    When le directeur importe la sauvegarde mais la connexion est coupée après {1} lots
    And le directeur prépare la reprise en associant le premier groupe du fichier au groupe existant {'Jeudi'}
    Then le plan est bloqué pour le motif {'planChanged'}
    And le marqueur d'import reste au lot {1}

  Scenario: Rétablir des élèves effacés exige une confirmation explicite
    Given le club a clos une saison après l'export du fichier et ne garde que {3} des élèves du fichier
    When le directeur prépare l'import en créant tous les groupes
    Then le plan demande la confirmation du rétablissement de {3} élèves
    When le directeur confirme le rétablissement de {2} élèves
    Then le plan demande la confirmation du rétablissement de {3} élèves
    When le directeur confirme le rétablissement de {3} élèves
    Then le plan est prêt

  Scenario: Un gros import est fractionné sur plusieurs jours
    Given le plafond d'écritures par jour est de {60}
    When le directeur prépare l'import en créant tous les groupes
    Then le plan avertit qu'il faut fractionner l'import sur {2} jours au moins
    When le directeur importe la sauvegarde en s'arrêtant au plafond du jour
    Then l'import est suspendu après le plafond du jour
    When le directeur reprend l'import le lendemain
    Then le club est identique à celui d'un import complet

  Scenario: Reprendre le même jour n'ajoute aucune écriture
    Given le plafond d'écritures par jour est de {60}
    When le directeur prépare l'import en créant tous les groupes
    And le directeur importe la sauvegarde en s'arrêtant au plafond du jour
    Then l'import est suspendu après le plafond du jour
    When le directeur reprend l'import le jour même
    Then l'import reste suspendu sans écriture de plus

  Scenario: Le marqueur d'un autre compte ne bloque pas l'import du directeur
    Given un autre compte a posé un marqueur terminé pour ce fichier
    When le directeur importe la sauvegarde en créant tous les groupes
    Then le club compte {2} groupes et {6} élèves
    And le marqueur d'import du directeur est le sien

  Scenario: Un enseignant confirme les fiches qu'il ne peut pas vérifier
    Given le club compte un groupe existant {'Jeudi'} confié à l'enseignant
    And une fiche du fichier existe déjà dans le club hors des groupes de l'enseignant
    When l'enseignant prépare l'import de son seul groupe
    Then le plan demande la confirmation de {3} fiches qu'il ne peut pas vérifier
    And aucune écriture n'a été faite
    When l'enseignant confirme {3} fiches qu'il ne peut pas vérifier
    Then le plan est prêt

