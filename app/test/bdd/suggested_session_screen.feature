# Parcours (d) : séance suggérée pour un groupe.
Feature: Suggested session screen

  Scenario: A children session lasts 90 minutes and is timed
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Group suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'90 min'} text
    And I see {'La puissance'} text
    And I see {'Welcome · 10 min'} text
    And I see {'Training · 35 min'} text
    And I see {'Game · 20 min'} text

  Scenario: An adults session lasts 120 minutes and may include a recall
    Given the club has the student {'Hugo'} in the {'adults'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Group suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'120 min'} text
    And I see {'Training · 50 min'} text

  Scenario: Each exercise links to its source sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Group suggestion'} text
    And I tap {'Suggest a session'} text
    And I open the source sheet of exercise {1}
    Then I see {'Technical sheet no. 2'} text
    And I see {'Required: 7 out of 9'} text
