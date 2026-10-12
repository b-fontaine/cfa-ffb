Feature: Session planner

  Scenario: Nothing is planned at first
    Given the app is running
    When I tap {'Plan a session'} text
    Then I see {'No session planned yet.'} text

  Scenario: A children session lasts 1h30
    Given the app is running
    When I tap {'Plan a session'} text
    And I enter {'Posture basics'} into {0} input field
    And I tap {'Add session'} text
    Then I see {'Posture basics'} text
    And I see {'Children · 90 min'} text

  Scenario: An adult session lasts 2h
    Given the app is running
    When I tap {'Plan a session'} text
    And I enter {'Position play'} into {0} input field
    And I tap {'Adults'} text
    And I tap {'Add session'} text
    Then I see {'Position play'} text
    And I see {'Adults · 120 min'} text

  Scenario: A session needs a title
    Given the app is running
    When I tap {'Plan a session'} text
    And I tap {'Add session'} text
    Then I see {'The session title is required.'} text
