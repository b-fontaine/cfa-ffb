Feature: Target on the cue ball

  The instructor shows where the tip hits the cue ball: the cue ball is drawn
  face on with a target, and the tip is drawn at the scale of the cue ball.

  Scenario Outline: The target names where the tip hits the cue ball
    When I look at the cue ball target with the tip {'<tip>'}
    Then I see {'<name>'} text
    And the diagram is described as {'Target on the cue ball seen from the front: <name>.'}

    Examples:
      | tip    | name                                |
      | center | Tip at the centre of the cue ball   |
      | top    | Tip at the top of the cue ball      |
      | bottom | Tip at the bottom of the cue ball   |
      | left   | Tip on the left of the cue ball     |
      | right  | Tip on the right of the cue ball    |

  Scenario: The target can show a tip slightly above the centre
    When I look at the cue ball target with the tip {'top'} slightly off centre
    Then I see {'Tip slightly above the centre of the cue ball'} text
    And the diagram is described as {'Target on the cue ball seen from the front: Tip slightly above the centre of the cue ball.'}

  Scenario: The target names the four sides of the cue ball
    When I look at the cue ball target with the tip {'center'}
    Then I see {'Top'} text
    And I see {'Bottom'} text
    And I see {'Left'} text
    And I see {'Right'} text

  Scenario: The tip is drawn at the real scale of the cue ball
    When I look at the cue ball target with the tip {'bottom'}
    Then I see {'The tip (8.5 mm) is drawn to the scale of the cue ball (48.0 mm).'} text

  Scenario: The target is read in French on a French device
    Given the device language is {'fr'}
    When I look at the cue ball target with the tip {'top'}
    Then I see {'Haut'} text
    And the diagram is described as {'Cible sur la blanche vue de face : Procédé en haut de la blanche.'}
