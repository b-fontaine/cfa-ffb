Feature: Cue ball and object ball sizes

  At Blackball the cue ball (48.0 mm) is smaller than the other balls
  (50.8 mm). Every drawing keeps that ratio, so that an instructor never shows
  two balls of the same size.

  Scenario: The size comparison shows the cue ball smaller than an object ball
    When I look at the ball size comparison
    Then the cue ball is {0.945} times the size of the object ball
    And I see {'48.0 mm'} text
    And I see {'50.8 mm'} text

  Scenario: The size comparison is read in French
    Given the device language is {'fr'}
    When I look at the ball size comparison
    Then I see {'48,0 mm'} text
    And I see {'50,8 mm'} text
    And the diagram is described as {'Comparaison de taille : la blanche mesure 48,0 mm, une bille de but 50,8 mm.'}

  Scenario: The table diagram draws the white ball smaller than a yellow ball
    When I open the diagram of the exercise {'full ball'}
    Then the white ball is {0.945} times the size of the {'yellow'} ball

  Scenario: The ghost ball touches the object ball without overlapping it
    When I look at the ghost aim towards the pocket {'top right'}
    Then the ghost ball touches the object ball

  Scenario: The ghost ball is drawn the size of the cue ball
    When I look at the ghost aim towards the pocket {'top right'}
    Then the ghost ball is drawn the size of the cue ball
