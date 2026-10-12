Feature: Courbe de progression

  Background:
    Given le club suit la saison {'2026-2027'}

  Scenario: Courbe de progression d'un exercice
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a obtenu sur {'puissance 2'} les passages {'5/10, 7/10, 6/10, 8/10'} dans cet ordre
    When j'ouvre la courbe de {'Léa'} pour {'puissance 2'}
    Then la courbe contient les points {'5, 7, 6, 8'}
    And le meilleur résultat est {'8/10'}
    And la pente est positive
