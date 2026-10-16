Feature: Design system

  Scenario: The audience badges name the audience and its duration
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children'}
    Then I see {'Children · 90 min'} text
    When I go to the address {'/catalogue/posture-1/guide?audience=adults'}
    Then I see {'Adults · 120 min'} text

  Scenario: The app uses the light theme on a light device
    Given the device theme is {'light'}
    And the app is running
    Then the {'light'} theme is used

  Scenario: The app uses the dark theme on a dark device
    Given the device theme is {'dark'}
    And the app is running
    Then the {'dark'} theme is used

  Scenario Outline: Selected states use the cloth blue container
    Given the device theme is {'<mode>'}
    And the app is running
    Then the selected navigation destination uses the cloth blue container
    And the selected chip and segment use the cloth blue container

    Examples:
      | mode  |
      | light |
      | dark  |

  Scenario: A progress bar track is never red
    Given the app is running
    Then the progress bar track is not red

  Scenario: The FFB logo is not shown without a brand asset
    Given the app is running
    Then I do not see the FFB logo

  Scenario: Page headers do not show the FFB logo without a brand asset
    Given the app is running
    When I go to the address {'/students'}
    Then I do not see the FFB logo

  Scenario: A tapped pass dot toggles and the x/n text follows
    Given the app is running
    And a pass dots row of {5} with {2} pocketed
    Then I see {'2/5'} text
    When I tap the pass dot {3}
    Then I see {'3/5'} text
    When I tap the pass dot {3}
    Then I see {'2/5'} text

  Scenario Outline: The timer changes tone under one minute and when overtime
    Given the app is running
    And a timer chip with {<seconds>} seconds remaining
    Then the timer chip uses the {'<tone>'} tone
    And I see {'<text>'} text

    Examples:
      | seconds | tone      | text   |
      | 120     | neutral   | 02:00  |
      | 59      | attention | 00:59  |
      | -5      | overdue   | +00:05 |

  Scenario: Tapping a phase of the timeline makes it the current one
    Given the app is running
    And a phase timeline of {120} minutes with the phase {2} current
    Then I see the button {'Phase 2 of 5: Notion, 15 min, current'}
    When I tap the phase {4}
    Then I see the button {'Phase 4 of 5: Game, 35 min, current'}
    And I see the button {'Phase 2 of 5: Notion, 15 min'}

  Scenario: The step bar shows the position and offers the injected actions
    Given the app is running
    And a step app bar titled {'Training'} at step {6} of {9}
    Then I see {'Training'} text
    And I see {'6/9'} text
    When I open the step menu
    Then I see {'Summary'} text
    And I see {'Finish session'} text
