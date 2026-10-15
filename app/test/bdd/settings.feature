# Lot 9 (F8), partie domaine et persistance : les réglages du club sont lus et
# écrits par des cas d'usage ; les règles lisent la valeur courante. Mots-clés
# Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en français.
Feature: Réglages du club

  Background:
    Given le club suit la saison {'2026-2027'}

  Scenario: Une installation neuve applique les valeurs par défaut
    Then le réglage {'passages requis'} vaut {5}
    And le réglage {'seuil alerte'} vaut {3}
    And le réglage {'séances avant rappel'} vaut {4}
    And le réglage {'part échec groupe'} vaut {50}
    And le réglage {'délai rappel sauvegarde'} vaut {30}

  Scenario: Un réglage enregistré est relu
    When je règle {'passages requis'} à {3}
    Then le réglage {'passages requis'} vaut {3}
    And le réglage {'seuil alerte'} vaut {3}

  Scenario: Baisser le nombre de passages requis valide un exercice sans toucher aux passages
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {3} passages sur {'puissance 1'} lors de séances précédentes
    And {'Léa'} n'a pas validé l'exercice {'puissance 1'}
    When je règle {'passages requis'} à {3}
    Then {'Léa'} a validé l'exercice {'puissance 1'}
    And le club compte {1} élèves et {3} passages

  Scenario: Relever le seuil d'alerte retire l'alerte sans toucher aux passages
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And {'Théo'} a échoué {3} passages sur {'bille-pleine 1'} lors de séances précédentes
    And le niveau d'alerte de {'Théo'} sur {'bille-pleine 1'} est {'attention'}
    When je règle {'seuil alerte'} à {4}
    Then le niveau d'alerte de {'Théo'} sur {'bille-pleine 1'} est {'aucune'}
    And le club compte {1} élèves et {3} passages

  Scenario: Un seuil d'alerte hors bornes est refusé et laisse les réglages intacts
    When je règle {'seuil alerte'} à {6}
    Then le réglage est refusé avec le motif {'invalidRules'}
    And le réglage {'seuil alerte'} vaut {3}

  Scenario: Une part d'échec hors bornes est refusée
    When je règle {'part échec groupe'} à {101}
    Then le réglage est refusé avec le motif {'invalidRules'}
    And le réglage {'part échec groupe'} vaut {50}

  Scenario: Rétablir les valeurs par défaut conserve les passages saisis
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {3} passages sur {'puissance 1'} lors de séances précédentes
    And je règle {'passages requis'} à {3}
    And je règle {'délai rappel sauvegarde'} à {7}
    And {'Léa'} a validé l'exercice {'puissance 1'}
    When je rétablis les réglages par défaut
    Then le réglage {'passages requis'} vaut {5}
    And le réglage {'délai rappel sauvegarde'} vaut {30}
    And {'Léa'} n'a pas validé l'exercice {'puissance 1'}
    And le club compte {1} élèves et {3} passages
