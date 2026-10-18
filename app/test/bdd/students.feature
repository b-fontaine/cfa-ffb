# Parcours (a) : liste des élèves du groupe, public, alertes, ajout et édition,
# puis vue de groupe (lot U9) : carte de chaleur technique × élève avec son
# alternative textuelle, assiduité et alertes de groupe. « Aujourd'hui » est le
# lundi 12 octobre 2026.
Feature: Students

  Scenario: The club starts without any student
    Given the app is running
    When I tap {'Students'} text
    Then I see {'No student yet. Add the first one to follow their progress.'} text

  Scenario: Adding a child student
    Given the app is running
    When I tap {'Students'} text
    And I tap {'Add a student'} text
    And I enter {'Léa'} into {0} input field
    And I tap {'Save'} text
    Then I see {'Léa'} text
    And I see {'Children'} text

  Scenario: Adding an adult student puts him in an adults group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Add a student'} text
    And I enter {'Hugo'} into {0} input field
    And I tap {'Adults'} text
    And I tap {'Save'} text
    Then I see {'Hugo'} text
    And I see {'Adults group'} text
    And I see {'Children group'} text

  Scenario: A first name is required
    Given the app is running
    When I tap {'Students'} text
    And I tap {'Add a student'} text
    And I tap {'Save'} text
    Then I see {'The first name is required.'} text

  Scenario: A first name is at most 40 characters
    Given the app is running
    When I tap {'Students'} text
    And I tap {'Add a student'} text
    And I enter {'Abcdefghijklmnopqrstuvwxyzabcdefghijklmno'} into {0} input field
    And I tap {'Save'} text
    Then I see {'This name is too long.'} text

  Scenario: Correcting the first name of a student
    Given the club has the student {'Lea'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Lea'} text
    And I tap {'Edit the first name'} text
    And I enter {'Léa'} into {0} input field
    And I tap {'Save'} text
    Then I see {'Léa'} text

  Scenario: A new student has a path to start, not a score of zero out of seventy
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    Then I see {'Path to start'} text
    And I do not see text containing {'of 70'}

  Scenario: A student who practised sees the exercises validated, not a fraction of seventy
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And the app is running
    When I tap {'Students'} text
    Then I see {'4 exercises validated'} text
    And I do not see text containing {'of 70'}

  Scenario: An alert is visible in the list after three failures
    Given the club has the student {'Théo'} in the {'children'} audience
    And {'Théo'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I tap {'Students'} text
    Then I see {'1 alert'} text

  Scenario: The list is displayed in French on a French device
    Given the device language is {'fr'}
    And the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Élèves'} text
    Then I see {'Les élèves du club'} text
    And I see {'Enfants'} text

  # Lot 10b (ADR 0020) : l'état d'une séance guidée en cours de son groupe
  # s'efface aussi ; la confirmation le dit avant l'effacement.
  Scenario: The erasure confirmation warns that a running guided session of the group is erased too
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    Then I see text containing {'running guided session'}

  Scenario: The erasure confirmation warns in French that a running guided session is erased too
    Given the device language is {'fr'}
    And the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Élèves'} text
    And I tap {'Léa'} text
    And I tap {'Effacer Léa'} text
    Then I see text containing {'séance guidée en cours'}

  # Lot 7 (ADR 0008) : les blocs marqués acquis d'un élève s'effacent avec lui.
  Scenario: Erasing a student also erases the blocks marked as acquired
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has the block {'posture'} acquired on {'2026-10-12'}
    And {'Hugo'} has the block {'puissance'} acquired on {'2026-10-12'}
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Erase Léa'} text
    And I tap {'Confirm'} text
    Then I see {'Hugo'} text
    And I do not see {'Léa'} text
    And the club keeps no data for {'Léa'}
    And the club keeps {1} acquired blocks in total

  Scenario: A group card offers its grid
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    Then I see {'Group grid'} text

  Scenario: The grid shows technique by student with a fraction in every cell
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'posture 1'}
    And {'Léa'} has {3} failed passes on {'puissance 1'}
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    Then I see {'Children group'} text
    And I see {'Techniques by student'} text
    And the grid has {15} rows and {2} students
    And I see the grid described as {'Léa, Posture, visée et coup de queue: 0 of 4 exercises, In progress'}
    And I see the grid described as {'Hugo, Posture, visée et coup de queue: 0 of 4 exercises, Not started'}
    And I see the grid described as {'Léa, La puissance: 0 of 4 exercises, To review, alert in progress'}

  Scenario: Each technique row is summarised as text
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Hugo'} has {2} successful passes on {'posture 1'}
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    Then I see the grid described as {'Posture, visée et coup de queue: 1 of 2 students completed, 1 in progress, 0 to start'}
    And I see the grid described as {'La puissance: 0 of 2 students completed, 0 in progress, 2 to start'}

  Scenario: A text summary lists the students of each technique
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Hugo'} has {2} successful passes on {'posture 1'}
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    And I tap {'Text summary'} text
    Then I see {'Posture, visée et coup de queue. Completed: Léa. In progress: Hugo. To start: nobody.'} text
    And I see {'La puissance. Completed: nobody. In progress: nobody. To start: Hugo, Léa.'} text

  Scenario: Tapping a cell opens the student sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    And I tap the grid cell of {'Léa'} on {'posture'}
    Then I see {'Maturity review'} text
    And I see {'Léa'} text

  Scenario: The group attendance counts the present members over the possible ones
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'posture 1'}
    And {'Hugo'} has {1} successful passes on {'posture 1'}
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    Then I see {'Group attendance'} text
    And I see {'2 attendances out of 4 possible (50 %)'} text
    And I see {'2 sessions'} text

  Scenario: A group without session says there is no session instead of zero percent
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    Then I see {'No session recorded yet.'} text
    And I do not see text containing {'0 %'}

  Scenario: Two students out of two failing a technique raise a group alert
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {1} failed passes on {'posture 1'}
    And {'Hugo'} has {1} failed passes on {'posture 1'}
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    Then I see {'Group alerts'} text
    And I see {'2 students out of 2 missed “Posture, visée et coup de queue” on their last pass'} text

  Scenario: A single failing student raises no group alert
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {1} failed passes on {'posture 1'}
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    Then I do not see {'Group alerts'} text

  Scenario: The grid scrolls horizontally on a phone while the technique column stays
    Given the screen is {390} by {844}
    And the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And the club has the student {'Eve'} in the {'children'} audience
    And the club has the student {'Max'} in the {'children'} audience
    And the club has the student {'Zoé'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    Then the technique column stays in place when the grid scrolls

  Scenario: The cells of the grid are at least 48 dp
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Group grid'} text
    Then the grid cells are at least {48} dp
    And the buttons are at least {48} dp high

  Scenario: The group grid opens from its direct link
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address of the grid of the group {'Children group'}
    Then I see {'Techniques by student'} text
    And I see {'Children group'} text

  Scenario: The grid is French on a French device
    Given the device language is {'fr'}
    And the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Élèves'} text
    And I tap {'Grille du groupe'} text
    Then I see {'Techniques par élève'} text
    And I see {'Assiduité du groupe'} text
    And I see {'Aucune séance saisie pour le moment.'} text
