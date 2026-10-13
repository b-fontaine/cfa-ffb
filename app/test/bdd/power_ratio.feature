Feature: Dose the power

  The instructor shows that the power depends on two things, the amplitude of
  the stroke and its speed: a plane with three zones and no levels.

  Scenario Outline: The plane gives the zone reached by the amplitude and the speed
    When I look at the power plane with a {'<amplitude>'} amplitude and a {'<speed>'} speed
    Then I see {'<line>'} text

    Examples:
      | amplitude | speed  | line                                   |
      | short     | slow   | Amplitude short, speed slow: soft      |
      | medium    | medium | Amplitude medium, speed medium: medium |
      | long      | slow   | Amplitude long, speed slow: medium     |
      | medium    | fast   | Amplitude medium, speed fast: strong   |
      | long      | fast   | Amplitude long, speed fast: strong     |

  Scenario: The empty plane names the three zones in French
    Given the device language is {'fr'}
    When I look at the empty power plane
    Then I see {'doux'} text
    And I see {'moyen'} text
    And I see {'puissant'} text

  Scenario: The plane has no level to count
    Given the device language is {'fr'}
    When I look at the empty power plane
    Then I do not see text containing {'cran'}
    And I do not see text containing {'niveau'}

  Scenario: The plane is read in French on a French device
    Given the device language is {'fr'}
    When I look at the power plane with a {'long'} amplitude and a {'fast'} speed
    Then the diagram is described as {'Amplitude longue, vitesse rapide : puissant'}
