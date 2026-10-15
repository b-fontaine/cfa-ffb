Feature: Quantity of ball diagram

  The instructor reads how much of the target ball the cue ball covers and
  where the tip hits the cue ball, in words as well as in the drawing.

  Scenario Outline: The diagram names the quantity of ball
    When I look at the quantity of ball diagram: {'<contact>'} with the tip {'center'}
    Then I see {'<label>'} text
    And the diagram is described as {'<label>; Tip at the centre of the cue ball'}

    Examples:
      | contact       | label              |
      | full          | Full ball          |
      | three-quarter | Three-quarter ball |
      | half          | Half ball          |
      | quarter       | Quarter ball       |
      | thin          | Thin cut           |

  Scenario: The diagram says where the tip hits the cue ball
    When I look at the quantity of ball diagram: {'half'} with the tip {'bottom'}
    Then I see {'Half ball'} text
    And the diagram is described as {'Half ball; Tip at the bottom of the cue ball'}

  Scenario Outline: The diagram says on which side the tip hits the cue ball
    When I look at the quantity of ball diagram: {'half'} with the tip {'<tip>'}
    Then I see {'Half ball'} text
    And the diagram is described as {'Half ball; <description>'}

    Examples:
      | tip   | description                       |
      | top   | Tip at the top of the cue ball    |
      | left  | Tip on the left of the cue ball   |
      | right | Tip on the right of the cue ball  |

  Scenario: The diagram can draw where each ball goes after the contact
    When I look at the quantity of ball diagram: {'half'} with the paths after the contact
    Then I see {'Half ball'} text
    And the diagram is described as {'Half ball; Tip at the centre of the cue ball; After the contact, the colour ball deviates by about 31° and the cue ball by about 59°'}

  Scenario: The full ball diagram sends the colour ball straight ahead
    When I look at the quantity of ball diagram: {'full'} with the paths after the contact
    Then the diagram is described as {'Full ball; Tip at the centre of the cue ball; After the contact, the colour ball goes straight ahead and the cue ball stops'}

  Scenario: The diagram is read in French on a French device
    Given the device language is {'fr'}
    When I look at the quantity of ball diagram: {'half'} with the tip {'left'}
    Then I see {'Demi-bille'} text
    And the diagram is described as {'Demi-bille ; Procédé à gauche de la blanche'}

  Scenario: The right side of the tip is read in French
    Given the device language is {'fr'}
    When I look at the quantity of ball diagram: {'half'} with the tip {'right'}
    Then the diagram is described as {'Demi-bille ; Procédé à droite de la blanche'}
