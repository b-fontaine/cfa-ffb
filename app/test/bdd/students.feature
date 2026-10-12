# Parcours (a) : liste des élèves du groupe, public, alertes, ajout et édition.
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

  Scenario: Correcting the first name of a student
    Given the club has the student {'Lea'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Lea'} text
    And I tap {'Edit the first name'} text
    And I enter {'Léa'} into {0} input field
    And I tap {'Save'} text
    Then I see {'Léa'} text

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
