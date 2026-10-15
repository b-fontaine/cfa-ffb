# Parcours (c) : saisie des résultats d'une séance.
# Sans notion principale, la saisie s'ouvre sur le premier exercice du
# catalogue : « posture 1 » (bloc proposé [Prop], taux 3 sur 4), depuis que la
# posture ouvre l'ordre d'enseignement.
Feature: Recording the results of a session

  Background:
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience

  Scenario: Recording a successful pass
    Given the app is running
    When I open the session of the group {'Children group'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'Pass recorded: 3 of 4, target reached'} text
    And I see {'1 of 2 passes'} text

  Scenario: A missed pass says the target was not reached
    Given the app is running
    When I open the session of the group {'Children group'}
    And I add {2} balls potted for {'Hugo'}
    And I record the pass of {'Hugo'}
    Then I see {'Pass recorded: 2 of 4, target missed'} text

  Scenario: At most two passes per exercise and per session
    Given the app is running
    When I open the session of the group {'Children group'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'2 of 2 passes'} text
    And I see {'Maximum reached for this session'} text

  Scenario: The fifth successful pass validates the exercise
    Given {'Léa'} has {4} successful passes on {'posture 1'}
    And the app is running
    When I open the session of the group {'Children group'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'Exercise validated!'} text
    And I see {'Next exercise: Posture, visée et coup de queue · exercise 2 · Proposal'} text

  Scenario: Three consecutive failures raise an alert
    Given {'Hugo'} has {2} failed passes on {'posture 1'}
    And the app is running
    When I open the session of the group {'Children group'}
    And I record the pass of {'Hugo'}
    Then I see {'3 consecutive failures: plan a recall.'} text

  Scenario: Only the present students can be recorded
    Given the app is running
    When I open the session of the group {'Children group'} without {'Hugo'}
    Then I see {'Léa'} text
    And I do not see {'Hugo'} text

  Scenario: The attempts cannot go below those of the exercise sheet
    Given the app is running
    When I open the session of the group {'Children group'}
    And I remove {3} attempts for {'Léa'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'Pass recorded: 3 of 4, target reached'} text

  Scenario: More attempts than the sheet are judged proportionally
    Given the app is running
    When I open the session of the group {'Children group'}
    And I add {3} attempts for {'Léa'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'More attempts than the sheet: the target is judged proportionally.'} text
    And I see {'Pass recorded: 3 of 7, target missed'} text

  Scenario: A pass on an exercise acquired at placement says it takes over
    Given {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And the app is running
    When I open the session of the group {'Children group'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'Exercise acquired at placement: recorded passes now take over this exercise (1 of 5).'} text
    And I do not see {'Exercise validated!'} text

  Scenario: A pass on an ordinary exercise does not mention the placement
    Given the app is running
    When I open the session of the group {'Children group'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    Then I do not see text containing {'acquired at placement'}

  # Lot U5 (grille de saisie) : une ligne par élève présent, une pastille par
  # essai, l'état de validation à droite, les tentatives sous la ligne.
  Scenario: Each present student has a row with the validation state
    Given the app is running
    When I open the session of the group {'Children group'}
    Then I see {'0 of 5 successful passes'} text {2} times

  Scenario: Tapping four dots out of six then recording stores 4 of 6 and marks the row reached
    Given the app is running
    When I open the session of the group {'Children group'}
    And I choose the exercise {'Posture, visée et coup de queue · no. 4 (4/6) · Proposal'}
    And I tap the pass dot {1} for {'Léa'}
    And I tap the pass dot {2} for {'Léa'}
    And I tap the pass dot {3} for {'Léa'}
    And I tap the pass dot {4} for {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'Pass recorded: 4 of 6, target reached'} text
    And I see {'Pass 1: 4 of 6, reached'} text
    And I see {'1 of 5 successful passes'} text

  Scenario: A missed pass marks the row with a neutral result
    Given the app is running
    When I open the session of the group {'Children group'}
    And I tap the pass dot {1} for {'Hugo'}
    And I record the pass of {'Hugo'}
    Then I see {'Pass 1: 1 of 4, missed'} text

  Scenario: The attempts of the sheet are shown under the row and can be changed
    Given the app is running
    When I open the session of the group {'Children group'}
    Then I see {'Attempts: 4 (sheet)'} text {2} times
    When I add {1} attempts for {'Léa'}
    Then I see {'Attempts: 5 (sheet: 4)'} text

  # Lot U5 (suite) : sélecteur nommé, liste compacte, historique groupé.
  Scenario: The exercise selector is named after the catalogue session and is not truncated
    Given the screen is {390} by {844}
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'demi-bille-1'}
    And the app is running
    When I tap {'Results'} text
    And I open the recorded session of {'Oct 5'}
    Then I see {'Les six parts de gâteau'} text
    And the exercise selector is named {'Exercise'} and not truncated

  Scenario: Ten students fit on a phone screen
    Given the club has the student {'Ada'} in the {'children'} audience
    And the club has the student {'Ben'} in the {'children'} audience
    And the club has the student {'Cléo'} in the {'children'} audience
    And the club has the student {'Dan'} in the {'children'} audience
    And the club has the student {'Eva'} in the {'children'} audience
    And the club has the student {'Fred'} in the {'children'} audience
    And the club has the student {'Gus'} in the {'children'} audience
    And the club has the student {'Ines'} in the {'children'} audience
    And the screen is {390} by {844}
    And the app is running
    When I open the session of the group {'Children group'}
    Then I see {10} student rows on the screen

  Scenario: A compact row records a pass with its dots on a phone
    Given the screen is {390} by {844}
    And the app is running
    When I open the session of the group {'Children group'}
    And I tap the pass dot {1} for {'Léa'}
    And I tap the pass dot {2} for {'Léa'}
    And I tap the pass dot {3} for {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'Pass 1: 3 of 4, reached'} text

  Scenario: A compact row is one 48 dp line and its dots carry no score
    Given the screen is {390} by {844}
    And the app is running
    When I open the session of the group {'Children group'}
    Then the compact row of {'Léa'} is {48} dp high without a score

  Scenario: Beyond the second pass the record button is gone
    Given the app is running
    When I open the session of the group {'Children group'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    And I record the pass of {'Léa'}
    Then I see {'Maximum reached for this session'} text
    And the record button is absent for {'Léa'}
    And the record button is present for {'Hugo'}

  Scenario: An exercise acquired at placement shows all the passes required
    Given {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And the app is running
    When I open the session of the group {'Children group'}
    Then I see {'5 of 5 successful passes'} text
    And I see {'0 of 5 successful passes'} text

  Scenario: The history of the session is grouped by student then by exercise
    Given the app is running
    When I open the session of the group {'Children group'}
    And I add {3} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    And I choose the exercise {'Posture, visée et coup de queue · no. 4 (4/6) · Proposal'}
    And I tap the pass dot {1} for {'Léa'}
    And I record the pass of {'Léa'}
    Then the history of {'Léa'} lists {2} exercises
    And I see {'Pass 1: 3 of 4'} text
    And I see {'Pass 1: 1 of 6'} text
