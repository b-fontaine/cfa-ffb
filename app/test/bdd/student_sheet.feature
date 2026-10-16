# Parcours (b) : fiche élève, parcours en cases (une ligne par technique, une
# case par exercice), en-tête « en cours / prochain / alerte », courbes
# repliées, acquittement d'une alerte et vue « à montrer à l'élève » (lot U9,
# ADR 0013, décision Q6). « Aujourd'hui » est le lundi 12 octobre 2026.
Feature: Student sheet

  Scenario: Progress per block and next exercise
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Léa'} has {5} successful passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Current exercise'} text
    And I see {'La puissance · exercise 2'} text
    And I see {'Next exercise'} text
    And I see {'La puissance · exercise 3'} text
    And I see {'1 of 15 techniques completed'} text
    And I see {'5 exercises validated'} text

  Scenario: The performance curve shows each attempt with a text alternative
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And {'Léa'} has {1} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Performance curves'} text
    Then I see the curve of {'puissance 1'} with {3} attempts
    And I see {'Attempt 1: 7 of 9'} text
    And I see {'Attempt 3: 6 of 9'} text

  Scenario: A notion to recall is suggested after a missed pass
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'puissance'}
    And {'Léa'} has {1} failed passes on {'puissance 2'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Notion to recall'} text
    And I see {'La puissance, exercise 2'} text
    And I see {'Last pass missed'} text

  # Assiduité (ADR 0006) : séances des groupes de l'élève aux dates où il en
  # est membre ; Léa n'était présente qu'à la sienne, pas à celle de Hugo.
  Scenario: Attendance counts the sessions of the group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And {'Hugo'} has {1} successful passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Attendance'} text
    And I see {'Present at 1 session of 2'} text

  Scenario: A student sheet opens from its direct link
    Given the club has the student {'Léa'} in the {'adults'} audience
    And the app is running
    When I go to the address of the sheet of {'Léa'}
    Then I see {'Léa'} text
    And I see {'Adults'} text

  Scenario: Three failed passes raise a warning on the sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Warning'} text
    And I see {'La puissance · exercise 1: 3 consecutive failures'} text
    And I do not see {'Action needed'} text

  Scenario: Five failed passes make the alert persistent
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {5} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Action needed'} text
    And I see {'La puissance · exercise 1: 5 consecutive failures'} text
    And I do not see {'Warning'} text

  Scenario: A student without repeated failures has no alert on the sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I do not see {'Warning'} text
    And I do not see {'Action needed'} text

  Scenario: Erasing a student removes all their data after confirmation
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And {'Hugo'} has {1} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    Then I see {'Erase Léa permanently?'} text
    When I tap {'Confirm'} text
    Then I see {'Hugo'} text
    And I do not see {'Léa'} text
    And the club keeps no data for {'Léa'}
    And the club keeps {1} passes in total

  Scenario: Cancelling the erasure keeps the student and their data
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    And I tap {'Cancel'} text
    Then I see {'Léa'} text
    And the club keeps {2} passes in total

  Scenario: The path shows one row per technique and one cell per exercise
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    Then the path has {15} rows and {70} cells
    And I see {'Path'} text
    And I see {'70 exercises in total'} text

  Scenario: A cell is to do, started, validated or acquired, each with its own text
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And {'Léa'} has the block {'bille-fantome'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then the cell {'posture 1'} is {'validated'}
    And the cell {'puissance 1'} is {'started, 2 of 5 successful passes'}
    And the cell {'puissance 2'} is {'to do'}
    And the cell {'bille-fantome 1'} is {'acquired at placement'}

  Scenario: A block marked as acquired at placement shows full acquired cells
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then the cell {'posture 1'} is {'acquired at placement'}
    And the cell {'posture 4'} is {'acquired at placement'}
    And I see {'Acquired at placement'} text
    And I see {'Acquired at placement on Mon, Oct 12'} text
    And I see {'4 exercises validated'} text
    And I see {'1 of 15 techniques completed'} text

  Scenario: An exercise taken back after placement shows its passes while the rest stays acquired
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has the block {'posture'} acquired on {'2026-09-01'}
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then the cell {'posture 1'} is {'started, 1 of 5 successful passes'}
    And the cell {'posture 2'} is {'acquired at placement'}

  Scenario: The header shows the exercise in progress, the next one and the alert
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Current exercise'} text
    And I see {'La puissance · exercise 1'} text
    And I see {'Next exercise'} text
    And I see {'La puissance · exercise 2'} text
    And I see {'Warning'} text
    And I see {'La puissance · exercise 1: 3 consecutive failures'} text
    And the cell {'puissance 1'} is {'started, 0 of 5 successful passes, alert in progress'}

  Scenario: Several alerts show the most serious one and count the others
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {5} failed passes on {'posture 1'}
    And {'Léa'} has {3} failed passes on {'posture 2'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Action needed'} text
    And I see {'Posture, visée et coup de queue · exercise 1 · Proposal: 5 consecutive failures'} text
    And I see {'+ 1 other alert'} text

  Scenario: A student without any pass sees a path to start, not a score of zero
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Path to start'} text
    And I see {'Exercise to start'} text
    And I do not see text containing {'of 70'}

  Scenario: A student who practised without validating sees the count, not a path to start
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'posture 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I do not see {'Path to start'} text
    And I see {'0 of 15 techniques completed'} text
    And I see {'0 exercises validated'} text
    And I see {'Current exercise'} text

  Scenario: A finished level shows no exercise in progress and no next exercise
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has every block acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Level 1 completed: every exercise is validated.'} text
    And I see {'15 of 15 techniques completed'} text
    And I do not see {'Current exercise'} text
    And I do not see {'Next exercise'} text

  Scenario: Tapping a cell opens the curve of its exercise with a text alternative
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And {'Léa'} has {1} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap the cell {'puissance 1'}
    Then I see the curve of {'puissance 1'} with {3} attempts
    And I see {'Attempt 1: 7 of 9'} text
    And I see {'Attempt 3: 6 of 9'} text

  Scenario: Tapping a cell never practised says so
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap the cell {'puissance 2'}
    Then I see {'Not practised yet.'} text

  Scenario: The curves are folded by default and open on demand
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Performance curves'} text
    And I do not see the curve of {'puissance 1'}
    When I tap {'Performance curves'} text
    Then I see the curve of {'puissance 1'} with {2} attempts

  Scenario: The rare actions are at the bottom of the sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    Then {'Show to the student'} is shown above {'Path'}
    And {'Path'} is shown above {'Edit the first name'}
    And {'Path'} is shown above {'Maturity review'}
    And {'Path'} is shown above {'Erase Léa'}

  Scenario: The placement actions are in the menu of the technique row
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see the button {'Placement actions: Posture, visée et coup de queue'}
    And I do not see {'Mark block as acquired'} text
    When I open the placement menu of {'Posture, visée et coup de queue'}
    Then I see {'Mark block as acquired'} text

  Scenario: Every cell and every button of the sheet is at least 48 dp
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then the path cells are at least {48} dp
    And the buttons are at least {48} dp high

  Scenario: An alert can be marked as seen
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Warning'} text
    When I tap {'Seen'} text
    Then I see {'Alert marked as seen.'} text
    And I do not see {'Warning'} text
    And I see {'Alert seen on Mon, Oct 12: La puissance · exercise 1'} text
    And I see {'Restore'} text

  Scenario: A seen alert leaves the students to watch of the home
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Seen'} text
    And I tap {'Today'} text
    Then I see {'Nobody needs watching'} text

  Scenario: A seen alert can be restored
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Seen'} text
    And I tap {'Restore'} text
    Then I see {'Alert restored.'} text
    And I see {'Warning'} text
    And I do not see {'Restore'} text

  Scenario: The showcase shows the first name and the path only
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And {'Hugo'} has {2} successful passes on {'posture 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Show to the student'} text
    Then I see {'Léa'} text
    And I see {'Your current exercise'} text
    And the showcase path has {15} rows and {70} cells
    And I do not see {'Warning'} text
    And I do not see {'Seen'} text
    And I do not see {'Hugo'} text
    And I do not see {'Attendance'} text
    And I do not see {'Maturity review'} text
    And I do not see {'Notion to recall'} text
    And I do not see {'Children'} text
    And I do not see {'Performance curves'} text

  Scenario: The showcase does not flag a proposal technique as a proposal
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Proposal'} text {2} times
    When I tap {'Show to the student'} text
    Then I do not see {'Proposal'} text

  Scenario: The showcase shows a technique to review as in progress
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'posture 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'To review'} text
    When I tap {'Show to the student'} text
    Then I do not see {'To review'} text
    And I see {'In progress'} text {1} times

  Scenario: The pass dots of the showcase count the successful passes only
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'posture 1'}
    And {'Léa'} has {2} failed passes on {'posture 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Show to the student'} text
    Then I see {'2/5'} text

  Scenario: Finishing the showcase goes back to the sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Show to the student'} text
    And I tap {'Done'} text
    Then I see {'Maturity review'} text
    And I see {'Path'} text

  Scenario: The system back button leaves the showcase for the sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Show to the student'} text
    And I press the system back button
    Then I see {'Maturity review'} text

  Scenario: The showcase has no navigation bar and opens from its direct link
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address of the showcase of {'Léa'}
    Then I see {'Your current exercise'} text
    And I see the {'none'} navigation

  Scenario: The sheet is French on a French device
    Given the device language is {'fr'}
    And the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I tap {'Élèves'} text
    And I tap {'Léa'} text
    Then I see {'Parcours'} text
    And I see {'Exercice en cours'} text
    And I see {'Vu'} text
    And I see {'Montrer à l’élève'} text
