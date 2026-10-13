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
