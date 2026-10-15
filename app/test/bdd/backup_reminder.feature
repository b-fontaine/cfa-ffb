# Lot U6 (R6) : rappel de sauvegarde sur « Aujourd'hui », sobre et non bloquant.
Feature: Backup reminder

  Scenario: No reminder before any pass is entered
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    Then I do not see {'Back up now'} text

  Scenario: Passes never backed up trigger a reminder
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    Then I see text containing {'never been backed up'}
    And I see {'Back up now'} text

  Scenario: The reminder leads to the backup screen
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Back up now'} text
    Then I see {'Export a backup (JSON)'} text

  Scenario: A fresh backup silences the reminder
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Back up now'} text
    And I tap {'Export a backup (JSON)'} text
    And I tap {'Today'} text
    Then I do not see {'Back up now'} text

  Scenario: Passes entered after a backup bring the reminder back
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Back up now'} text
    And I tap {'Export a backup (JSON)'} text
    And {'Léa'} has {3} successful passes on {'puissance 2'}
    And I tap {'Today'} text
    Then I see text containing {'3 passes entered since the last backup'}

  Scenario: A backup older than 30 days brings the reminder back
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Back up now'} text
    And I tap {'Export a backup (JSON)'} text
    And the day advances by {31} days
    And I tap {'Today'} text
    Then I see text containing {'31 days ago'}

  Scenario: A cancelled export keeps the reminder
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the backup dialog is cancelled
    And the app is running
    When I tap {'Back up now'} text
    And I tap {'Export a backup (JSON)'} text
    And I tap {'Today'} text
    Then I see {'Back up now'} text
