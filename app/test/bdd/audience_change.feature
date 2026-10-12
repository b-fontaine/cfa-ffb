Feature: Passage enfants vers adultes

  Background:
    Given le club suit la saison {'2026-2027'}

  Scenario: Passage en cours adultes avec historique conservé
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Hugo'}
    And {'Hugo'} a réussi {5} passages sur {'puissance 1'} lors de séances précédentes
    When je passe {'Hugo'} en public {'adultes'} au {'2026-11-01'}
    Then le public courant de {'Hugo'} est {'adultes'}
    And {'Hugo'} conserve {5} passages enregistrés
    And l'historique de public de {'Hugo'} contient {'enfants'} puis {'adultes'}

  Scenario: Le bilan de maturité ne change pas le public
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Hugo'}
    When j'enregistre pour {'Hugo'} un bilan de concentration {4}, endurance {4}, frustration {3} le {'2026-10-10'}
    Then le bilan de maturité suggère le passage à titre d'aide
    And le public courant de {'Hugo'} est {'enfants'}
