Feature: Adaptive navigation

  Scenario: A phone uses a navigation bar
    Given the screen is {390} by {800}
    And the app is running
    Then I see the {'bar'} navigation

  Scenario: A tablet or desktop uses a navigation rail
    Given the screen is {1000} by {800}
    And the app is running
    Then I see the {'rail'} navigation

  Scenario: The dark theme is kept on every screen
    Given the device theme is {'dark'}
    And the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    Then the {'dark'} theme is used

  Scenario: A malformed exercise number shows a localized error page
    Given the app is running
    When I go to the address {'/exercises/puissance/abc'}
    Then I see {'Page not found'} text
    And I see {'This address does not match any screen.'} text

  Scenario: An exercise number below one is refused
    Given the app is running
    When I go to the address {'/exercises/puissance/0'}
    Then I see {'Page not found'} text

  Scenario: The error page is displayed in French on a French device
    Given the device language is {'fr'}
    And the app is running
    When I go to the address {'/nowhere'}
    Then I see {'Page introuvable'} text

  Scenario: The error page leads back to the home screen
    Given the app is running
    When I go to the address {'/exercises/puissance/abc'}
    And I tap {'Back to home'} text
    Then I see {'Prepare a session'} text
