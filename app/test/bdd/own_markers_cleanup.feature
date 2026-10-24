# Nettoyage des marqueurs par leur auteur (FB8 partie B, tranche B1 ; ADR 0024
# décision 19 ; décision D4 du 2026-10-24). Un marqueur d'import
# (`imports/{empreinte}_{uid}`) ou d'opération (`operations/{empreinte}_{uid}`)
# appartient à son auteur par construction : à la suppression de son compte,
# l'auteur retrouve et supprime les siens, et rien d'autre. Le club est un faux
# Firestore en mémoire qui applique les garde-fous des règles sur les marqueurs
# (liste filtrée sur l'auteur, suppression du sien seul, rôle) ; les règles
# réelles sont jouées contre l'émulateur par scripts/rules_test/matrix.test.mjs
# et import.test.mjs. Pas d'écran dans cette tranche : le parcours de
# suppression d'un compte (B2) s'y appuiera.
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français.
Feature: Retirer ses propres marqueurs d'un club

  Background:
    Given un club synchronisé dont les comptes posent des marqueurs
    And dans le club, le compte {'directeur'} a laissé {2} marqueurs d'import et {2} marqueurs d'opération
    And dans le club, le compte {'enseignant'} a laissé {1} marqueurs d'import et {0} marqueurs d'opération
    And dans le club, le compte {'administrateur'} a laissé {1} marqueurs d'import et {1} marqueurs d'opération

  Scenario: Un directeur retire ses marqueurs d'opération et d'import
    When le compte {'directeur'} retire ses marqueurs du club
    Then {4} marqueurs ont été retirés
    And il ne reste aucun marqueur du compte {'directeur'}
    And le compte {'enseignant'} a toujours {1} marqueurs
    And le compte {'administrateur'} a toujours {2} marqueurs

  Scenario: Un enseignant retire ses marqueurs d'import sans demander les marqueurs d'opération
    When le compte {'enseignant'} retire ses marqueurs du club
    Then {1} marqueurs ont été retirés
    And il ne reste aucun marqueur du compte {'enseignant'}
    And le compte {'directeur'} a toujours {4} marqueurs
    And aucune liste des marqueurs d'opération n'a été demandée

  Scenario: Un parent n'a aucun marqueur : rien n'est lu ni écrit
    When le compte {'parent'} retire ses marqueurs du club
    Then {0} marqueurs ont été retirés
    And aucune liste de marqueurs n'a été demandée
    And aucun lot n'a été envoyé

  Scenario: Plus de 400 marqueurs partent en lots de 400 au plus
    Given dans le club, le compte {'directeur'} a laissé {450} marqueurs d'import et {0} marqueurs d'opération
    When le compte {'directeur'} retire ses marqueurs du club
    Then {454} marqueurs ont été retirés
    And il ne reste aucun marqueur du compte {'directeur'}
    And aucun lot n'a dépassé {400} suppressions

  Scenario: Un nettoyage coupé par le réseau se reprend sans danger
    Given dans le club, le compte {'directeur'} a laissé {450} marqueurs d'import et {0} marqueurs d'opération
    And la connexion est coupée après {1} lot
    When le compte {'directeur'} retire ses marqueurs du club
    Then le nettoyage est interrompu faute de réseau
    And le compte {'directeur'} a toujours {54} marqueurs
    When la connexion revient
    And le compte {'directeur'} retire ses marqueurs du club
    Then il ne reste aucun marqueur du compte {'directeur'}
    And le compte {'enseignant'} a toujours {1} marqueurs

  Scenario: Hors ligne, rien n'est retiré
    Given l'appareil est hors ligne
    When le compte {'directeur'} retire ses marqueurs du club
    Then le nettoyage est interrompu faute de réseau
    And le compte {'directeur'} a toujours {4} marqueurs
