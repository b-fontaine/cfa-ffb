# Clôture de saison dans un club synchronisé : purge des invitations (FB8,
# partie B, tranche B3 ; ADR 0025 décision 6 : « purgées à la clôture de
# saison » ; décision D3 du 2026-10-24). La clôture supprime les invitations
# UTILISÉES ou ÉCHUES du club (une invitation révoquée est déjà supprimée) ;
# une invitation encore valable et celles d'un autre club restent. Le directeur
# ne lit ni ne supprime une invitation de DIRECTEUR (les règles ne la lui
# listent pas) : la clôture de l'administrateur, elle, la purge.
# Le club est un faux Firestore en mémoire qui applique les garde-fous des
# règles (liste bornée au club et au rôle, suppression par un gestionnaire du
# club) ; les règles réelles sont jouées par scripts/rules_test/invitations.test.mjs.
# Mots-clés Gherkin en anglais (voir docs/engineering/testing.md) ; libellés en
# français.
Feature: Purger les invitations du club à la clôture de saison

  Background:
    Given un club synchronisé de {2} groupes de {4} élèves ayant chacun {3} passages

  Scenario: La clôture supprime les invitations utilisées et échues du club, et seulement elles
    Given une invitation {'VALIDTEACH'} de rôle {'teacher'} du club {'c1'}, {'valable'}
    And une invitation {'USEDSTUDNT'} de rôle {'student'} du club {'c1'}, {'utilisée'}
    And une invitation {'OLDGUARDAA'} de rôle {'guardian'} du club {'c1'}, {'échue'}
    And une invitation {'OLDTEACHAA'} de rôle {'teacher'} du club {'c1'}, {'échue'}
    And une invitation {'OTHERCLUBA'} de rôle {'teacher'} du club {'c2'}, {'échue'}
    When le directeur clôt la saison en effaçant {2} élèves par groupe
    Then la clôture est terminée
    And il reste les invitations {'OTHERCLUBA, VALIDTEACH'}
    And aucun marqueur d'opération ne reste

  Scenario: L'aperçu de la clôture compte les invitations à supprimer
    Given une invitation {'VALIDTEACH'} de rôle {'teacher'} du club {'c1'}, {'valable'}
    And une invitation {'USEDSTUDNT'} de rôle {'student'} du club {'c1'}, {'utilisée'}
    And une invitation {'OLDGUARDAA'} de rôle {'guardian'} du club {'c1'}, {'échue'}
    And une invitation {'OTHERCLUBA'} de rôle {'teacher'} du club {'c2'}, {'échue'}
    Then l'aperçu de la clôture annonce {2} invitations à supprimer
    And l'aperçu n'a rien écrit

  Scenario: La clôture du directeur ne lit pas les invitations de directeur, celle de l'administrateur les purge
    Given une invitation {'DIRECTORAA'} de rôle {'director'} du club {'c1'}, {'échue'}
    And une invitation {'OLDGUARDAA'} de rôle {'guardian'} du club {'c1'}, {'échue'}
    Then l'aperçu de la clôture annonce {1} invitations à supprimer
    When le directeur clôt la saison en effaçant {0} élèves par groupe
    Then la clôture est terminée
    And il reste les invitations {'DIRECTORAA'}
    And aucune liste d'invitations de directeur n'a été demandée par le directeur

  Scenario: La clôture de l'administrateur purge aussi les invitations de directeur
    Given une invitation {'DIRECTORAA'} de rôle {'director'} du club {'c1'}, {'utilisée'}
    And une invitation {'OLDGUARDAA'} de rôle {'guardian'} du club {'c1'}, {'échue'}
    And une invitation {'OTHERCLUBA'} de rôle {'director'} du club {'c2'}, {'échue'}
    When un administrateur clôt la saison, {0} élèves effacés par groupe
    Then il reste les invitations {'OTHERCLUBA'}

  Scenario: Une purge de nombreuses invitations interrompue se reprend
    Given le club a {450} invitations échues
    When le directeur clôt la saison, connexion coupée après le premier lot d'invitations
    Then la clôture est interrompue
    And il reste {51} invitations
    When le directeur reprend la clôture
    Then la clôture est terminée
    And il reste les invitations {''}
    And aucun lot n'a dépassé {400} écritures
    And l'avancement annoncé de la clôture a atteint son dernier lot
    And aucun marqueur d'opération ne reste

  Scenario: Une invitation révoquée pendant la clôture fait échouer le lot, et la reprise termine
    Given une invitation {'USEDSTUDNT'} de rôle {'student'} du club {'c1'}, {'utilisée'}
    And une invitation {'OLDTEACHAA'} de rôle {'teacher'} du club {'c1'}, {'échue'}
    And l'invitation {'OLDTEACHAA'} est révoquée juste avant le lot qui la supprime
    When le directeur clôt la saison en effaçant {0} élèves par groupe
    Then la clôture a échoué
    And il reste les invitations {'USEDSTUDNT'}
    When le directeur reprend la clôture
    Then la clôture est terminée
    And il reste les invitations {''}
    And aucun marqueur d'opération ne reste
