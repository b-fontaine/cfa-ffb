# Filet des marqueurs abandonnés (FB8 partie B, tranche B5 ; ADR 0024 décision
# 19 ; décision D4 du 2026-10-24). Un marqueur d'import
# (`imports/{empreinte}_{uid}`) ou d'opération (`operations/{empreinte}_{uid}`)
# dont le dernier lot (`updatedAt`) a plus de 90 jours est réputé abandonné :
# auteur parti (compte supprimé) ou opération jamais reprise. Le directeur ou
# l'administrateur le supprime depuis « Mon club », quel qu'en soit l'auteur ;
# jamais un marqueur récent, jamais celui d'un autre club ; l'enseignant n'y a
# pas accès. Lots de 400 au plus, plafond quotidien partagé avec l'import.
# Le club est un faux Firestore en mémoire qui applique les garde-fous des
# règles (liste de plage sur `updatedAt`, suppression d'un marqueur ancien par
# un gestionnaire, horloge du serveur) ; les règles réelles sont jouées contre
# l'émulateur par scripts/rules_test/stale_markers.test.mjs.
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français.
Feature: Purger les marqueurs abandonnés du club

  Background:
    Given un club synchronisé où des marqueurs vieillissent
    And le compte {'parti'} a laissé {2} marqueurs d'import et {1} marqueurs d'opération il y a {120} jours
    And le compte {'enseignant'} a laissé {1} marqueurs d'import et {0} marqueurs d'opération il y a {10} jours

  Scenario: Un directeur nettoie les marqueurs anciens d'un compte supprimé
    When le compte {'directeur'} purge les marqueurs abandonnés du club
    Then {3} marqueurs abandonnés ont été supprimés
    And le compte {'parti'} garde {0} marqueurs dans le club
    And le compte {'enseignant'} garde {1} marqueurs dans le club

  Scenario: L'administrateur nettoie aussi les marqueurs anciens
    When le compte {'administrateur'} purge les marqueurs abandonnés du club
    Then {3} marqueurs abandonnés ont été supprimés
    And le compte {'parti'} garde {0} marqueurs dans le club

  Scenario: Un marqueur de moins de 90 jours n'est pas supprimé
    Given le compte {'parti'} a laissé {1} marqueurs d'import et {1} marqueurs d'opération il y a {89} jours
    When le compte {'directeur'} purge les marqueurs abandonnés du club
    Then {3} marqueurs abandonnés ont été supprimés
    And le compte {'parti'} garde {2} marqueurs dans le club

  Scenario: Le marqueur ancien d'un autre club n'est jamais touché
    Given dans un autre club, le compte {'parti'} a laissé {2} marqueurs d'import il y a {200} jours
    When le compte {'directeur'} purge les marqueurs abandonnés du club
    Then {3} marqueurs abandonnés ont été supprimés
    And il reste {2} marqueurs dans l'autre club

  Scenario: Un enseignant n'y a pas accès : rien n'est lu ni supprimé
    When le compte {'enseignant'} purge les marqueurs abandonnés du club
    Then la purge est refusée
    And aucun marqueur n'a été lu ni supprimé
    And le compte {'parti'} garde {3} marqueurs dans le club

  Scenario: Plus de 400 marqueurs partent en lots de 400 au plus
    Given le compte {'parti'} a laissé {450} marqueurs d'import et {0} marqueurs d'opération il y a {100} jours
    When le compte {'directeur'} purge les marqueurs abandonnés du club
    Then {453} marqueurs abandonnés ont été supprimés
    And aucun lot de purge n'a dépassé {400} suppressions

  Scenario: Le plafond quotidien partagé avec l'import suspend la purge jusqu'au lendemain
    Given le compte {'parti'} a laissé {450} marqueurs d'import et {0} marqueurs d'opération il y a {100} jours
    And {9550} écritures ont déjà été faites aujourd'hui sur cet appareil
    When le compte {'directeur'} purge les marqueurs abandonnés du club
    Then la purge est suspendue jusqu'à demain
    And {400} marqueurs abandonnés ont été supprimés
    And le compte {'parti'} garde {53} marqueurs dans le club
    When le jour suivant arrive
    And le compte {'directeur'} purge les marqueurs abandonnés du club
    Then {53} marqueurs abandonnés ont été supprimés
    And le compte {'parti'} garde {0} marqueurs dans le club

  Scenario: Serveur injoignable : rien n'est supprimé, la purge se relance
    Given le serveur est injoignable
    When le compte {'directeur'} purge les marqueurs abandonnés du club
    Then la purge est interrompue faute de réseau
    And le compte {'parti'} garde {3} marqueurs dans le club
    When le serveur répond de nouveau
    And le compte {'directeur'} purge les marqueurs abandonnés du club
    Then le compte {'parti'} garde {0} marqueurs dans le club

  Scenario: Sur « Mon club », le directeur lit l'avertissement puis purge
    When le directeur ouvre la purge des marqueurs abandonnés de « Mon club »
    Then I see text containing {'rétablir les élèves effacés'}
    When I tap {'Supprimer les marqueurs abandonnés'} text
    Then I see {'3 marqueurs abandonnés supprimés.'} text
    And le compte {'parti'} garde {0} marqueurs dans le club

  Scenario: Sur « Mon club », sans marqueur abandonné, rien n'est supprimé
    Given le compte {'parti'} n'a plus aucun marqueur dans le club
    When le directeur ouvre la purge des marqueurs abandonnés de « Mon club »
    And I tap {'Supprimer les marqueurs abandonnés'} text
    Then I see {'Aucun marqueur abandonné.'} text
