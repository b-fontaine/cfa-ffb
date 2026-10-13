# Parcours (b) : fiche élève, progression par bloc et courbes de performance.
Feature: Student sheet

  Scenario: Progress per block and next exercise
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Léa'} has {5} successful passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'La puissance · exercise 2'} text
    And I see {'25 % validated'} text
    And I see {'5 of 72 exercises validated'} text

  Scenario: The performance curve shows each attempt with a text alternative
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And {'Léa'} has {1} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see the curve of {'puissance 1'} with {3} attempts
    And I see {'Attempt 1: 7 of 9'} text
    And I see {'Attempt 3: 6 of 9'} text

  Scenario: A notion to recall is suggested after a missed pass
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'puissance'}
    And {'Léa'} has {1} failed passes on {'puissance 2'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Notion to recall'} text
    And I see {'La puissance, exercise 2'} text
    And I see {'Last pass missed'} text

  Scenario: A student sheet opens from its direct link
    Given the club has the student {'Léa'} in the {'adults'} audience
    And the app is running
    When I go to the address of the sheet of {'Léa'}
    Then I see {'Léa'} text
    And I see {'Adults'} text

  Scenario: Three failed passes raise a warning on the sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Warning'} text
    And I see {'La puissance · exercise 1: 3 consecutive failures'} text
    And I do not see {'Action needed'} text

  Scenario: Five failed passes make the alert persistent
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {5} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Action needed'} text
    And I see {'La puissance · exercise 1: 5 consecutive failures'} text
    And I do not see {'Warning'} text

  Scenario: A student without repeated failures has no alert on the sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I do not see {'Warning'} text
    And I do not see {'Action needed'} text

  Scenario: Erasing a student removes all their data after confirmation
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And {'Hugo'} has {1} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    Then I see {'Erase Léa permanently?'} text
    When I tap {'Confirm'} text
    Then I see {'Hugo'} text
    And I do not see {'Léa'} text
    And the club keeps no data for {'Léa'}
    And the club keeps {1} passes in total

  Scenario: Cancelling the erasure keeps the student and their data
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    And I tap {'Cancel'} text
    Then I see {'Léa'} text
    And the club keeps {2} passes in total
