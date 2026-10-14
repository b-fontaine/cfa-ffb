# Suivi des résultats d'entraînement (domaine). Mots-clés Gherkin en anglais :
# bdd_widget_test ne reconnaît pas les mots-clés français (vérifié, voir
# docs/engineering/testing.md). Les libellés sont en français.
Feature: Suivi des résultats d'entraînement

  Background:
    Given le club suit la saison {'2026-2027'}

  Scenario: Enregistrer un passage valide
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    When j'enregistre pour {'Léa'} sur {'puissance 1'} {7} billes réussies sur {9} tentatives
    Then le passage est enregistré avec le ratio {'7/9'}

  Scenario: Refuser plus de réussites que de tentatives
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    When j'enregistre pour {'Léa'} sur {'puissance 1'} {10} billes réussies sur {9} tentatives
    Then l'enregistrement est refusé avec le motif {'pottedExceedsTotal'}

  Scenario: Valider un exercice au cinquième passage réussi
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'puissance 1'}
    And {'Léa'} a réussi {4} passages sur {'puissance 1'} lors de séances précédentes
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    When j'enregistre pour {'Léa'} sur {'puissance 1'} {7} billes réussies sur {9} tentatives
    Then l'exercice {'puissance 1'} est validé
    And l'exercice suivant recommandé est {'puissance 2'}

  Scenario: Le taux n'est pas atteint
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a validé tous les exercices avant {'puissance 1'}
    And {'Léa'} a réussi {4} passages sur {'puissance 1'} lors de séances précédentes
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    When j'enregistre pour {'Léa'} sur {'puissance 1'} {6} billes réussies sur {9} tentatives
    Then l'exercice {'puissance 1'} reste en cours avec {4} passages réussis sur {5}
    And l'exercice suivant recommandé est {'puissance 1'}

  Scenario: Alerte après trois échecs consécutifs
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And {'Théo'} a échoué {2} passages sur {'bille-pleine 1'} lors de séances précédentes
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Théo'}
    When j'enregistre pour {'Théo'} sur {'bille-pleine 1'} {4} billes réussies sur {8} tentatives
    Then le niveau d'alerte de {'Théo'} sur {'bille-pleine 1'} est {'attention'}

  Scenario: Une réussite résout l'alerte et valide l'exercice
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And {'Théo'} a réussi {4} passages sur {'bille-pleine 1'} lors de séances précédentes
    And {'Théo'} a échoué {3} passages sur {'bille-pleine 1'} lors de séances précédentes
    And le niveau d'alerte de {'Théo'} sur {'bille-pleine 1'} est {'attention'}
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Théo'}
    When j'enregistre pour {'Théo'} sur {'bille-pleine 1'} {6} billes réussies sur {8} tentatives
    Then le niveau d'alerte de {'Théo'} sur {'bille-pleine 1'} est {'aucune'}
    And l'exercice {'bille-pleine 1'} est validé

  Scenario: Deux passages maximum par exercice et par séance
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    And j'enregistre pour {'Léa'} sur {'puissance 2'} {6} billes réussies sur {10} tentatives
    And j'enregistre pour {'Léa'} sur {'puissance 2'} {7} billes réussies sur {10} tentatives
    When j'enregistre pour {'Léa'} sur {'puissance 2'} {8} billes réussies sur {10} tentatives
    Then l'enregistrement est refusé avec le motif {'passesLimitReached'}

  # Lot 7 (ADR 0008) : un passage daté du jour du positionnement ou après
  # reprend la main sur son exercice ; il n'est pas annoncé comme validation.
  Scenario: Un passage après le positionnement reprend la main sur son exercice
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-10-01'}
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    When j'enregistre pour {'Léa'} sur {'posture 1'} {3} billes réussies sur {4} tentatives
    Then le passage reprend la main sur l'exercice acquis au positionnement
    And la validation de l'exercice n'est pas annoncée
    And l'exercice suivant recommandé est {'posture 1'}

  Scenario: Un passage le jour du positionnement reprend la main sur son exercice
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-10-03'}
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    When j'enregistre pour {'Léa'} sur {'posture 1'} {3} billes réussies sur {4} tentatives
    Then le passage reprend la main sur l'exercice acquis au positionnement

  Scenario: Un passage antérieur au positionnement ne reprend pas la main
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-10-05'}
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    When j'enregistre pour {'Léa'} sur {'posture 1'} {3} billes réussies sur {4} tentatives
    Then le passage ne reprend pas la main sur l'exercice acquis au positionnement
    And l'exercice suivant recommandé est {'puissance 1'}

  Scenario: Le cinquième passage après le positionnement ne fête pas la validation
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {4} passages sur {'posture 1'} lors de séances précédentes
    And {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-10-02'}
    And la séance du groupe {'Jeunes'} le {'2026-10-03'} réunit {'Léa'}
    When j'enregistre pour {'Léa'} sur {'posture 1'} {3} billes réussies sur {4} tentatives
    Then le passage reprend la main sur l'exercice acquis au positionnement
    And la validation de l'exercice n'est pas annoncée
