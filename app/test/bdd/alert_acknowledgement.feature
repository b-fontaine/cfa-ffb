# Lot U9 / lot 10 (ADR 0013), domaine et persistance : l'animateur acquitte
# l'alerte d'un élève (« Vu »). L'acquittement masque l'alerte sur les
# surfaces de surveillance (fiche, accueil, bilan, liste des élèves) tant que
# le dernier passage de l'exercice est celui du « Vu » ; il ne touche ni aux
# passages, ni à la notion à rappeler, ni à la séance suggérée. « Aujourd'hui »
# est le 2026-10-12.
Feature: Acquittement d'une alerte

  Background:
    Given le club suit la saison {'2026-2027'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Théo'}

  Scenario: Une alerte vue disparaît de la fiche et des élèves à surveiller
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    When j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'ouvre la fiche de {'Léa'}
    And j'ouvre l'accueil du jour
    Then l'en-tête n'a aucune alerte
    And l'alerte de l'en-tête sur {'posture 1'} est vue le {'2026-10-12'}
    And aucun élève n'est à surveiller

  Scenario: Seule l'alerte vue disparaît, les autres élèves restent à surveiller
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And {'Théo'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    When j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'ouvre l'accueil du jour
    Then les élèves à surveiller sont {'Théo'}

  Scenario: Une alerte vue disparaît du bilan de séance
    Given {'Théo'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And la séance {'posture-1'} du catalogue a été donnée au groupe {'Jeunes'} le {'2026-10-12'}
    When j'acquitte l'alerte de {'Théo'} sur {'posture 1'}
    And je demande le bilan de la dernière saisie
    Then aucun élève n'est à surveiller dans le bilan

  Scenario: Une alerte vue disparaît de la liste des élèves
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    When j'ouvre la liste des élèves
    Then {'Léa'} a {1} alertes dans la liste
    When j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'ouvre la liste des élèves
    Then {'Léa'} a {0} alertes dans la liste

  Scenario: Un nouveau passage échoué fait réapparaître l'alerte avec le nouveau compte
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    When {'Léa'} a échoué {1} passages sur {'posture 1'} le {'2026-10-12'}
    And j'ouvre la fiche de {'Léa'}
    Then l'alerte de l'en-tête porte sur {'posture 1'} avec {4} échecs

  Scenario: Un passage réussi résout l'alerte et l'acquittement reste dormant
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    When {'Léa'} a réussi {1} passages sur {'posture 1'} le {'2026-10-12'}
    And j'ouvre la fiche de {'Léa'}
    Then l'en-tête n'a aucune alerte
    And le club garde {1} acquittements en tout

  Scenario: Une alerte vue peut être rétablie
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    When je rétablis l'alerte de {'Léa'} sur {'posture 1'}
    And j'ouvre la fiche de {'Léa'}
    Then l'alerte de l'en-tête porte sur {'posture 1'} avec {3} échecs
    And le club garde {0} acquittements en tout

  Scenario: Une alerte rétablie peut être vue de nouveau
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And je rétablis l'alerte de {'Léa'} sur {'posture 1'}
    When j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'ouvre la fiche de {'Léa'}
    Then l'en-tête n'a aucune alerte

  Scenario: Sans alerte active, l'acquittement est refusé
    Given {'Léa'} a échoué {2} passages sur {'posture 1'} lors de séances précédentes
    When j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    Then l'acquittement est refusé avec le motif {'aucune alerte active'}
    And le club garde {0} acquittements en tout

  Scenario: Un exercice inconnu est refusé
    When j'acquitte l'alerte de {'Léa'} sur {'posture 9'}
    Then l'acquittement est refusé avec le motif {'exercice inconnu'}

  Scenario: Acquitter ne change ni la notion à rappeler ni la séance suggérée
    Given le groupe {'Adultes'} de public {'adultes'} compte l'élève {'Marc'}
    And le groupe {'Adultes'} de public {'adultes'} compte l'élève {'Sophie'}
    And {'Marc, Sophie'} ont validé tous les exercices avant {'puissance 3'}
    And {'Marc'} a échoué {3} passages sur {'bille-fantome 1'} lors de séances précédentes
    And {'Sophie'} a échoué {3} passages sur {'bille-fantome 1'} lors de séances précédentes
    When je demande la séance suggérée du groupe {'Adultes'} pour {'Marc, Sophie'}
    Then la notion à rappeler est {'bille-fantome'}
    And le premier exercice est {'puissance 3'}
    When j'acquitte l'alerte de {'Marc'} sur {'bille-fantome 1'}
    And j'acquitte l'alerte de {'Sophie'} sur {'bille-fantome 1'}
    And je demande la séance suggérée du groupe {'Adultes'} pour {'Marc, Sophie'}
    Then la notion à rappeler est {'bille-fantome'}
    And le premier exercice est {'puissance 3'}

  Scenario: Les acquittements survivent à un export puis un import
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    And j'ouvre la fiche de {'Léa'}
    Then l'en-tête n'a aucune alerte
    And le club garde {1} acquittements en tout

  Scenario: Une sauvegarde de l'ancien format s'importe sans acquittement
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde au format {2} sans acquittements dans un club vide
    And j'ouvre la fiche de {'Léa'}
    Then l'alerte de l'en-tête porte sur {'posture 1'} avec {3} échecs
    And le club garde {0} acquittements en tout

  Scenario: Importer l'ancien format efface les acquittements en place
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'exporte une sauvegarde du club
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    When j'importe à nouveau cette sauvegarde au format {1} sans acquittements
    Then le club garde {0} acquittements en tout

  Scenario: Une clé d'acquittements dans un ancien format est refusée sans rien écrire
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec la version {2}
    Then l'import est refusé avec le motif {'backupInvalid'}
    And le club compte {0} élèves et {0} passages
    And le club garde {0} acquittements en tout

  Scenario: Effacer un élève efface ses acquittements
    Given {'Léa'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And {'Théo'} a échoué {3} passages sur {'posture 1'} lors de séances précédentes
    And j'acquitte l'alerte de {'Léa'} sur {'posture 1'}
    And j'acquitte l'alerte de {'Théo'} sur {'posture 1'}
    When j'efface l'élève {'Léa'}
    Then le club garde {1} acquittements en tout
