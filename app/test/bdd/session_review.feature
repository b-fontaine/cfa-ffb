# Lot U7 : à « Terminer » la séance guidée, le bilan récapitule les passages
# saisis, les validations du jour, les élèves à surveiller, et propose la
# séance suivante du catalogue avec « Planifier » (report du lot 8).
Feature: Session summary

  Scenario: Finishing a guided session with recorded results opens the summary
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    And I tap {'Open the session'} text
    And I add {4} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    And I tap {'Back to the guided session'} text
    And I tap {'End session'} text
    And I tap {'Confirm'} text
    Then I see {'Session summary'} text
    And I see {'1 pass entered, 1 successful'} text
    And I see {'Quantité demi-bille, session 1/2'} text

  Scenario: Finishing a guided session without recorded results returns where it came from
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'End session'} text
    And I tap {'Confirm'} text
    Then I do not see {'Session summary'} text
    And I see text containing {'Quantité demi-bille, session 1/2'}

  Scenario: A finished guided session is no longer offered to resume
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    And I tap {'Open the session'} text
    And I add {4} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    And I tap {'Back to the guided session'} text
    And I tap {'End session'} text
    And I tap {'Confirm'} text
    And I tap {'Back to Today'} text
    Then I do not see {'In progress'} text

  Scenario: The summary names the sheet, the group, the date and the present students
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'Posture, visée et coup de queue, session 1/2'} text
    And I see {'Mon, Oct 12 · Children group · 2 students present'} text

  Scenario: The summary lists the passes entered per exercise
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'1 pass entered, 1 successful'} text
    And I see {'Posture, visée et coup de queue · exercise 1 · Proposal'} text

  Scenario: An exercise validated by this session is listed with the student
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {4} successful passes on {'posture 1'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'Validated during this session'} text
    And I see {'Léa validated Posture, visée et coup de queue · exercise 1 · Proposal'} text

  Scenario: An exercise validated in an earlier session is not listed
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {5} successful passes on {'posture 1'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'No exercise validated by this session.'} text

  Scenario: Present students without any pass are named
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'Present without a pass'} text
    And I see {'Hugo'} text

  Scenario: A present student with an active alert is to watch
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'posture 1'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'To watch'} text
    And I see text containing {'3 failures in a row'}

  Scenario: The summary proposes the next catalogue session of the group
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'Next session'} text
    And I see {'Session 2/2'} text
    And I see {'Proposed for Mon, Oct 19'} text
    And I see {'Plan'} text

  Scenario: A record without any pass shows no next session and offers to enter results
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'No pass entered for this session.'} text
    And I do not see {'Next session'} text
    When I tap {'Enter the results'} text
    Then I see {'Record the results'} text

  Scenario: Plan creates a dated session planned for the group
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    And I tap {'Plan'} text
    Then I see {'Planned for Mon, Oct 19'} text
    And the group {'Children group'} has a planned session with the catalogue session {'posture-2'} on {'2026-10-19'}
    And I do not see {'Plan'} text

  Scenario: The planned session appears on the home as the next session
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    And I tap {'Plan'} text
    And I tap {'Back to Today'} text
    Then I see {'Next'} text
    And I see text containing {'Mon, Oct 19'}

  Scenario: A session already planned for the group is shown instead of the Plan button
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-19'} with the catalogue session {'posture-2'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then I see {'Already planned for Mon, Oct 19'} text
    And I do not see {'Plan'} text

  Scenario: Changing the proposed date is reflected in the planned session
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    And I tap {'Change the date'} text
    And I pick the day {21} in the date picker
    Then I see {'Proposed for Wed, Oct 21'} text
    When I tap {'Plan'} text
    Then the group {'Children group'} has a planned session with the catalogue session {'posture-2'} on {'2026-10-21'}
