# Lot U9 / lot 10 (domaine) : la vue de groupe (carte de chaleur technique ×
# élève), l'assiduité du groupe et les alertes de groupe. « Aujourd'hui » est
# le 2026-10-12. Les élèves rejoignent le groupe le 1er septembre 2026.
Feature: La vue de groupe

  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Hugo'}

  Scenario: La grille croise les techniques et les élèves
    When j'ouvre la grille du groupe {'Jeunes'}
    Then la grille compte {15} techniques
    And les colonnes de la grille sont {'Hugo, Léa, Théo'}

  Scenario: Chaque cellule porte une fraction et un état
    Given {'Théo'} a le bloc {'posture'} acquis au positionnement le {'2026-10-12'}
    And {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la grille du groupe {'Jeunes'}
    Then la cellule de {'Théo'} sur {'posture'} affiche {4} sur {4} {'acquise au positionnement'}
    And la cellule de {'Léa'} sur {'posture'} affiche {1} sur {4} {'en cours'}
    And la cellule de {'Hugo'} sur {'posture'} affiche {0} sur {4} {'à commencer'}

  Scenario: Une alerte active marque la cellule, pas une alerte vue
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la grille du groupe {'Jeunes'}
    Then la cellule de {'Léa'} sur {'posture'} est signalée par une alerte
    When j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'ouvre la grille du groupe {'Jeunes'}
    Then la cellule de {'Léa'} sur {'posture'} n'est pas signalée par une alerte

  Scenario: Le résumé en texte liste les élèves de chaque technique
    Given {'Théo'} a validé tous les exercices avant {'puissance 1'}
    And {'Léa'} a réussi {5} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la grille du groupe {'Jeunes'}
    Then les élèves ayant terminé la technique {'posture'} sont {'Théo'}
    And les élèves en cours sur la technique {'posture'} sont {'Léa'}
    And les élèves à commencer sur la technique {'posture'} sont {'Hugo'}

  Scenario: Un élève qui a quitté le groupe n'est plus une colonne
    Given {'Hugo'} quitte le groupe {'Jeunes'} le {'2026-10-01'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then les colonnes de la grille sont {'Léa, Théo'}

  Scenario: Un groupe inconnu n'a pas de grille
    When j'ouvre la grille du groupe {'Fantômes'}
    Then la grille est refusée car le groupe est introuvable

  Scenario: L'assiduité compte les présents sur les présents possibles
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo'}
    And une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-12'} avec {'Léa'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then l'assiduité du groupe est de {3} présences sur {6} possibles en {2} séances
    And l'assiduité de {'Léa'} est de {2} sur {2}

  Scenario: Un élève arrivé en cours de saison n'est pas pénalisé
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo, Hugo'}
    And {'Eve'} rejoint le groupe {'Jeunes'} le {'2026-10-08'}
    And une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-12'} avec {'Léa, Théo, Hugo, Eve'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then l'assiduité du groupe est de {7} présences sur {7} possibles en {2} séances

  Scenario: Une séance future n'est pas comptée
    Given une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-05'} avec {'Léa, Théo, Hugo'}
    And une séance du groupe {'Jeunes'} a eu lieu le {'2026-10-19'} avec {'Léa'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then l'assiduité du groupe est de {3} présences sur {3} possibles en {1} séances

  Scenario: Sans séance saisie, l'assiduité ne dit pas zéro pour cent
    When j'ouvre la grille du groupe {'Jeunes'}
    Then l'assiduité du groupe indique qu'aucune séance n'est saisie

  Scenario: Quatre élèves sur huit en échec sur une technique lèvent une alerte de groupe
    Given les élèves {'Ana, Bob, Cléo, Dan, Eli'} rejoignent le groupe {'Jeunes'} le {'2026-09-01'}
    And {'Léa, Théo, Hugo, Ana'} ont échoué {1} passages sur {'posture 1'} le {'2026-10-12'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then le groupe a une alerte sur la technique {'posture'} avec {4} élèves sur {8}

  Scenario: Trois élèves sur huit ne lèvent pas d'alerte de groupe
    Given les élèves {'Ana, Bob, Cléo, Dan, Eli'} rejoignent le groupe {'Jeunes'} le {'2026-09-01'}
    And {'Léa, Théo, Hugo'} ont échoué {1} passages sur {'posture 1'} le {'2026-10-12'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then le groupe n'a aucune alerte

  Scenario: Des élèves en échec qui ne pratiquent plus depuis longtemps ne lèvent pas d'alerte
    Given {'Léa, Théo'} ont échoué {1} passages sur {'posture 1'} le {'2026-09-10'}
    And le groupe {'Jeunes'} a tenu {4} séances sans passage à partir du {'2026-10-01'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then le groupe n'a aucune alerte

  Scenario: Un seul élève en échec ne lève pas d'alerte de groupe
    Given {'Léa'} a échoué {1} passages sur {'posture 1'} le {'2026-10-12'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then le groupe n'a aucune alerte

  Scenario: Le seuil de part d'échec des réglages s'applique
    Given {'Léa, Théo'} ont échoué {1} passages sur {'posture 1'} le {'2026-10-12'}
    And je règle {'part échec groupe'} à {80}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then le groupe n'a aucune alerte

  Scenario: Acquitter une alerte individuelle ne change pas l'alerte de groupe
    Given {'Léa, Théo'} ont échoué {3} passages sur {'posture 1'} le {'2026-10-12'}
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    When j'ouvre la grille du groupe {'Jeunes'}
    Then le groupe a une alerte sur la technique {'posture'} avec {2} élèves sur {3}

  Scenario: L'accueil liste trois alertes de groupe au plus
    Given {'Léa, Théo'} ont échoué {1} passages sur {'posture 1'} le {'2026-10-12'}
    And {'Léa, Théo'} ont échoué {1} passages sur {'puissance 1'} le {'2026-10-12'}
    And {'Léa, Théo'} ont échoué {1} passages sur {'bille-fantome 1'} le {'2026-10-12'}
    And {'Léa, Théo'} ont échoué {1} passages sur {'bille-pleine 1'} le {'2026-10-12'}
    When j'ouvre les alertes de groupe
    Then {3} alertes de groupe sont affichées sur {4}
    And la première alerte de groupe porte sur la technique {'posture'} du groupe {'Jeunes'}
