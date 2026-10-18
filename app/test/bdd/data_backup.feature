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
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And je planifie la séance {'Cours de demi-bille'} pour le groupe {'Jeunes'} le {'2026-10-12'} avec la séance du catalogue {'demi-bille-2'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    Then la séance planifiée {'Cours de demi-bille'} est liée à la séance du catalogue {'demi-bille-2'}

  Scenario: Refuser une sauvegarde dont la séance du catalogue est inconnue
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And je planifie la séance {'Cours de demi-bille'} pour le groupe {'Jeunes'} le {'2026-10-12'} avec la séance du catalogue {'demi-bille-2'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec une séance planifiée du catalogue inconnue
    Then l'import est refusé avec le motif {'backupUnknownSheet'}
    And aucune séance planifiée n'est enregistrée

  Scenario: Conserver la date, le groupe et la séance du catalogue des séances
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And je planifie la séance {'Cours'} pour le groupe {'Jeunes'} le {'2026-10-19'} avec la séance du catalogue {'demi-bille-2'}
    And la séance du groupe {'Jeunes'} le {'2026-10-19'} note la séance du catalogue {'demi-bille-2'} avec {'Léa'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    Then la séance planifiée {'Cours'} est prévue le {'2026-10-19'} pour le groupe {'Jeunes'}
    And la séance planifiée {'Cours'} est liée à la séance du catalogue {'demi-bille-2'}
    And la séance saisie du groupe {'Jeunes'} le {'2026-10-19'} note la séance du catalogue {'demi-bille-2'}

  # ADR 0016 : deux saisies d'un même groupe le même jour (séances du
  # catalogue différentes) sont stockables ; l'aller-retour les conserve.
  Scenario: Restaurer deux saisies d'un même groupe le même jour
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance du groupe {'Jeunes'} le {'2026-10-19'} note la séance du catalogue {'posture-1'} avec {'Léa'}
    And la séance du groupe {'Jeunes'} le {'2026-10-19'} note la séance du catalogue {'demi-bille-2'} avec {'Léa'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    Then le groupe {'Jeunes'} compte {2} séances saisies le {'2026-10-19'}
    And le groupe {'Jeunes'} a une séance saisie le {'2026-10-19'} pour la séance du catalogue {'posture-1'}
    And le groupe {'Jeunes'} a une séance saisie le {'2026-10-19'} pour la séance du catalogue {'demi-bille-2'}

  # Lot 7 (ADR 0008) : les blocs acquis au positionnement font partie de la
  # sauvegarde.
  Scenario: Restaurer les blocs acquis au positionnement
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a le bloc {'puissance'} acquis au positionnement le {'2026-09-15'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    Then le club compte {1} blocs acquis
    And {'Léa'} garde le bloc {'puissance'} acquis au positionnement le {'2026-09-15'}

  Scenario: Refuser une sauvegarde dont un bloc acquis est inconnu du catalogue
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a le bloc {'puissance'} acquis au positionnement le {'2026-09-15'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec un bloc acquis inconnu
    Then l'import est refusé avec le motif {'backupUnknownBlock'}
    And le club compte {0} blocs acquis

  # Lot 9 (ADR 0012) : les réglages font partie de la sauvegarde (format 2) ;
  # un fichier du format 1 reste lisible.
  Scenario: La sauvegarde exportée contient les réglages
    Given je règle {'passages requis'} à {3}
    When j'exporte une sauvegarde du club
    Then la sauvegarde contient le réglage {'passages requis'} à {3}

  Scenario: Restaurer les réglages avec les données
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And je règle {'passages requis'} à {3}
    And je règle {'délai rappel sauvegarde'} à {14}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    Then le club compte {1} élèves et {0} passages
    And le réglage {'passages requis'} vaut {3}
    And le réglage {'délai rappel sauvegarde'} vaut {14}

  Scenario: Importer un fichier du format 1 sans réglages garde les valeurs par défaut d'un club neuf
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {5} passages sur {'puissance 1'} lors de séances précédentes
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde de format {1} sans réglages dans un club vide
    Then le club compte {1} élèves et {5} passages
    And le réglage {'passages requis'} vaut {5}

  Scenario: Importer un fichier sans réglages laisse les réglages du club inchangés
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde sans réglages dans un club vide réglé à {3} passages requis
    Then le club compte {1} élèves et {0} passages
    And le réglage {'passages requis'} vaut {3}

  Scenario: Refuser une sauvegarde dont un réglage est hors bornes sans rien écrire
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And {'Léa'} a réussi {5} passages sur {'puissance 1'} lors de séances précédentes
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec le réglage {'seuil alerte'} à {9}
    Then l'import est refusé avec le motif {'backupInvalid'}
    And le club compte {0} élèves et {0} passages
    And le réglage {'seuil alerte'} vaut {3}

  # ADR 0023 : les étiquettes de la note de jeu d'une séance (liste fermée, sans
  # texte libre) font partie de la sauvegarde du format 5.
  Scenario: Conserver les étiquettes d'une séance saisie
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance du groupe {'Jeunes'} le {'2026-10-19'} note la séance du catalogue {'posture-1'} avec {'Léa'}
    And je pose les étiquettes {'tooLong,toRedo'} sur la séance saisie du groupe {'Jeunes'} le {'2026-10-19'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide
    Then la séance saisie du groupe {'Jeunes'} le {'2026-10-19'} porte les étiquettes {'tooLong,toRedo'}

  Scenario: Importer un fichier du format 4 donne des séances sans étiquettes
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance du groupe {'Jeunes'} le {'2026-10-19'} note la séance du catalogue {'posture-1'} avec {'Léa'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde au format {4} sans étiquettes dans un club vide
    Then la séance saisie du groupe {'Jeunes'} le {'2026-10-19'} ne porte aucune étiquette

  Scenario: Refuser une sauvegarde dont une étiquette est inconnue sans rien écrire
    Given le groupe {'Jeunes'} de public {'enfants'} compte l'élève {'Léa'}
    And la séance du groupe {'Jeunes'} le {'2026-10-19'} note la séance du catalogue {'posture-1'} avec {'Léa'}
    And j'exporte une sauvegarde du club
    When j'importe cette sauvegarde dans un club vide avec l'étiquette {'Léa a pleuré'}
    Then l'import est refusé avec le motif {'backupInvalid'}
    And le club compte {0} élèves et {0} passages
