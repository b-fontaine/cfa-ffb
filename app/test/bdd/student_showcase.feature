# Lot U9 (domaine) : la vue « à montrer à l'élève » (décision Q6) ne porte que
# le prénom et le parcours. La garantie est de type : le modèle n'a aucun champ
# pour les alertes, les notes, le bilan de maturité, l'assiduité ou un autre
# élève. « Aujourd'hui » est le 2026-10-12.
Feature: La vue à montrer à l'élève

  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}

  Scenario: La vue montre le prénom et le parcours
    Given {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la vue élève de {'Léa'}
    Then la vue élève montre le prénom {'Léa'} et {15} techniques
    And la case {'posture 1'} de la vue élève est {'validée'}
    And l'exercice en cours de la vue élève est {'posture 2'}

  Scenario: La vue ne montre ni alerte, ni bilan, ni assiduité, ni autre élève
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And {'Théo'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la vue élève de {'Léa'}
    Then la vue élève ne contient ni alerte, ni bilan, ni assiduité, ni autre élève

  Scenario: La vue élève n'affiche pas le badge Proposition
    Given {'Léa'} a réussi {1} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la vue élève de {'Léa'}
    Then la vue élève ne signale aucune technique comme proposition

  Scenario: Une technique à revoir est montrée en cours
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la vue élève de {'Léa'}
    Then la technique {'posture'} de la vue élève est {'en cours'}
    And la case {'posture 1'} de la vue élève est {'en cours'}

  Scenario: Un parcours sans aucun passage est à commencer
    When j'ouvre la vue élève de {'Léa'}
    Then la vue élève est à commencer

  Scenario: Un élève qui a pratiqué sans valider n'est pas à commencer
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la vue élève de {'Léa'}
    Then la vue élève n'est pas à commencer

  Scenario: Les pastilles ne comptent que les réussites
    Given {'Léa'} a réussi {2} passages sur {'posture 1'} lors de séances précédentes
    And {'Léa'} a échoué {2} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la vue élève de {'Léa'}
    Then l'exercice en cours de la vue élève compte {2} réussites sur {5}

  Scenario: Une technique acquise au positionnement est montrée acquise
    Given {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-10-12'}
    When j'ouvre la vue élève de {'Léa'}
    Then la technique {'posture'} de la vue élève est {'acquise'}
    And la vue élève compte {4} exercices validés et {1} techniques terminées

  Scenario: Un élève inconnu n'a pas de vue
    When j'ouvre la vue élève de {'Zoé'}
    Then la vue élève est refusée car l'élève est introuvable
