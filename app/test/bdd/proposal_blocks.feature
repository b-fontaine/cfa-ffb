# Parcours : les blocs proposés [Prop] (posture, bille fantôme) ne sont jamais
# présentés comme fédéraux, partout où l'application les affiche.
Feature: Proposal blocks

  The posture and ghost ball training blocks are not in the federal sheets:
  they are proposals adapted from them. Every screen that shows one says so,
  and the source note never claims a federal sheet for them.

  Scenario: The sheet of a proposed exercise is marked as a proposal
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I open the source sheet of exercise {1}
    Then I see {'Proposal'} text
    And I see text containing {'non-federal proposal'}
    And I do not see text containing {'federal sheets'}
    And I see {'Required: 3 out of 4'} text
    And I see the billiard table

  Scenario: The marker is French on a French device
    Given the device language is {'fr'}
    And the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Séances'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggérer une séance'} text
    And I open the source sheet of exercise {1}
    Then I see {'Proposition'} text
    And I see text containing {'proposition non fédérale'}

  Scenario: A federal exercise carries no proposal marker
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Léa'} has validated the block {'puissance'}
    And {'Léa'} has validated the block {'bille-fantome'}
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I open the source sheet of exercise {1}
    Then I do not see {'Proposal'} text
    And I see text containing {'federal sheets'}

  Scenario: The progress of a student marks the proposed blocks
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the sheet of {'Léa'}
    Then I see {'Posture, visée et coup de queue'} text
    And I see text containing {'exercise 1 · Proposal'}

  Scenario: The first exercise of a new student is the proposed posture block
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'Posture, visée et coup de queue'} text
    And I see text containing {'exercise 1 · Proposal'}

  Scenario: Recording on a proposed exercise says it is a proposal
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I open the session of the group {'Children group'}
    Then I see text containing {'no. 1 (3/4) · Proposal'}
