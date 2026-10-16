# Lot U9 (domaine) : le parcours de l'élève (une ligne par technique, une case
# par exercice) et l'en-tête « en cours / prochain / alerte », sans interface.
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français. « Aujourd'hui » est le 2026-10-12. Le catalogue compte 15
# techniques et 70 exercices ; « posture » en a 4 et « bille-fantome » 2.
Feature: Le parcours de l'élève

  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}

  Scenario: Le parcours compte une ligne par technique et une case par exercice
    When j'ouvre la fiche de {'Léa'}
    Then le parcours compte {15} techniques
    And le parcours compte {70} cases
    And la technique {'posture'} compte {4} cases
    And la technique {'bille-fantome'} compte {2} cases

  Scenario: Une case est à faire, en cours, validée ou acquise
    Given {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    And {'Léa'} a réussi {2} passages sur {'posture 2'} lors de séances précédentes
    And {'Léa'} a le bloc {'puissance'} acquis au positionnement le {'2026-10-12'}
    When j'ouvre la fiche de {'Léa'}
    Then la case {'posture 1'} est {'validée'}
    And la case {'posture 2'} est {'en cours'} avec {2} réussites
    And la case {'posture 3'} est {'à faire'}
    And la case {'puissance 1'} est {'acquise'}
    And la technique {'posture'} est {'en cours'}
    And la technique {'puissance'} est {'acquise au positionnement'}
    And la technique {'demi-bille'} est {'à commencer'}

  Scenario: Un échec seul met la case en cours sans réussite
    Given {'Léa'} a échoué {1} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la fiche de {'Léa'}
    Then la case {'posture 1'} est {'en cours'} avec {0} réussites

  Scenario: Un exercice repris après le positionnement montre ses passages, le reste reste acquis
    Given {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-10-05'}
    And {'Léa'} a réussi {1} passages sur {'posture 2'} le {'2026-10-06'}
    When j'ouvre la fiche de {'Léa'}
    Then la case {'posture 1'} est {'acquise'}
    And la case {'posture 2'} est {'en cours'} avec {1} réussites
    And la case {'posture 3'} est {'acquise'}

  Scenario: Une technique terminée par passages n'est pas confondue avec une technique acquise
    Given {'Léa'} a validé tous les exercices avant {'puissance 1'}
    When j'ouvre la fiche de {'Léa'}
    Then la technique {'posture'} est {'terminée'}
    And la case {'posture 1'} est {'validée'}

  Scenario: L'en-tête montre l'exercice en cours et le prochain
    When j'ouvre la fiche de {'Léa'}
    Then l'exercice en cours est {'posture 1'}
    And le prochain exercice est {'posture 2'}
    And le parcours est à commencer

  Scenario: Un exercice validé fait avancer l'en-tête
    Given {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la fiche de {'Léa'}
    Then l'exercice en cours est {'posture 2'}
    And le prochain exercice est {'posture 3'}
    And le parcours n'est pas à commencer

  Scenario: Le prochain exercice passe à la technique suivante
    Given {'Léa'} a validé tous les exercices avant {'puissance 1'}
    When j'ouvre la fiche de {'Léa'}
    Then l'exercice en cours est {'puissance 1'}
    And le prochain exercice est {'puissance 2'}

  Scenario: L'exercice en cours montre les passages réussis
    Given {'Léa'} a réussi {2} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la fiche de {'Léa'}
    Then l'exercice en cours est {'posture 1'}
    And l'exercice en cours compte {2} réussites sur {5}

  Scenario: Le total ne dit pas « zéro sur soixante-dix »
    Given {'Léa'} a le bloc {'posture'} acquis au positionnement le {'2026-10-12'}
    When j'ouvre la fiche de {'Léa'}
    Then l'en-tête compte {1} techniques terminées sur {15}
    And l'en-tête compte {4} exercices validés sur {70}
    And le parcours n'est pas à commencer

  Scenario: Un niveau terminé n'a ni exercice en cours ni prochain
    Given {'Léa'} a tous les blocs acquis au positionnement le {'2026-10-12'}
    When j'ouvre la fiche de {'Léa'}
    Then le niveau est terminé
    And aucun exercice n'est en cours
    And aucun prochain exercice n'est proposé
    And l'en-tête compte {15} techniques terminées sur {15}

  Scenario: Trois échecs de suite apparaissent dans l'en-tête
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la fiche de {'Léa'}
    Then l'alerte de l'en-tête porte sur {'posture 1'} avec {3} échecs
    And la technique {'posture'} est {'à revoir'}
    And la case {'posture 1'} est signalée par une alerte

  Scenario: Sans alerte, l'en-tête n'en montre aucune
    Given {'Léa'} a échoué {2} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la fiche de {'Léa'}
    Then l'en-tête n'a aucune alerte
