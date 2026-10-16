# U3 : présentation plein écran. La scène (DiagramStage) réserve elle-même la
# légende, le badge et la barre basse, et donne le reste au schéma (F1 : la
# légende du bas n'est plus tronquée à 1280 x 800). Le plein écran passe par le
# port FullscreenController (double dans les tests) ; l'indication « Tournez
# l'appareil » n'apparaît qu'en portrait, quand la largeur borne le schéma.
Feature: Presentation stage

  Scenario Outline: The whole caption and the navigation bar fit on the screen
    Given the screen is {<width>} by {<height>}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=<step>'}
    Then the presentation is open
    And the whole caption is visible
    And the navigation bar of the presentation is visible
    And the figure keeps at least {160} px

    Examples:
      | width | height | step |
      | 1280  | 800    | 5    |
      | 1280  | 800    | 6    |
      | 1280  | 800    | 8    |
      | 900   | 600    | 5    |
      | 900   | 600    | 8    |
      | 390   | 844    | 5    |
      | 390   | 844    | 8    |
      | 844   | 390    | 5    |
      | 844   | 390    | 8    |

  Scenario: The caption stays whole at 320 dp with a large system text
    Given the screen is {320} by {640}
    And the text size is {130} percent
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    Then the presentation is open
    And the whole caption is visible
    And the navigation bar of the presentation is visible
    And nothing overflows the screen

  Scenario: The stage needs no scrolling on a tablet
    Given the screen is {1280} by {800}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    Then the presentation is open
    And the stage needs no scrolling

  Scenario: The player controls are reachable without scrolling on a tablet
    Given the screen is {1280} by {800}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    Then the presentation is open
    And the player controls are visible on the screen

  Scenario: The full screen entry is hidden when the device cannot do it
    Given the device does not support full screen
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    Then I do not see {'Full screen'} text

  Scenario: The full screen is entered from the presentation
    Given the device supports full screen
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    And I tap {'Full screen'} text
    Then the full screen was entered {1} times
    And I see {'Exit full screen'} text
    And I do not see {'Full screen'} text

  Scenario: The full screen is left from the presentation
    Given the device supports full screen
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    And I tap {'Full screen'} text
    And I tap {'Exit full screen'} text
    Then the full screen was left {1} times
    And I see {'Full screen'} text

  Scenario: The browser leaving the full screen is followed by the button
    Given the device supports full screen
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    And I tap {'Full screen'} text
    And the browser leaves the full screen
    Then I see {'Full screen'} text

  Scenario: The F key switches the full screen in the presentation
    Given the device supports full screen
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    And I press the key {'F'}
    Then the full screen was entered {1} times
    When I press the key {'F'}
    Then the full screen was left {1} times

  Scenario: The full screen is offered in the guide menu
    Given the device supports full screen
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I open the guide menu
    And I tap {'Full screen'} text
    Then the full screen was entered {1} times
    When I open the guide menu
    Then I see {'Exit full screen'} text

  Scenario: The guide menu hides the full screen entry when the device cannot do it
    Given the device does not support full screen
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I open the guide menu
    Then I do not see {'Full screen'} text

  Scenario: The full screen survives the presentation
    Given the device supports full screen
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I open the guide menu
    And I tap {'Full screen'} text
    And I tap {'Show'} text
    Then the presentation is open
    And I see {'Exit full screen'} text
    When I tap {'Close'} text
    Then the full screen is still active
    And the full screen was left {0} times

  Scenario: The rotate hint is shown on a phone held upright
    Given the screen is {390} by {844}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    Then I see {'Rotate the device to enlarge the diagram'} text
    And I see {'Next'} text

  Scenario Outline: The rotate hint is not shown when the width does not limit the figure
    Given the screen is {<width>} by {<height>}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    Then I do not see {'Rotate the device to enlarge the diagram'} text

    Examples:
      | width | height |
      | 844   | 390    |
      | 1280  | 800    |

  Scenario: Dismissing the rotate hint removes it for the step
    Given the screen is {390} by {844}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    And I tap the control {'Dismiss the hint'}
    Then I do not see {'Rotate the device to enlarge the diagram'} text
    And the presentation is open

  Scenario: A step with several illustrations is still listed as before
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=1'}
    Then the presentation is open
    And I see text containing {'Demi-bille : la blanche, un peu plus petite'}

  Scenario: The cloth pattern lies under the presentation and is not announced
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=5'}
    Then the presentation is drawn over the cloth pattern
    And the cloth pattern adds nothing for screen readers
