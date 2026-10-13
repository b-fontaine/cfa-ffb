# Parcours (d) : le schéma animé sur la fiche source d'un exercice.
Feature: Exercise sheet diagram

  The instructor opens the source sheet of an exercise and sees its table
  diagram: balls and paths. He plays it, pauses it, replays it and changes its
  speed. The ball contact is written in his language ; the bridge is given once,
  by the sheet card.

  Scenario: The sheet shows the table diagram with its contact and bridge
    Given the app is running
    When I go to the address {'/exercises/bille-pleine/1'}
    Then I see the billiard table
    And I see {'Table diagram'} text
    And I see {'Ball contact: Full ball'} text
    And I see {'Bridge on the rail'} text
    And I see {'Play'} text
    And I see {'Replay'} text

  Scenario: The labels are French on a French device
    Given the device language is {'fr'}
    And the app is running
    When I go to the address {'/exercises/bille-pleine/1'}
    Then I see {'Schéma de table'} text
    And I see {'Quantité de bille : Bille pleine'} text
    And I see {'Pont sur le cadre'} text
    And I see {'Lire'} text
    And I see {'Rejouer'} text

  Scenario: The surface bridge is written when the sheet says so
    Given the app is running
    When I go to the address {'/exercises/bille-pleine/2'}
    Then I see {'Bridge on the surface'} text
    And I do not see {'Bridge: on the surface'} text

  Scenario: Playing then pausing the shot
    Given the app is running
    When I go to the address {'/exercises/bille-pleine/1'}
    And I press {'Play'}
    And {300} milliseconds pass
    Then I see {'Pause'} text
    When I press {'Pause'}
    Then I see {'Play'} text

  Scenario: The three speeds are offered
    Given the app is running
    When I go to the address {'/exercises/bille-pleine/1'}
    Then I see {'Speed ×0.5'} text
    And I see {'Speed ×1'} text
    And I see {'Speed ×2'} text

  Scenario: An exercise printed twice on the source shows both diagrams
    Given the app is running
    When I go to the address {'/exercises/rejet-naturel/1'}
    Then I see {'Diagram 1 of 2'} text
    And I see {'Diagram 2 of 2'} text

  Scenario: A single diagram carries no numbering
    Given the app is running
    When I go to the address {'/exercises/bille-pleine/1'}
    Then I do not see {'Diagram 1 of 1'} text

  Scenario: An exercise without diagram says so and keeps its sheet
    Given the diagram library is empty
    And the app is running
    When I go to the address {'/exercises/bille-pleine/1'}
    Then I see {'No diagram is available for this exercise.'} text
    And I see {'Required: 6 out of 8'} text
    And I do not see {'Play'} text

  Scenario: An unreadable diagram library does not hide the sheet
    Given the diagram library cannot be read
    And the app is running
    When I go to the address {'/exercises/bille-pleine/1'}
    Then I see {'This exercise diagram is invalid and cannot be displayed.'} text
    And I see {'Required: 6 out of 8'} text
    And I do not see {'Play'} text
