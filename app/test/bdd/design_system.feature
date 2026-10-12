Feature: Design system

  Scenario: The home page presents both audiences
    Given the app is running
    Then I see {'Children'} text
    And I see {'Adults'} text
    And I see {'90 min'} text
    And I see {'120 min'} text

  Scenario: The app uses the light theme on a light device
    Given the device theme is {'light'}
    And the app is running
    Then the {'light'} theme is used

  Scenario: The app uses the dark theme on a dark device
    Given the device theme is {'dark'}
    And the app is running
    Then the {'dark'} theme is used
