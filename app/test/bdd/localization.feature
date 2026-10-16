Feature: Localization

  Scenario: The app is displayed in English by default
    Given the app is running
    Then I see {'Plan the next session'} text

  Scenario: The app follows a French device
    Given the device language is {'fr'}
    And the app is running
    Then I see {'Planifier la prochaine séance'} text
