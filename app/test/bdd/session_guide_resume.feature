# Lot 10b (ADR 0020) : la séance guidée en cours survit au rechargement de la
# page et à la fermeture de l'application. « I relaunch the app » ferme puis
# rouvre l'application sur l'accueil (la mémoire des guides est perdue, les
# données de l'appareil restent) ; « I reload the page » rouvre la même adresse.
# « Aujourd'hui » est le lundi 12 octobre 2026.
Feature: Session guide resume

  Scenario: The counters of an initiation survive a relaunch
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I relaunch the app
    Then I see {'In progress'} text
    When I tap {'Resume at step 6'} text
    Then I see the guide at step {6} of {10}
    And I see {'2 of 4 successes'} text

  Scenario: The ticked criteria of a grid survive a relaunch
    Given the app is running
    When I go to the address {'/catalogue/rebond-bande-2/guide?audience=children'}
    And I go to the guide step {'Criteria observed'}
    And I tap {'Vise un point de la première bande'} text
    Then I see {'1 of 4 criteria acquired'} text
    When I relaunch the app
    And I resume the session in progress
    Then I see {'1 of 4 criteria acquired'} text

  Scenario: The score of the game survives a relaunch
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children'}
    And I go to the guide step {'Player or team A'}
    And I tap the tooltip {'Add a point for Player or team A'} {3} times
    And I tap the tooltip {'Add a point for Player or team B'} {5} times
    And I relaunch the app
    And I tap {'Resume at step 9'} text
    Then the score of {'Player or team A'} is {3}
    And the score of {'Player or team B'} is {5}

  Scenario: The step survives a relaunch and Today lists it
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=3'}
    And I relaunch the app
    Then I see {'Step 4 of 10'} text
    And I see {'Resume at step 4'} text
    When I tap {'Resume at step 4'} text
    Then I see the guide at step {4} of {10}

  Scenario: Reloading the page on the address of the guide keeps the counters
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I reload the page
    Then I see the guide at step {6} of {10}
    And I see {'2 of 4 successes'} text

  Scenario: The step of the address wins over the saved step
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I relaunch the app
    And I go to the address {'/catalogue/posture-1/guide?audience=children&step=2'}
    Then I see the guide at step {3} of {10}
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    Then I see {'2 of 4 successes'} text

  Scenario: Reloading the guide without a step offers to resume it
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/catalogue/posture-1/guide?audience=children'}
    And I reload the page
    Then I see {'This session is already under way: step 6 of 10.'} text
    When I tap {'Resume at step 6'} text
    Then I see {'2 of 4 successes'} text

  Scenario: The timer comes back paused where it was
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=1'}
    And the guide timer has run {42} seconds
    Then I see {'19:18'} text
    When I relaunch the app
    And I resume the session in progress
    Then I see {'19:18'} text
    And the guided session of {'demi-bille-1'} has its timer {'paused'}

  Scenario: Ending the session forgets it
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I end the guided session
    And I tap {'Confirm'} text
    Then the device keeps no running state for {'posture-1'}
    When I relaunch the app
    Then I do not see {'In progress'} text
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    Then I see {'0 of 4 successes'} text

  Scenario: Starting over forgets it
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/catalogue/posture-1'}
    And I tap {'Launch'} text
    And I tap {'Start over'} text
    Then the device keeps no running state for {'posture-1'}
    When I relaunch the app
    Then I do not see {'In progress'} text

  Scenario: Abandoning from Today forgets it
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I relaunch the app
    And I tap {'Abandon'} text
    And I tap {'Confirm'} text
    Then I do not see {'In progress'} text
    And the device keeps no running state for {'posture-1'}
    When I relaunch the app
    Then I do not see {'In progress'} text

  Scenario: Nothing is kept for a guide that was only opened
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=0'}
    Then the device keeps no running state for {'posture-1'}
    When I relaunch the app
    Then I do not see {'In progress'} text
    And I see {'Plan the next session'} text

  Scenario: A deleted planned session is not resumed
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    And I tap {'Next'} text
    And I relaunch the app
    Then I see {'In progress'} text
    When I go to the address {'/planner'}
    And I delete the planned session {'Cours'}
    And I relaunch the app
    Then I do not see {'In progress'} text
    And the device keeps no running state for {'posture-1'}

  Scenario: The record opened from the guide is restored without copying the students
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    And I tap {'Hugo'} text
    And I tap {'Open the session'} text
    And I tap {'Back to the guided session'} text
    And I reload the page
    And I tap {'Note the results'} text
    Then the student {'Hugo'} is marked absent in the roster
    And the student {'Léa'} is marked present in the roster

  Scenario: A guided session left for more than seven days is forgotten
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And the day advances by {8} days
    And I relaunch the app
    Then I do not see {'In progress'} text
    And the device keeps no running state for {'posture-1'}

  Scenario: A guided session left for six days is still there
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And the day advances by {6} days
    And I relaunch the app
    Then I see {'In progress'} text

  Scenario: Erasing a student erases the running session of their group
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    And I tap {'Next'} text
    And I relaunch the app
    Then I see {'In progress'} text
    When I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    And I tap {'Confirm'} text
    And I relaunch the app
    Then I do not see {'In progress'} text
    And the device keeps no running state for {'posture-1'}

  # Sans relance : le guide gardé en mémoire est libéré, il ne réécrit pas la
  # ligne effacée et le guide rouvert est neuf.
  Scenario: Erasing a student releases the running session of their group at once
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    And I tap {'Next'} text
    And I go to the address {'/'}
    Then I see {'In progress'} text
    When I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    And I tap {'Confirm'} text
    And I go to the address {'/'}
    Then I do not see {'In progress'} text
    And the device keeps no running state for {'posture-1'}
    When I go to the address {'/catalogue/posture-1/guide?audience=children'}
    Then I do not see text containing {'Resume at step'}
    And the device keeps no running state for {'posture-1'}

  Scenario: Erasing a student keeps the running session of another group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Paul'} in the {'adults'} audience
    And a session {'Cours'} is planned for the group {'Adults group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    And I tap {'Next'} text
    And I go to the address {'/'}
    And I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    And I tap {'Confirm'} text
    And I relaunch the app
    Then I see {'In progress'} text
    And the device keeps a running state for {'posture-1'}

  Scenario: Closing a season erases the running session of the erased students' group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {5} successful passes on {'posture 1'}
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    And I tap {'Next'} text
    And I relaunch the app
    And I open the closure of the season {'2026-2027'}
    And I tap {'Erase 1 student and close'} text
    And I tap {'I understand'} text
    And I tap the button {'closure-erase-and-close'}
    Then I see {'Season closed'} text
    And the device keeps no running state for {'posture-1'}
