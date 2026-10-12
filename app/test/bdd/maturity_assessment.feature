# Parcours (e) : bilan de maturité et changement de public manuel.
Feature: Maturity review and audience change

  Background:
    Given the club has the student {'Hugo'} in the {'children'} audience

  Scenario: A ready review gives a cautious hint and changes nothing
    Given the app is running
    When I open the review of {'Hugo'}
    And I give {4} for the criterion {'Concentration'}
    And I give {4} for the criterion {'Endurance'}
    And I give {3} for the criterion {'Frustration management'}
    And I tap {'Save the review'} text
    Then I see {'All three criteria reach 3: moving to the adults course can be considered.'} text
    And I see {'Decision aid only: the audience never changes without your action.'} text
    And I see {'Current audience: Children'} text

  Scenario: A review below the threshold does not indicate the move
    Given the app is running
    When I open the review of {'Hugo'}
    And I give {3} for the criterion {'Concentration'}
    And I give {2} for the criterion {'Endurance'}
    And I give {4} for the criterion {'Frustration management'}
    And I tap {'Save the review'} text
    Then I see {'At least one criterion is below 3: the move is not indicated for now.'} text

  Scenario: The move to the adults audience is manual and confirmed
    Given the app is running
    When I open the review of {'Hugo'}
    And I tap {'Move to the Adults audience'} text
    Then I see {'Change the audience?'} text
    When I tap {'Confirm'} text
    Then I see {'Current audience: Adults'} text
    And I see {'No review has been recorded.'} text

  Scenario: Cancelling the confirmation keeps the audience
    Given the app is running
    When I open the review of {'Hugo'}
    And I tap {'Move to the Adults audience'} text
    And I tap {'Cancel'} text
    Then I see {'Current audience: Children'} text

  Scenario: The audience history is kept after the change
    Given {'Hugo'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I open the review of {'Hugo'}
    And I tap {'Move to the Adults audience'} text
    And I tap {'Confirm'} text
    Then I see the audience history of {'Hugo'} with {2} entries
    And the student {'Hugo'} keeps {2} recorded passes
