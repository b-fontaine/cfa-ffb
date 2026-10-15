Feature: Contact height of two unequal balls

  Side view of the cue ball and an object ball resting on the cloth. The cue
  ball is smaller, so the contact is slightly above its equator (technical
  sheet no. 4). The drawing exaggerates the tilt of the line of centres ten times and says so: it is
  never presented as a measure.

  Scenario: The contact is drawn above the equator of the cue ball
    When I look at the contact height drawing
    Then the contact point is above the equator of the cue ball

  Scenario: The drawing says that the tilt is exaggerated
    When I look at the contact height drawing
    Then I see text containing {'exaggerated ×10'}

  Scenario: The contact height drawing is read in French
    Given the device language is {'fr'}
    When I look at the contact height drawing
    Then I see text containing {'Inclinaison exagérée ×10'}
    And the diagram description contains {'légèrement au-dessus de l\'équateur de la blanche'}
