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
    Then I see {'Plan the next session'} text

  # Lot U6 : cinq destinations recentrées (ADR 0004, R6).
  Scenario: The five destinations are Today, Students, Results, Sessions and More
    Given the device language is {'fr'}
    And the app is running
    Then the navigation destinations are {"Aujourd'hui, Élèves, Résultats, Séances, Plus"}
    And the destination {"Aujourd'hui"} is selected

  Scenario: The five destinations are announced in English
    Given the app is running
    Then the navigation destinations are {'Today, Students, Results, Sessions, More'}

  Scenario: Sessions offers Planned, Catalogue and Suggestion
    Given the app is running
    When I tap {'Sessions'} text
    Then the sessions tabs are {'Planned, Catalogue, Suggestion'}
    And the sessions tab {'Catalogue'} is selected
    And the destination {'Sessions'} is selected

  Scenario: Each sessions tab opens its own screen
    Given the app is running
    When I tap {'Sessions'} text
    And I tap {'Planned'} text
    Then I see {'Planning'} text
    And the sessions tab {'Planned'} is selected
    When I tap {'Suggestion'} text
    Then I see {'Suggested session'} text
    And the sessions tab {'Suggestion'} is selected
    When I tap {'Catalogue'} text
    Then I see {'Session catalogue'} text
    And the sessions tab {'Catalogue'} is selected

  Scenario: The sessions tabs are in French on a French device
    Given the device language is {'fr'}
    And the app is running
    When I tap {'Séances'} text
    Then the sessions tabs are {'Planifiées, Catalogue, Suggestion'}

  Scenario: The planner address selects Sessions and its Planned tab
    Given the app is running
    When I go to the address {'/planner'}
    Then the destination {'Sessions'} is selected
    And the sessions tab {'Planned'} is selected

  Scenario: The suggestion address selects Sessions and its Suggestion tab
    Given the app is running
    When I go to the address {'/session'}
    Then the destination {'Sessions'} is selected
    And the sessions tab {'Suggestion'} is selected

  Scenario: A session of the catalogue stays under Sessions without the tabs
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-2'}
    Then the destination {'Sessions'} is selected
    And I do not see the sessions tabs

  Scenario: More contains the backup and opens it
    Given the app is running
    When I tap {'More'} text
    Then the destination {'More'} is selected
    And I see {'Backup'} text
    When I tap {'Backup'} text
    Then I see {'Back up your data'} text
    And the destination {'More'} is selected
    When I tap {'Back to More'} text
    Then I see {'Backup'} text

  # Lot 9 : « Plus » contient Sauvegarde et Réglages (scénario U6 reporté).
  Scenario: More contains Backup and Settings
    Given the app is running
    When I tap {'More'} text
    Then I see {'Backup'} text
    And I see {'Settings'} text

  Scenario: The settings address selects More and leads back to it
    Given the app is running
    When I go to the address {'/settings'}
    Then the destination {'More'} is selected
    When I tap {'Back to More'} text
    Then I see {'Backup'} text
