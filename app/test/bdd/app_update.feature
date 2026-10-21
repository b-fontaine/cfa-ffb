# Lot 15 : hors ligne et mise à jour. Le navigateur installe une nouvelle
# version en arrière-plan (service worker) ; l'application la signale par une
# bannière sobre et ne l'active JAMAIS d'office, pour ne pas interrompre une
# saisie. Le rechargement de la page après « Update » n'est pas observable ici :
# il est assuré par web/offline.js, testé dans scripts/pwa_js_test.mjs. La source de mise à jour
# (port AppUpdateSource) est un double.
Feature: New version banner

  Scenario: No banner while the app is up to date
    Given the app is running
    Then I do not see {'A new version is available. Your saved data is kept, and the data of this device stays exportable.'} text

  Scenario: A version already waiting is announced on opening
    Given a new version of the app is waiting
    And the app is running
    Then I see {'A new version is available. Your saved data is kept, and the data of this device stays exportable.'} text
    And I see {'Update'} text

  Scenario: A version installed while the app is open is announced
    Given the app is running
    When the browser installs a new version of the app
    Then I see {'A new version is available. Your saved data is kept, and the data of this device stays exportable.'} text
    And the new version of the app was activated {0} times

  Scenario: The banner is in French on a French device
    Given the device language is {'fr'}
    And a new version of the app is waiting
    And the app is running
    Then I see {'Une nouvelle version est disponible. Vos données enregistrées sont conservées, et celles de cet appareil restent exportables.'} text
    And I see {'Mettre à jour'} text
    And I see {'Plus tard'} text

  Scenario: Later hides the banner without updating
    Given a new version of the app is waiting
    And the app is running
    When I tap {'Later'} text
    Then I do not see {'A new version is available. Your saved data is kept, and the data of this device stays exportable.'} text
    And the new version of the app was activated {0} times

  Scenario: Update activates the new version only on request
    Given a new version of the app is waiting
    And the app is running
    When I tap {'Update'} text
    Then the new version of the app was activated {1} times

  Scenario: A banner appearing during a data entry keeps what was typed
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Plan a session'} text
    And I enter {'Posture basics'} into {0} input field
    And I choose the group {'Children group'}
    And the browser installs a new version of the app
    Then I see {'A new version is available. Your saved data is kept, and the data of this device stays exportable.'} text
    And I see {'Posture basics'} text
    When I tap {'Add session'} text
    Then I see {'Mon, Oct 12 · Children group · Children · 90 min'} text

  Scenario Outline: The banner fits a small screen
    Given the screen is {<width>} by {<height>}
    And a new version of the app is waiting
    And the app is running
    Then I see {'A new version is available. Your saved data is kept, and the data of this device stays exportable.'} text
    And I see {'Update'} text

    Examples:
      | width | height |
      | 390   | 844    |
      | 320   | 640    |
