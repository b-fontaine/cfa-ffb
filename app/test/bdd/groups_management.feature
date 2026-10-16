# Lot 11a (ADR 0019), domaine : plusieurs groupes par public dans une saison.
# Le nom d'un groupe est unique dans sa saison (casse et espaces de bord
# ignorés) ; un groupe ne se supprime que vide, sans séance saisie ni séance
# planifiée ;
# l'inscription et le changement de public demandent le groupe dès qu'il y en
# a plusieurs. « Aujourd'hui » est le 2026-10-12.
Feature: Plusieurs groupes par public

  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}

  Scenario: Créer un second groupe du même public
    When je crée le groupe {'Mercredi'} de public {'enfants'}
    Then la saison compte les groupes {'Jeunes, Mercredi'}

  Scenario: Un nom déjà pris dans la saison est refusé, casse et espaces ignorés
    When je crée le groupe {' JEUNES '} de public {'adultes'}
    Then l'opération sur les groupes est refusée avec le motif {'groupNameTaken'}
    And la saison compte les groupes {'Jeunes'}

  Scenario: Renommer un groupe garde ses membres et sa grille
    When je renomme le groupe {'Jeunes'} en {'Débutants'}
    And j'ouvre la grille du groupe {'Jeunes'}
    Then la saison compte les groupes {'Débutants'}
    And la grille du groupe s'intitule {'Débutants'}
    And les colonnes de la grille sont {'Léa'}

  Scenario: Un groupe qui a des membres ne se supprime pas
    When je supprime le groupe {'Jeunes'}
    Then l'opération sur les groupes est refusée avec le motif {'groupNotEmpty'}
    And la saison compte les groupes {'Jeunes'}

  Scenario: Un groupe vide et sans séance se supprime
    Given je crée le groupe {'Mercredi'} de public {'enfants'}
    When je supprime le groupe {'Mercredi'}
    Then la saison compte les groupes {'Jeunes'}

  Scenario: Un groupe qui a donné une séance ne se supprime pas, même vide
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa'}
    And {'Léa'} quitte le groupe {'Jeunes'} le {'2026-10-06'}
    When je supprime le groupe {'Jeunes'}
    Then l'opération sur les groupes est refusée avec le motif {'groupHasRecords'}
    And la saison compte les groupes {'Jeunes'}

  Scenario: Un groupe visé par une séance planifiée ne se supprime pas, même vide
    Given {'Léa'} quitte le groupe {'Jeunes'} le {'2026-10-06'}
    And je planifie la séance {'Cours'} pour le groupe {'Jeunes'} le {'2026-10-19'} avec la séance du catalogue {'demi-bille-2'}
    When je supprime le groupe {'Jeunes'}
    Then l'opération sur les groupes est refusée avec le motif {'groupHasPlanned'}
    And la saison compte les groupes {'Jeunes'}

  Scenario: Avec un seul groupe pour le public, l'inscription ne demande rien
    When j'inscris {'Zoé'} en public {'enfants'}
    Then {'Zoé'} est membre du groupe {'Jeunes'}

  Scenario: Avec deux groupes pour le public, l'inscription demande le groupe
    Given je crée le groupe {'Mercredi'} de public {'enfants'}
    When j'inscris {'Zoé'} en public {'enfants'}
    Then l'opération sur les groupes est refusée avec le motif {'groupChoiceRequired'}
    And le club ne compte pas l'élève {'Zoé'}
    When j'inscris {'Zoé'} en public {'enfants'} dans le groupe {'Mercredi'}
    Then {'Zoé'} est membre du groupe {'Mercredi'}

  Scenario: Le changement de public demande le groupe de destination quand il y en a deux
    Given je crée le groupe {'Soir'} de public {'adultes'}
    And je crée le groupe {'Midi'} de public {'adultes'}
    When j'essaie de passer {'Léa'} en public {'adultes'} au {'2026-10-12'}
    Then l'opération sur les groupes est refusée avec le motif {'groupChoiceRequired'}
    And le public courant de {'Léa'} est {'enfants'}
    When j'essaie de passer {'Léa'} en public {'adultes'} au {'2026-10-12'} dans le groupe {'Midi'}
    Then {'Léa'} est membre du groupe {'Midi'}
