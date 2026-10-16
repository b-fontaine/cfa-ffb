# Lot 11c (ADR 0019), écrans : l'assistant de clôture de saison, « Saisons
# passées » et la carte « Clôturer la saison » d'Aujourd'hui. « Aujourd'hui »
# est le lundi 12 octobre 2026 ; la saison 2026-2027 court jusqu'au 31 août 2027.
Feature: Season closure screen

  Scenario: The backup is proposed first and its state is read after the export
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    Then I see {'Close the 2026-2027 season'} text
    And I see {'2. Backup (recommended)'} text
    And I see {'Export a backup'} text
    And I do not see {'Backup done.'} text
    When I tap {'Export a backup'} text
    Then I see {'Backup done.'} text

  Scenario: Each student gets a proposal with its reason, and every line can be reversed
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    Then I see the closure choice of {'Léa'} is {'Keep'}
    And I see the closure choice of {'Hugo'} is {'Erase'}
    And I see {'Active and enrolled this season'} text
    And I see {'Absent from every session this season'} text
    And I see {'1 student to erase, 1 to keep.'} text
    When I tap the closure choice of {'Hugo'}
    Then I see the closure choice of {'Hugo'} is {'Keep'}
    And I see {'No student to erase, 2 to keep.'} text

  Scenario: Keep everyone and erase everyone apply to the whole list
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    And I tap {'Erase everyone'} text
    Then I see {'2 students to erase, none to keep.'} text
    When I tap {'Keep everyone'} text
    Then I see {'No student to erase, 2 to keep.'} text

  Scenario: The erasure needs an explicit confirmation
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    And I tap {'Erase 1 student and close'} text
    Then I see {'Permanently erase 1 student?'} text
    And I see {'This cannot be undone. The season results are kept without any name.'} text
    And the button {'closure-erase-and-close'} is disabled
    When I tap {'I understand'} text
    Then the button {'closure-erase-and-close'} is enabled

  Scenario: Cancelling the confirmation erases nothing
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    And I tap {'Erase 1 student and close'} text
    And I tap {'Cancel'} text
    Then I see {'1. Summary'} text
    And the club keeps data for {'Hugo'}

  Scenario: Closing erases the chosen students, keeps the others and reports numbers only
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {5} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    And I tap {'Erase 1 student and close'} text
    And I tap {'I understand'} text
    And I tap the button {'closure-erase-and-close'}
    Then I see {'Season closed'} text
    And I see {'Season 2026-2027 closed.'} text
    And I see {'1 student erased'} text
    And I see {'1 student kept'} text
    And I see {'1 group prepared'} text
    And I do not see text containing {'Hugo'}
    And the club keeps no data for {'Hugo'}

  Scenario: Kept students keep their path and rejoin a group of the next season
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {5} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    And I tap {'Erase 1 student and close'} text
    And I tap {'I understand'} text
    And I tap the button {'closure-erase-and-close'}
    And I tap {'Back to Today'} text
    And I tap {'Students'} text
    Then I see {'Léa'} text
    And I see {'Children group'} text
    And I do not see {'Hugo'} text
    And I do not see {'No group'} text
    When I tap {'Léa'} text
    Then I see {'1 exercise validated'} text

  Scenario: Closing with nobody to erase needs no red confirmation
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    And I tap {'Close the season'} text
    Then I see {'Season closed'} text
    And I see {'0 students erased'} text
    And I see {'1 student kept'} text

  Scenario: Past seasons lists the closed season without any name
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {4} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    And I tap {'Erase 1 student and close'} text
    And I tap {'I understand'} text
    And I tap the button {'closure-erase-and-close'}
    And I tap {'See past seasons'} text
    Then I see {'Past seasons'} text
    And I see {'Results kept without any name.'} text
    And I see {'2026-2027'} text
    And I see {'2 sessions'} text
    And I see {'Fewer than 3 students: attendances and passes are not kept.'} text
    And I do not see text containing {'Hugo'}
    And I do not see text containing {'Léa'}

  Scenario: An exercise practised by three students has its line, fewer has none
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And the club has the student {'Eve'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And {'Hugo'} has {1} successful passes on {'posture 1'}
    And {'Eve'} has {1} successful passes on {'posture 1'}
    And {'Eve'} has {1} successful passes on {'puissance 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    And I tap {'Close the season'} text
    And I tap {'See past seasons'} text
    Then I see {'Exercises practised'} text
    And I see the grid described as {'Posture, visée et coup de queue, exercise 1: 3 students, 3 passes, 9 of 12 balls'}
    And I do not see text containing {'La puissance · 1'}
    And I see {'Exercises practised by fewer than 3 students are not detailed.'} text

  Scenario: Past seasons is empty before any closure
    Given the app is running
    When I tap {'More'} text
    And I tap {'Past seasons'} text
    Then I see {'No closed season yet. When you close a season, its figures will stay here, without any name.'} text

  Scenario: A finished season is offered for closure on Today, and the card goes once closed
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the day advances by {330} days
    And the app is running
    Then I see {'Close the 2026-2027 season?'} text
    When I tap {'Close the season'} text
    Then I see {'Close the 2026-2027 season'} text
    When I tap {'Close the season'} text
    And I tap {'Back to Today'} text
    Then I do not see {'Close the 2026-2027 season?'} text

  Scenario: The card is not shown while the season runs
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    Then I do not see text containing {'Close the 2026-2027'}

  Scenario: The assistant fits a phone and leaves nothing to scroll sideways
    Given the screen is {390} by {844}
    And the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    Then I see {'3. What to do with each student?'} text
    And no layout overflow is reported

  Scenario: The assistant is French on a French device
    Given the device language is {'fr'}
    And the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the closure of the season {'2026-2027'}
    Then I see {'Clôturer la saison 2026-2027'} text
    And I see {'Tout reconduire'} text
    And I see {'Tout effacer'} text
    And I see {'1 élève à effacer, 1 à reconduire.'} text
