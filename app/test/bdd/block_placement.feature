# Lot 7 : positionnement initial (ADR 0008, docs/engineering/positionnement-initial-plan.md § 8).
# L'animateur marque un bloc entier « acquis » depuis la fiche de l'élève, sans
# passage fictif. Les passages saisis le jour du positionnement ou après
# reprennent la main sur leur exercice seulement. Les séances amorcées par
# « has {n} passes » datent du 12 septembre 2026 puis des jours suivants, deux
# passages par séance au plus ; « aujourd'hui » vaut le 12 octobre 2026. Le
# catalogue compte 70 exercices ; « Posture, visée et coup de queue » en a 4.
Feature: Block placement

  Background:
    Given the club has the student {'Léa'} in the {'children'} audience

  Scenario: A fresh sheet offers the placement menu on every block
    Given the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Path to start'} text
    And I see {15} placement menus

  Scenario: Marking a block as acquired shows its status, its date and the counter
    Given the app is running
    When I open the sheet of {'Léa'}
    And I mark the block {'Posture, visée et coup de queue'} as acquired
    And I tap {'Mark as acquired'} text
    Then I see {'Block marked as acquired: Posture, visée et coup de queue'} text
    And I see {'Acquired at placement'} text
    And I see {'Acquired at placement on Mon, Oct 12'} text
    And I see {'4 exercises validated'} text

  Scenario: The next exercise skips the acquired block
    Given {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'La puissance · exercise 1'} text

  Scenario: Acquired blocks add up in the counter
    Given {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And {'Léa'} has the block {'puissance'} acquired on {'2026-10-12'}
    And {'Léa'} has the block {'bille-fantome'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'10 exercises validated'} text
    And I see {'La quantité de bille pleine · exercise 1'} text

  Scenario: A date in the future is refused under the dialog
    Given the app is running
    When I open the sheet of {'Léa'}
    And I mark the block {'Posture, visée et coup de queue'} as acquired
    And I tap {'Placement date'} text
    And I pick the day {20} in the date picker
    And I tap {'Mark as acquired'} text
    Then I see {'The date cannot be in the future.'} text
    When I tap {'Cancel'} text
    Then I see {'Path to start'} text

  Scenario: The dialog proposes the day it is opened, not the day the sheet was built
    Given the app is running
    When I open the sheet of {'Léa'}
    And the day advances by {1} days
    And I mark the block {'Posture, visée et coup de queue'} as acquired
    Then I see {'Tue, Oct 13'} text

  Scenario: Cancelling the dialog marks nothing
    Given the app is running
    When I open the sheet of {'Léa'}
    And I mark the block {'Posture, visée et coup de queue'} as acquired
    And I tap {'Cancel'} text
    Then I see {'Path to start'} text
    And I do not see {'Acquired at placement'} text

  Scenario: Removing the acquired status after confirmation restores the counter
    Given {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'4 exercises validated'} text
    When I open the placement menu of {'Posture, visée et coup de queue'}
    And I tap {'Remove acquired status'} text
    Then I see {'Remove acquired status for “Posture, visée et coup de queue”?'} text
    When I tap {'Confirm'} text
    Then I see {'Acquired status removed.'} text
    And I see {'Path to start'} text
    And I do not see {'Acquired at placement'} text

  Scenario: Cancelling the removal keeps the acquired status
    Given {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I open the placement menu of {'Posture, visée et coup de queue'}
    And I tap {'Remove acquired status'} text
    And I tap {'Cancel'} text
    Then I see {'Acquired at placement'} text
    And I see {'4 exercises validated'} text

  Scenario: A pass after the date takes over its exercise only
    Given {'Léa'} has the block {'posture'} acquired on {'2026-09-01'}
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'3 exercises validated'} text
    And I see {'3/4'} text
    And I see {'Acquired at placement on Tue, Sep 1; 1 exercise taken over by passes recorded since'} text
    When I open the placement menu of {'Posture, visée et coup de queue'}
    Then I see {'Remove acquired status'} text

  Scenario: A pass on the same day takes over its exercise
    Given {'Léa'} has the block {'posture'} acquired on {'2026-09-12'}
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'3 exercises validated'} text
    And I see {'Acquired at placement on Sat, Sep 12; 1 exercise taken over by passes recorded since'} text

  Scenario: A pass dated before the placement does not take over
    Given {'Léa'} has {1} successful passes on {'posture 1'}
    And {'Léa'} has the block {'posture'} acquired on {'2026-09-13'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'4 exercises validated'} text
    And I see {'Acquired at placement'} text
    And I do not see text containing {'taken over by passes'}

  Scenario: A block mastered by passes is not offered to be marked
    Given {'Léa'} has validated the block {'posture'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {14} placement menus

  Scenario: An old alert on an acquired block is hidden until the exercise is taken over
    Given {'Léa'} has {3} failed passes on {'posture 1'}
    And {'Léa'} has the block {'posture'} acquired on {'2026-09-14'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I do not see {'Warning'} text
    When {'Léa'} has {1} failed passes on {'posture 1'}
    And I tap the back button
    Then I see {'Club students'} text
    When I tap {'Léa'} text
    Then I see {'Warning'} text

  Scenario: An acquired block is never overdue nor to review
    Given {'Léa'} has {5} failed passes on {'posture 1'}
    And {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I do not see {'More sessions than recommended'} text
    And I do not see {'To review'} text

  Scenario: Removing a dormant marker leaves the counter unchanged
    Given {'Léa'} has the block {'posture'} acquired on {'2026-09-12'}
    And {'Léa'} has {1} successful passes on {'posture 1'}
    And {'Léa'} has {1} successful passes on {'posture 2'}
    And {'Léa'} has {1} successful passes on {'posture 3'}
    And {'Léa'} has {1} successful passes on {'posture 4'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'0 exercises validated'} text
    And I see {'Acquired at placement on Sat, Sep 12; 4 exercises taken over by passes recorded since'} text
    When I open the placement menu of {'Posture, visée et coup de queue'}
    And I tap {'Remove acquired status'} text
    And I tap {'Confirm'} text
    Then I see {'0 exercises validated'} text
    And I do not see text containing {'taken over by passes'}

  Scenario: The acquired status survives reopening the sheet
    Given the app is running
    When I open the sheet of {'Léa'}
    And I mark the block {'Posture, visée et coup de queue'} as acquired
    And I tap {'Mark as acquired'} text
    And I tap the back button
    Then I see {'Club students'} text
    When I tap {'Léa'} text
    Then I see {'Acquired at placement'} text
    And I see {'4 exercises validated'} text

  Scenario: Acquired at placement is distinct from mastered by passes
    Given {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And {'Léa'} has validated the block {'puissance'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Acquired at placement'} text
    And I see {'Mastered'} text

  Scenario: A proposed block can be marked as acquired and keeps its badge
    Given {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Acquired at placement'} text
    And I see the badge {'Proposal'} in the block {'Posture, visée et coup de queue'}

  Scenario: The menu button carries the name of the block
    Given the app is running
    When I open the sheet of {'Léa'}
    Then I see the button {'Placement actions: Posture, visée et coup de queue'}

  Scenario: Marking a block as acquired refreshes the notion to recall
    Given {'Léa'} has {1} failed passes on {'puissance 2'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'La puissance, exercise 2'} text
    When I mark the block {'La puissance'} as acquired
    And I tap {'Mark as acquired'} text
    Then I see {'No notion to recall for now.'} text
    And I do not see {'La puissance, exercise 2'} text

  Scenario: Removing the acquired status refreshes the notion to recall
    Given {'Léa'} has {1} failed passes on {'puissance 2'}
    And {'Léa'} has the block {'puissance'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'No notion to recall for now.'} text
    When I open the placement menu of {'La puissance'}
    And I tap {'Remove acquired status'} text
    And I tap {'Confirm'} text
    Then I see {'La puissance, exercise 2'} text
