Feature: Where to stand

  The instructor shows the stance with a figure of a player: numbered marks
  point at the feet, the legs, the head, the forearm, the bridge hand and the
  cue, and each mark is explained in a legend next to the drawing.

  Scenario: The figure legends the six marks of the stance
    When I look at the player figure from the side
    Then I see the legend of {6} marks
    And I see {'Forearm: vertical, only the elbow moves'} text

  Scenario: The figure legends only the marks of the session
    When I look at the player figure from the side with the marks {'feet, head'}
    Then I see the legend of {2} marks
    And I see {'Head: in line with the cue, the lead eye above it'} text
    And I do not see {'Forearm: vertical, only the elbow moves'} text

  Scenario: The view from above does not show the forearm
    When I look at the player figure from above with the head case {'right eye over the cue'}
    Then I see the legend of {5} marks
    And I do not see {'Forearm: vertical, only the elbow moves'} text

  Scenario Outline: The figure says where the head goes
    When I look at the player figure from above with the head case {'<case>'}
    Then I see {'<text>'} text

    Examples:
      | case                   | text                                    |
      | right eye over the cue | Case 1: the right eye above the cue     |
      | cue between the eyes   | Case 2: the cue between the two eyes    |
      | left eye over the cue  | Case 3: the left eye above the cue      |

  Scenario: The figure shows a left-handed player as a mirror of the right-handed one
    When I look at the player figure from the side as a left-handed player
    Then I see the legend of {2} marks
    And I see {'Feet: neither too close nor too far apart; the left foot under the hand that holds the cue (left-handed)'} text
    And the diagram is described as {'Schematic figure of a left-handed player (a right-handed one mirrored), side view, balls not to scale. Marks: 1. Feet: neither too close nor too far apart; the left foot under the hand that holds the cue (left-handed). 2. Legs and hips: hips turned slightly to the right; left leg straight and right leg bent, or right leg forward with both bent (left-handed)'}

  Scenario: The figure is read in French on a French device
    Given the device language is {'fr'}
    When I look at the player figure from the side with the marks {'cue'}
    Then I see {"Queue : dans l'axe de la visée, vers le centre de la blanche"} text
