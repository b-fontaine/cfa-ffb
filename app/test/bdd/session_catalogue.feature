# Parcours (L4, ADR 0004) : consulter le catalogue de séances, en lecture
# seule, et relire les propositions non sourcées dans leur contexte.
Feature: Session catalogue

  The instructor opens the catalogue from the menu, browses the 14 techniques
  and their 28 sessions, reads a session without being able to change it, and
  reviews the unsourced proposals in their context.

  Scenario: The menu leads to the 14 techniques and their 28 sessions
    Given the app is running
    When I tap {'Sessions'} text
    Then I see {'Session catalogue'} text
    And the catalogue lists {14} techniques
    And the catalogue lists {28} sessions
    And the technique {'rebond-bande'} comes before the technique {'rejet-naturel'}
    And the technique {'demi-bille'} lists {2} sessions
    And the technique {'quart'} lists {1} sessions
    And the technique {'retro'} lists {4} sessions
    And I see {'14 techniques · 28 sessions · read-only'} text

  Scenario: The group suggestion stays one tap away from the catalogue
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Group suggestion'} text
    Then I see {'Suggested session'} text

  Scenario: A session is read-only and shows its five phases in order
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then I see {'Quantité demi-bille, session 1/2'} text
    And I see {'Previous session: Quantité de bille pleine, session 2/2'} text
    And the phases appear in the order {'welcome,notionAndInitiation,training,game,review'}
    And the content cannot be edited
    And I see {'Read-only content: nothing can be edited here.'} text

  Scenario: The audience changes the minutes and the adult theory
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then I see {'90 min in total (approximate)'} text
    And the phase minutes add up to {90}
    And I do not see text containing {'For adults'}
    When I tap {'Adults · 120 min'} text
    Then I see {'120 min in total (approximate)'} text
    And the phase minutes add up to {120}
    And I see text containing {'For adults: Au trois-quarts'}

  Scenario: The outline jumps to the game and back
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Game'} text
    Then the phase {'game'} is on screen
    When I tap {'Recall'} text
    Then the phase {'welcome'} is on screen

  Scenario: The first session of the catalogue welcomes instead of recalling
    Given the app is running
    When I go to the address {'/catalogue/posture-1'}
    Then I see {'First session of the catalogue: welcome, no recall.'} text
    And I see {'Welcome · 10 min'} text

  Scenario: The content is announced as French under the English interface
    Given the app is running
    When I go to the address {'/catalogue'}
    Then I see {'The session content is written in French; only the interface is translated.'} text
    When I go to the address {'/catalogue/demi-bille-1'}
    Then I see {'The session content is written in French; only the interface is translated.'} text

  Scenario: The French interface shows no language notice
    Given the device language is {'fr'}
    And the app is running
    When I tap {'Séances'} text
    Then I see {'Catalogue de séances'} text
    And I do not see text containing {'seule l’interface est traduite'}
    And I see {'14 techniques · 28 séances · lecture seule'} text

  Scenario: A proposed exercise block is badged in the session
    Given the app is running
    When I go to the address {'/catalogue/posture-1'}
    Then the element {'exercise:e1'} is marked as a proposal
    And I see {'This target is a proposal, not a federal figure.'} text {2} times
    And the element {'theme'} is marked as a proposal

  Scenario: A federal game is sourced and its recall rule is a proposal
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then the element {'game'} is marked as sourced
    And the element {'exercise:e1'} is marked as sourced
    And the element {'link'} is marked as a proposal
    And I see text containing {'Game no. 7 of the federal sheets'}

  Scenario: An adapted game is a proposal to validate
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1'}
    Then the element {'game'} is marked as a proposal
    And I see text containing {'Game adapted from game no. 1: adaptation to validate.'}
    And I see text containing {'Playful variant:'}
    And I see text containing {'Recall rule'}

  Scenario: The filter keeps only the sessions to validate
    Given the session catalogue holds the fixture sessions
    And the app is running
    When I go to the address {'/catalogue'}
    Then the catalogue lists {4} sessions
    And the session {'posture-1'} is marked to validate
    And the session {'demi-bille-1'} is not marked to validate
    When I tap {'To validate only'} text
    Then the catalogue lists {2} sessions
    And the session {'quart-1'} is marked to validate
    And I do not see text containing {'Quantité demi-bille'}
    When I tap {'To validate only'} text
    Then the catalogue lists {4} sessions

  Scenario: Each session says what is to validate and the games have their own filter
    Given the session catalogue holds the fixture sessions
    And the app is running
    When I go to the address {'/catalogue'}
    Then the session {'posture-1'} shows the review reason {'exercise'}
    And the session {'quart-1'} shows the review reason {'game'}
    And the session {'demi-bille-1'} shows the review reason {'gameLink'}
    When I tap {'Games to validate'} text
    Then the catalogue lists {1} sessions
    And the session {'quart-1'} is marked to validate

  Scenario: On the real catalogue the filters tell the games from the rest
    Given the app is running
    When I go to the address {'/catalogue'}
    Then the catalogue lists {28} sessions
    When I tap {'Games to validate'} text
    Then the catalogue lists {11} sessions
    When I tap {'Games to validate'} text
    And I tap {'To validate only'} text
    Then the catalogue lists {18} sessions

  Scenario: An unknown session is a missing page
    Given the app is running
    When I go to the address {'/catalogue/unknown-9'}
    Then I see {'Page not found'} text
    When I go to the address {'/catalogue/Not_A_Slug'}
    Then I see {'Page not found'} text

  Scenario: A session opens from the catalogue and leads back to it
    Given the app is running
    When I tap {'Sessions'} text
    And I open the session {'demi-bille-2'} of the catalogue
    Then I see {'Quantité demi-bille, session 2/2'} text
    And I see {'Previous session: Quantité demi-bille, session 1/2'} text
    When I tap {'Session catalogue'} text
    Then the catalogue lists {28} sessions

  Scenario: The address preselects the audience
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1?audience=adults'}
    Then I see {'120 min in total (approximate)'} text

  Scenario: A session is reviewed without students nor planned session
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1'}
    Then the element {'exercise:e1'} is marked as a proposal
    And the element {'game'} is marked as a proposal
    And the element {'link'} is marked as a proposal
    And the element {'variant'} is marked as a proposal
    And the phases appear in the order {'welcome,notionAndInitiation,training,game,review'}
