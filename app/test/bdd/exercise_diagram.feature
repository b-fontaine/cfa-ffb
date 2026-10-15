Feature: Exercise diagram

  The instructor reads the diagram of an exercise on a billiard table, plays
  the shot, pauses it, replays it and changes its speed. Balls are never
  identified by their colour alone.

  Scenario: The table shows each ball with its letter and its mark
    When I open the diagram of the exercise {'full ball'}
    Then I see the billiard table
    And I see {'W'} text
    And I see {'Y x4'} text
    And I see the cue behind the white ball
    And the diagram is described as {'Full ball: pot the yellow ball'}

  Scenario: The balls carry their French letters on a French device
    Given the device language is {'fr'}
    When I open the diagram of the exercise {'full ball'}
    Then I see {'B'} text
    And I see {'J x4'} text
    And I see {'Lire'} text
    And I see {'Rejouer'} text

  Scenario: The diagram waits on the starting layout
    When I open the diagram of the exercise {'full ball'}
    Then the white ball is at the start of the shot
    And the yellow ball is still on the table
    And I see {'Play'} text

  Scenario: Playing the shot pots the yellow ball
    When I open the diagram of the exercise {'full ball'}
    And I press {'Play'}
    And {300} milliseconds pass
    Then the white ball has left the start of the shot
    And I see {'Pause'} text
    When {1500} milliseconds pass
    Then the yellow ball is potted
    And I see {'Play'} text

  Scenario: Pausing freezes the shot
    When I open the diagram of the exercise {'full ball'}
    And I press {'Play'}
    And {300} milliseconds pass
    And I press {'Pause'}
    And I note the position of the white ball
    And {1500} milliseconds pass
    Then the white ball has not moved
    And the yellow ball is still on the table
    And I see {'Play'} text

  Scenario: Resuming after a pause goes on from where the shot stopped
    When I open the diagram of the exercise {'full ball'}
    And I press {'Play'}
    And {300} milliseconds pass
    And I press {'Pause'}
    And I press {'Play'}
    And {750} milliseconds pass
    Then the yellow ball is potted

  Scenario: Replaying restarts the shot from the starting layout
    When I open the diagram of the exercise {'full ball'}
    And I press {'Play'}
    And {1500} milliseconds pass
    Then the yellow ball is potted
    When I press {'Replay'}
    And {100} milliseconds pass
    Then the yellow ball is still on the table
    When {1500} milliseconds pass
    Then the yellow ball is potted

  Scenario: At double speed the shot ends twice as fast
    When I open the diagram of the exercise {'full ball'}
    And I press {'Speed ×2'}
    And I press {'Play'}
    And {600} milliseconds pass
    Then the yellow ball is potted

  Scenario: At normal speed the shot lasts one second
    When I open the diagram of the exercise {'full ball'}
    And I press {'Play'}
    And {900} milliseconds pass
    Then the yellow ball is still on the table
    When {200} milliseconds pass
    Then the yellow ball is potted

  Scenario: At normal speed the shot is not over after the same time
    When I open the diagram of the exercise {'full ball'}
    And I press {'Play'}
    And {600} milliseconds pass
    Then the yellow ball is still on the table

  Scenario: At half speed the shot takes twice as long
    When I open the diagram of the exercise {'full ball'}
    And I press {'Speed ×0.5'}
    And I press {'Play'}
    And {1500} milliseconds pass
    Then the yellow ball is still on the table
    When {1000} milliseconds pass
    Then the yellow ball is potted

  Scenario: Reduced animations show the final image without motion
    Given reduced animations are enabled on the device
    When I open the diagram of the exercise {'full ball'}
    Then the yellow ball is potted
    And the diagram is not animated
    And I see {'Play'} text

  Scenario: Reduced animations still let the instructor replay the shot
    Given reduced animations are enabled on the device
    When I open the diagram of the exercise {'full ball'}
    And I press {'Replay'}
    And {100} milliseconds pass
    Then the yellow ball is still on the table
    When {1500} milliseconds pass
    Then the yellow ball is potted

  Scenario: An exercise without a shot shows only the table
    When I open the diagram of the exercise {'balls to observe'}
    Then I see the billiard table
    And I see {'R'} text
    And I do not see {'Play'} text
    And I do not see {'Replay'} text

  Scenario: An invalid diagram is reported and offers no control
    When I open the diagram of the exercise {'ball outside the table'}
    Then I see {'This exercise diagram is invalid and cannot be displayed.'} text
    And I do not see {'Play'} text
    And I do not see the billiard table

  Scenario Outline: No label covers a path on the six-position diagram
    Given the diagram is {<width>} px wide
    When I open the catalogue diagram {'entrainement-p05-e1'}
    Then I see {7} diagram labels
    And no label covers a path, a ball or another label

    Examples:
      | width |
      | 310   |
      | 450   |
      | 900   |

  Scenario Outline: No label covers a path on the six-position diagram in presentation
    Given the diagram is {<width>} px wide
    When I open the catalogue diagram {'entrainement-p05-e1'} in presentation
    Then I see {7} diagram labels
    And no label covers a path, a ball or another label

    Examples:
      | width |
      | 390   |
      | 900   |

  Scenario Outline: No label covers a ball or another label on any catalogue diagram
    Given the diagram is {<width>} px wide
    Then no label covers a ball or another label on every catalogue diagram

    Examples:
      | width |
      | 390   |
      | 450   |
      | 900   |

  Scenario: The cue stays inside the table against the rail
    When I open the diagram of the exercise {'shot against the rail'}
    Then the cue stays inside the table

  Scenario: Every catalogue diagram draws its cue inside the table
    Then the cue stays inside the table on every catalogue diagram

  Scenario: The ball quantity of the sheet is shown in a free place on the table
    Given the diagram is {900} px wide
    When I open the catalogue diagram {'entrainement-p05-e1'}
    Then I see the ball quantity inset
    And the inset covers no path, ball or label

  Scenario: The ball quantity goes under the table when the table has no free place
    Given the diagram is {310} px wide
    When I open the catalogue diagram {'entrainement-p06-e4'}
    Then I see the ball quantity inset under the table

  Scenario Outline: The inset covers nothing on any catalogue diagram
    Given the diagram is {<width>} px wide
    Then the inset covers nothing on every catalogue diagram

    Examples:
      | width |
      | 310   |
      | 450   |
      | 900   |

  Scenario: No inset is shown when the sheet gives no ball quantity
    When I open the diagram of the exercise {'full ball'}
    Then I do not see the ball quantity inset

  Scenario: In presentation the labels are at least 16 px
    When I open the diagram of the exercise {'full ball'} in presentation
    Then every label is at least {16} px
