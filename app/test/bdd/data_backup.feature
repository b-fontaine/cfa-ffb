# Sauvegarde et restauration des données du club (domaine, sans interface).
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français.
Feature: Sauvegarde et restauration des données

  Background:
    Given le club suit la saison {'2026-2027'}

  Scenario: Restaurer une sauvegarde dans un club vide
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {5} passages sur {'puissance 1'} lors de séances précédentes
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    Then le club compte {1} élèves et {5} passages
    And {'Léa'} a validé l'exercice {'puissance 1'}

  Scenario: Importer deux fois la même sauvegarde ne duplique rien
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {5} passages sur {'puissance 1'} lors de séances précédentes
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    And j'importe à nouveau cette sauvegarde
    Then le club compte {1} élèves et {5} passages

  Scenario: Refuser une sauvegarde d'une version inconnue
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec la version {99}
    Then l'import est refusé avec le motif {'backupVersionUnsupported'}
    And le club compte {0} élèves et {0} passages

  Scenario: Refuser une sauvegarde invalide sans rien écrire
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {5} passages sur {'puissance 1'} lors de séances précédentes
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec un passage invalide
    Then l'import est refusé avec le motif {'backupInvalid'}
    And le club compte {0} élèves et {0} passages

  Scenario: Refuser une sauvegarde dont un passage vise un exercice inconnu
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {5} passages sur {'puissance 1'} lors de séances précédentes
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec un passage sur un exercice inconnu
    Then l'import est refusé avec le motif {'backupInconsistent'}
    And le club compte {0} élèves et {0} passages

  Scenario: Conserver la séance du catalogue d'une séance planifiée
    Given je planifie la séance {'Cours de demi-bille'} pour les {'enfants'} avec la séance du catalogue {'demi-bille-2'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    Then la séance planifiée {'Cours de demi-bille'} est liée à la séance du catalogue {'demi-bille-2'}

  Scenario: Refuser une sauvegarde dont la séance du catalogue est inconnue
    Given je planifie la séance {'Cours de demi-bille'} pour les {'enfants'} avec la séance du catalogue {'demi-bille-2'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec une séance planifiée du catalogue inconnue
    Then l'import est refusé avec le motif {'backupUnknownSheet'}
    And aucune séance planifiée n'est enregistrée
