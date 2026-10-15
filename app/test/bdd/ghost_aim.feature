Feature: Ghost ball aim

  The instructor shows where the cue ball must be at the impact: the table
  diagram is completed by a magnified view of the contact, because at the
  scale of the table the ghost ball and the object ball are too small to read.

  Scenario: The contact is magnified under the table
    When I look at the ghost ball aim in half ball to the top right pocket
    Then I see text containing {'Magnified'}
    And the diagram is described as {'Ghost ball, Half ball: the cue ball aims at the point where it touches the object ball to send it into the top right pocket. Magnified view of the contact: the ghost ball, the size of the cue ball, touches the object ball; the dot marks the contact.'}

  Scenario: The magnified view is read in French on a French device
    Given the device language is {'fr'}
    When I look at the ghost ball aim in half ball to the top right pocket
    Then I see text containing {'Loupe'}
