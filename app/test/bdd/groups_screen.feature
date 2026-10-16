# Lot 11a (ADR 0019), écrans : plusieurs groupes par public, depuis la liste
# des élèves et la fiche d'un élève. « Aujourd'hui » est le lundi 12 octobre
# 2026.
Feature: Groups screen

  Scenario: Creating a second group of children
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'New group'} text
    And I enter {'Wednesday'} into {0} input field
    And I tap {'Create the group'} text
    Then I see {'Group “Wednesday” created.'} text
    And I see {'Wednesday'} text
    And I see {'Children group'} text

  Scenario: A name already used in the season is refused
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'New group'} text
    And I enter {' CHILDREN group '} into {0} input field
    And I tap {'Create the group'} text
    Then I see {'Another group of this season already has this name.'} text

  Scenario: Renaming a group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I open the menu of the group {'Children group'}
    And I tap {'Rename'} text
    And I enter {'Beginners'} into {0} input field
    And I tap {'Save'} text
    Then I see {'Group renamed to “Beginners”.'} text
    And I see {'Beginners'} text
    And I do not see {'Children group'} text

  Scenario: An empty group without any session can be deleted
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the group {'Wednesday'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I open the menu of the group {'Wednesday'}
    And I tap {'Delete'} text
    And I tap {'Confirm'} text
    Then I see {'Group “Wednesday” deleted.'} text
    And I do not see {'Wednesday'} text

  Scenario: A group with members cannot be deleted
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I open the menu of the group {'Children group'}
    And I tap {'Delete'} text
    And I tap {'Confirm'} text
    Then I see {'This group still has members: move them first.'} text
    And I see {'Léa'} text

  Scenario: Enrolling asks for the group when the audience has several
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the group {'Wednesday'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Add a student'} text
    And I enter {'Hugo'} into {0} input field
    And I tap {'Save'} text
    Then I see {'Which group?'} text
    When I tap {'Wednesday'} text
    And I tap {'Save'} text
    Then I see {'Hugo'} text
    And the student {'Hugo'} belongs to the group {'Wednesday'}

  Scenario: Enrolling in the only group of the audience asks nothing
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Add a student'} text
    And I enter {'Hugo'} into {0} input field
    And I tap {'Save'} text
    Then I do not see {'Which group?'} text
    And the student {'Hugo'} belongs to the group {'Children group'}

  Scenario: Changing the group of a student
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the group {'Wednesday'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Change group'} text
    Then I see {'Current group: Children group'} text
    When I tap {'Wednesday'} text
    And I tap {'Move'} text
    Then I see {'Léa is now in the group “Wednesday”.'} text
    And the student {'Léa'} belongs to the group {'Wednesday'}

  Scenario: Among several groups, the chosen one receives the student
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the group {'Wednesday'} in the {'children'} audience
    And the club has the group {'Saturday'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Change group'} text
    And I tap {'Saturday'} text
    And I tap {'Move'} text
    Then the student {'Léa'} belongs to the group {'Saturday'}

  Scenario: A student alone in the audience has nowhere to go
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    And I tap {'Change group'} text
    Then I see {'There is no other group for this audience in the season. Create one from the students list.'} text

  Scenario: Changing the audience asks for the group when the new audience has two
    Given the club has the student {'Hugo'} in the {'children'} audience
    And the club has the group {'Evening'} in the {'adults'} audience
    And the club has the group {'Noon'} in the {'adults'} audience
    And the app is running
    When I open the review of {'Hugo'}
    And I tap {'Move to the Adults audience'} text
    And I tap {'Confirm'} text
    Then I see {'Which group?'} text
    When I tap {'Noon'} text
    And I tap {'Move to the Adults audience'} text
    And I tap {'Confirm'} text
    Then I see {'Current audience: Adults'} text
    And the student {'Hugo'} belongs to the group {'Noon'}
