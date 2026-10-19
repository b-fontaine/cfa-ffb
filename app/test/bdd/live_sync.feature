# Lot FB5b (ADR 0024, B4 et B5) : les écrans qui montrent des données partagées
# se mettent à jour quand un AUTRE appareil du même club écrit, sans
# rechargement. Deux appareils sur un même serveur : celui de l'écran (dépôts
# Firestore, connexion qui peut tomber) et un autre appareil (graphe complet,
# directeur du même club) qui écrit sur le même double de serveur. Le texte par
# défaut est l'anglais. « Aujourd'hui » est le lundi 12 octobre 2026.
Feature: Live synchronization between devices

  Background:
    Given the club data lives on a server shared with other devices
    And the club has the student {'Léa'} in the {'children'} audience

  Scenario: The sheet of a student follows a pass recorded on another device
    Given the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Path to start'} text
    When {'Léa'} has {5} successful passes on {'puissance 1'}
    Then I see {'1 exercise validated'} text
    And I do not see {'Path to start'} text

  Scenario: The list of students follows a student enrolled on another device
    Given the app is running
    When I tap {'Students'} text
    Then I see {'Léa'} text
    When the club has the student {'Zoé'} in the {'children'} audience
    Then I see {'Zoé'} text
    And I see {'Léa'} text

  Scenario: The home screen follows a session planned on another device
    Given the app is running
    Then I do not see {'Rebond au centre'} text
    When a session {'Rebond au centre'} is planned for the group {'Children group'} on {'2026-10-14'} without a catalogue session
    Then I see {'Rebond au centre'} text

  Scenario: Leaving a screen leaves no subscription behind
    Given the app is running
    When I tap {'Students'} text
    And I note the number of open subscriptions
    And I tap {'Léa'} text
    And I tap the back button
    Then I see {'Léa'} text
    And the number of open subscriptions is the one noted

  Scenario: A device that loses its rights stops listening and says so
    Given the app is running
    When I open the sheet of {'Léa'}
    And the device is no longer a member of the club
    Then I see {'You are not allowed to do this.'} text
    And no subscription stays open on the shared server

  Scenario: A device that was offline catches up when the connection returns
    Given the app is running
    When I open the sheet of {'Léa'}
    And the device loses its connection to the server
    And {'Léa'} has {5} successful passes on {'puissance 1'}
    Then I see {'Path to start'} text
    When the device gets its connection to the server back
    Then I see {'1 exercise validated'} text

  Scenario: A screen keeps following the data when the scope of the account changes
    Given the app is running
    When I open the sheet of {'Léa'}
    And the account of the device receives the group {'Children group'}
    And {'Léa'} has {5} successful passes on {'puissance 1'}
    Then I see {'1 exercise validated'} text
    When {'Léa'} has {5} successful passes on {'posture 1'}
    Then I see {'2 exercises validated'} text
