# FB7, partie B : l'écran et le parcours d'import d'une sauvegarde dans un club
# synchronisé. Le moteur (plan, lots, marqueur) est celui de la partie A, sur un
# faux Firestore qui applique les garde-fous des règles (voir
# test/support/import_world.dart) ; ces scénarios prouvent le PARCOURS : ce que
# l'animateur voit, choisit, confirme, et ce que le club contient ensuite. Les
# règles réelles sont jouées par scripts/rules_test/import.test.mjs, le parcours
# navigateur par scripts/emulator_e2e. Le texte par défaut est l'anglais.
Feature: Import a backup into the club

  Background:
    Given a synchronised club
    And a backup of {2} groups, {6} students and {3} sessions per group with {4} passes per student and session

  Scenario: The director imports a complete file
    When the import screen is opened as the director
    Then I see {'Choose the file'} text
    And I see {'You are importing as: Director.'} text
    When I choose the backup file
    Then I see {'File report'} text
    And I see {'Choices are needed'} text
    And I see text containing {'Groups: 2 in the file'}
    When I tap {'Continue'} text
    Then I see {'Matching the groups'} text
    And the action {'Continue'} is blocked
    When I create every group of the file
    Then the action {'Continue'} is available
    When I tap {'Continue'} text
    Then I see {'Summary before writing'} text
    And I see text containing {'Effective role: Director'}
    And I see text containing {'writes to do'}
    When I tap {'Import now'} text
    Then I see {'Import finished'} text
    And the club holds {2} groups and {6} students
    And the club holds {72} passes
    And the screen shows no identifier of the account

  Scenario: A teacher imports only into their groups and confirms the records they cannot check
    Given the club has the group {'Jeudi'} run by the teacher
    And the club has the group {'Mardi'} run by another teacher
    And a backup of a single group
    When the import screen is opened as the teacher
    Then I see {'You are importing as: Teacher.'} text
    When I choose the backup file
    And I tap {'Continue'} text
    Then I see {'Matching the groups'} text
    And the menu of the group {'Groupe 1'} offers {'To choose, Match to: Jeudi'}
    When I match the group {'Groupe 1'} to {'Match to: Jeudi'}
    And I tap {'Continue'} text
    Then I see {'Confirmations'} text
    And I see text containing {'3 student records will be created'}
    And the action {'Continue'} is blocked
    When I tick {'I confirm creating 3 records that cannot be checked'}
    Then the action {'Continue'} is available
    When I tap {'Continue'} text
    Then I see {'Summary before writing'} text
    And I see text containing {'Effective role: Teacher'}
    When I tap {'Import now'} text
    Then I see {'Import finished'} text
    And the club holds {3} students in the group {'Jeudi'}

  Scenario: A record that exists outside the groups of the teacher is refused by the server, soberly
    Given the club has the group {'Jeudi'} run by the teacher
    And a backup of a single group
    And a record of the file already exists in the club outside the groups of the teacher
    When the import screen is opened as the teacher
    And I choose the backup file
    And I tap {'Continue'} text
    And I match the group {'Groupe 1'} to {'Match to: Jeudi'}
    And I tap {'Continue'} text
    And I tick {'I confirm creating 3 records that cannot be checked'}
    And I tap {'Continue'} text
    And I tap {'Import now'} text
    Then I see text containing {'The server refused to write a batch'}
    And I see text containing {'That batch wrote nothing'}
    And nothing was written in the club

  Scenario: An invalid file is blocked with a localised problem and no child data
    Given the file is not a backup
    When the import screen is opened as the director
    And I choose the backup file
    Then I see {'Import not possible'} text
    And I see text containing {'The file is not a readable backup.'}
    And I do not see {'Continue'} text
    And I see {'Choose another file'} text
    And nothing was written in the club

  Scenario: A backup that cites unknown catalogue sheets is blocked
    Given the backup cites a sheet that the catalogue does not know
    When the import screen is opened as the director
    And I choose the backup file
    Then I see {'Import not possible'} text
    And I do not see {'Continue'} text

  Scenario: A planned session without a group cannot be imported without an explicit choice
    Given the backup holds a planned session without a group
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    Then I see {'Sessions and students without a group'} text
    And I see text containing {'Séance sans groupe'}
    And the action {'Continue'} is blocked
    And nothing was written in the club
    When I attach the session {'p-orphan'} to {'Attach to: Groupe 1'}
    Then the action {'Continue'} is available
    When I tap {'Continue'} text
    Then I see {'Summary before writing'} text

  Scenario: A planned session without a group can be skipped explicitly
    Given the backup holds a planned session without a group
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    And I attach the session {'p-orphan'} to {'Skip (do not import)'}
    And I tap {'Continue'} text
    And I tap {'Import now'} text
    Then I see {'Import finished'} text
    And the club holds no planned session {'p-orphan'}

  Scenario: A student without a group needs an explicit choice, to attach or to skip
    Given the backup holds a student without a group
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    Then I see {'Sessions and students without a group'} text
    And the action {'Continue'} is blocked
    And nothing was written in the club
    When I attach the student {'s-g1-1'} to {'Attach to: Groupe 1'}
    Then the action {'Continue'} is available
    When I attach the student {'s-g1-1'} to {'Skip (do not import)'}
    Then the action {'Continue'} is available
    When I tap {'Continue'} text
    And I tap {'Import now'} text
    Then I see {'Import finished'} text

  Scenario: Students who may have been erased are restored only after a confirmation of their exact number
    Given the club closed a season after the export of the file and keeps only {3} students of the file
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    Then I see {'Confirmations'} text
    And I see text containing {'3 students missing from the club may have been erased'}
    And I see text containing {'check before confirming'}
    And the action {'Continue'} is blocked
    When I tick {'I confirm restoring 3 students'}
    Then the action {'Continue'} is available
    When I tap {'Continue'} text
    And I tap {'Import now'} text
    Then I see {'Import finished'} text
    And the club holds {2} groups and {6} students

  Scenario: A group of the file can only be matched to a group of the same audience
    Given the club has the group {'Mardi'} run by the teacher
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    Then the menu of the group {'Groupe 1'} offers {'To choose, Create in the club'}
    And the menu of the group {'Groupe 2'} offers {'To choose, Create in the club, Match to: Mardi'}

  Scenario: An interrupted import resumes by itself when the network comes back
    Given the batches hold at most {60} writes
    And the network is cut after {1} batches
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    And I tap {'Import now'} text
    Then I see text containing {'Import interrupted: no connection'}
    And I see text containing {'1 of'}
    And I do not see {'Action needed'} text
    When the connection comes back
    Then I see {'Import finished'} text
    And the club is identical to the one of a complete import

  Scenario: Opening the screen again with the same file and the same account resumes at the right batch
    Given the batches hold at most {60} writes
    And the network is cut after {1} batches
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    And I tap {'Import now'} text
    Then I see text containing {'Import interrupted: no connection'}
    When the network is back but the screen is closed
    And the import screen is opened as the director
    And I choose the backup file
    Then I see text containing {'An import of this file by this account has started: 1 of'}
    When I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    Then I see text containing {'Resuming at batch 2 of'}
    When I tap {'Resume the import'} text
    Then I see {'Import finished'} text
    And the club is identical to the one of a complete import

  Scenario: Another file or another account starts cleanly
    Given the batches hold at most {60} writes
    And the network is cut after {1} batches
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    And I tap {'Import now'} text
    And the network is back but the screen is closed
    And another account opens the import screen
    And I choose the backup file
    Then I do not see text containing {'has started'}
    When the same account opens the import screen again with another file
    And I choose the backup file
    Then I do not see text containing {'has started'}

  Scenario: The daily limit pauses the import without an error, and the next day it resumes
    Given the club writes at most {60} per day
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    Then I see text containing {'because of the daily write limit'}
    When I tap {'Import now'} text
    Then I see text containing {'Paused: daily limit reached'}
    And I see text containing {'Resume tomorrow'}
    And I do not see {'Action needed'} text
    When the next day comes
    And the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    And I tap {'Resume the import'} text
    Then I see {'Import finished'} text
    And the club is identical to the one of a complete import

  Scenario: A file that is already fully imported is announced and not written again
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    And I tap {'Import now'} text
    Then I see {'Import finished'} text
    When the import screen is opened as the director
    And I choose the backup file
    Then I see {'This file is already imported'} text
    And I see text containing {'already fully imported'}
    And I do not see {'Continue'} text

  Scenario: The import can be stopped between two batches and resumed
    Given the batches hold at most {60} writes
    When the import screen is opened as the director
    And I choose the backup file
    And I tap {'Continue'} text
    And I create every group of the file
    And I tap {'Continue'} text
    And I start the import and ask to stop during the first batch
    Then I see text containing {'Import stopped after 1 of'}
    When I tap {'Resume'} text
    Then I see {'Import finished'} text
