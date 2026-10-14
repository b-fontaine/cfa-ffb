# Parcours (e) : historique des séances saisies, correction et suppression
# d'un passage (ADR 0006). Les séances amorcées par « has {n} passes » datent
# du 12 septembre 2026 puis des jours suivants, deux passages par séance au
# plus ; « puissance 1 » demande 7 billes sur 9.
Feature: Recorded sessions history

  Background:
    Given the club has the student {'Léa'} in the {'children'} audience

  Scenario: The results tab lists no session at first
    Given the app is running
    When I tap {'Results'} text
    Then I see {'Recorded sessions'} text
    And I see {'No session recorded yet.'} text
    And I see {'New session'} text

  Scenario: A recorded session appears with its date, group, presence and passes
    Given {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Results'} text
    Then I see text containing {'Sep 12'}
    And I see {'Children group · Children'} text
    And I see {'1 present'} text
    And I see {'2 passes'} text

  Scenario: The newest session comes first
    Given {'Léa'} has {3} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Results'} text
    Then the session of {'Sep 13'} is listed before the session of {'Sep 12'}

  Scenario: A session opens from the history
    Given {'Léa'} has {1} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Results'} text
    And I open the recorded session of {'Sep 12'}
    Then I see text containing {'Session of'}
    And I see {'Léa · La puissance · exercise 1: 7 of 9'} text

  Scenario: The new session button opens the record form
    Given the app is running
    When I tap {'Results'} text
    And I tap {'New session'} text
    Then I see {'Record the results'} text
    And I see {'Open the session'} text

  Scenario: Correcting a pass updates the session and the student's result
    Given {'Léa'} has {1} failed passes on {'puissance 1'}
    And the app is running
    When I tap {'Results'} text
    And I open the recorded session of {'Sep 12'}
    And I edit the pass {'6 of 9'} of {'Léa'}
    And I add {1} balls potted in the correction
    And I tap {'Save the correction'} text
    Then I see {'Pass corrected: 7 of 9'} text
    And I see {'Léa · La puissance · exercise 1: 7 of 9'} text
    When I open the sheet of {'Léa'}
    Then I see {'Attempt 1: 7 of 9'} text
    And I do not see {'Last pass missed'} text

  Scenario: Deleting a pass frees a slot in the session after confirmation
    Given {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Results'} text
    And I open the recorded session of {'Sep 12'}
    And I delete the pass {'7 of 9'} of {'Léa'}
    Then I see {'Delete this pass?'} text
    When I tap {'Confirm'} text
    Then I see {'Pass deleted.'} text
    And I see {'Léa · La puissance · exercise 1: 7 of 9'} text
    And the club keeps {1} passes in total
    When I choose the exercise {'La puissance · no. 1 (7/9)'}
    Then I see {'1 of 2 passes'} text
    When I tap {'Results'} text
    Then I see {'1 pass'} text

  Scenario: Cancelling a deletion keeps the pass
    Given {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I tap {'Results'} text
    And I open the recorded session of {'Sep 12'}
    And I delete the pass {'7 of 9'} of {'Léa'}
    And I tap {'Cancel'} text
    Then I see {'Léa · La puissance · exercise 1: 7 of 9'} text {2} times
    And the club keeps {2} passes in total

  # La saisie connaît la séance du catalogue qu'elle note (ADR 0007).
  Scenario: A recorded session names the catalogue session it noted
    Given a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'puissance-1'}
    And the app is running
    When I tap {'Results'} text
    Then I see {'Catalogue session: La puissance, session 1/2'} text
    And I do not see text containing {'Main notion:'}
