# Parcours (f) : sauvegarde JSON, import avec prévisualisation, persistance volatile.
Feature: Backup screen

  Scenario: Exporting a backup saves a JSON file
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'More'} text
    And I tap {'Backup'} text
    And I tap {'Export a backup (JSON)'} text
    Then I see {'Backup saved.'} text
    And the saved backup file contains {'Léa'}

  Scenario: A browser download counts as a saved backup
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the browser downloads backups without a location
    And the app is running
    When I tap {'Back up now'} text
    And I tap {'Export a backup (JSON)'} text
    Then I see {'Backup saved.'} text
    And the downloaded backup contains {'Léa'}
    When I tap {'Today'} text
    Then I do not see {'Back up now'} text

  Scenario: Importing a backup shows a preview before confirmation
    Given the app is running
    And the next picked file is a backup of the student {'Zoé'}
    When I tap {'More'} text
    And I tap {'Backup'} text
    And I tap {'Import a backup'} text
    Then I see {'1 student'} text
    And I see {'1 season'} text
    When I tap {'Import these data'} text
    Then I see {'Import complete.'} text
    And the club has {1} student

  Scenario: Cancelling the preview imports nothing
    Given the app is running
    And the next picked file is a backup of the student {'Zoé'}
    When I tap {'More'} text
    And I tap {'Backup'} text
    And I tap {'Import a backup'} text
    And I tap {'Cancel'} text
    Then the club has {0} student

  Scenario: An unreadable file is refused
    Given the app is running
    And the next picked file contains {'not a backup'}
    When I tap {'More'} text
    And I tap {'Backup'} text
    And I tap {'Import a backup'} text
    Then I see {'This file is not a readable backup.'} text
    And the club has {0} student

  Scenario: A volatile browser storage is announced
    Given the browser keeps data in memory only
    And the app is running
    When I tap {'More'} text
    And I tap {'Backup'} text
    Then I see text containing {'Data is kept in memory only'}

  Scenario: A durable storage shows no warning
    Given the app is running
    When I tap {'More'} text
    And I tap {'Backup'} text
    Then I do not see text containing {'Data is kept in memory only'}
