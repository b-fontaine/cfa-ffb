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
    And I see {'14 techniques · 28 sessions'} text
    And I do not see text containing {'read-only'}

  Scenario: The button Group suggestion is gone and the Suggestion tab leads to the suggestion
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    Then I do not see {'Group suggestion'} text
    When I tap {'Suggestion'} text
    Then I see {'Suggested session'} text

  Scenario: A session shows its five phases in order and no read-only sentence
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then I see {'Quantité demi-bille, session 1/2'} text
    And I see {'Previous session: Quantité de bille pleine, session 2/2'} text
    And the phases appear in the order {'welcome,notionAndInitiation,training,game,review'}
    And the content cannot be edited
    And I do not see text containing {'Read-only'}
    And I do not see text containing {'Jump to'}

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

  Scenario: The phase timeline sits under the audience choice and leads to the phase
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then the phase timeline is shown below the text {'90 min in total (approximate)'}
    And the phase timeline is above the phase {'welcome'}
    When I tap the phase {4}
    Then the phase {'game'} is on screen
    When I tap the phase {1}
    Then the phase {'welcome'} is on screen

  Scenario: The minutes of the phase timeline follow the audience
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then the phase timeline minutes add up to {90}
    When I tap {'Adults · 120 min'} text
    Then the phase timeline minutes add up to {120}

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
    And I see {'14 techniques · 28 séances'} text
    And I do not see text containing {'lecture seule'}

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

  Scenario: Each session says in one badge what is to validate and the games have their own filter
    Given the session catalogue holds the fixture sessions
    And the app is running
    When I go to the address {'/catalogue'}
    Then the session {'posture-1'} shows the review badge {'1 point to validate'}
    And the review badge of {'posture-1'} explains {'Exercises to validate'}
    And the session {'quart-1'} shows the review badge {'1 point to validate'}
    And the review badge of {'quart-1'} explains {'Game to validate'}
    And the session {'demi-bille-1'} has no review badge
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

  # --- Lot U8 : catalogue en mode « Préparer » (R12, R13) ---

  Scenario: The title of a row is the evocative name of the session
    Given the app is running
    When I go to the address {'/catalogue'}
    Then the session {'demi-bille-1'} has the title {'Le partage du gâteau'} and the subtitle {'Session 1/2 · Quantité demi-bille'}
    And the session {'puissance-1'} has the title {'Les deux curseurs'} and the subtitle {'Session 1/2 · La puissance'}

  Scenario: The names of the rows are announced as proposals once, in the header
    Given the app is running
    When I go to the address {'/catalogue'}
    Then I see {'Evocative names are proposals, not federal wording.'} text

  Scenario: A session to validate carries one single badge with the number of points
    Given the app is running
    When I go to the address {'/catalogue'}
    Then the session {'posture-1'} shows the review badge {'2 points to validate'}
    And the session {'posture-1'} shows no source or proposal badge
    And the review badge of {'posture-1'} explains {'Exercises to validate'}
    And the review badge of {'posture-1'} explains {'Recall to validate'}
    And the session {'posture-2'} shows the review badge {'1 point to validate'}
    And the session {'demi-bille-1'} has no review badge

  Scenario: A session to validate also signals its minor proposals by their own neutral badge
    Given the app is running
    When I go to the address {'/catalogue'}
    Then the session {'posture-1'} shows the review badge {'2 points to validate'}
    And the session {'posture-1'} shows the review reason {'theory'}
    And the session {'posture-2'} shows the review badge {'1 point to validate'}
    And the session {'posture-2'} shows the review reason {'gameLink'}

  Scenario: The federal source badge leaves the list and stays in the detail
    Given the app is running
    When I go to the address {'/catalogue'}
    Then I do not see text containing {'Federal source'}
    When I go to the address {'/catalogue/demi-bille-1'}
    Then the element {'game'} is marked as sourced
    And the element {'exercise:e1'} is marked as sourced

  Scenario: The detail lists the points to validate by reason
    Given the app is running
    When I go to the address {'/catalogue/posture-1'}
    Then the review note of the session says {'2 points to validate'}
    And the review note of the session lists {'exercise,recall,theory'}

  Scenario: A session without point to validate has no badge and its proposals stay signalled in the detail
    Given the app is running
    When I go to the address {'/catalogue'}
    Then the session {'demi-bille-1'} has no review badge
    When I go to the address {'/catalogue/demi-bille-1'}
    Then the element {'link'} is marked as a proposal
    And the element {'theme'} is marked as a proposal
    And I do not see text containing {'points to validate'}
    And I do not see text containing {'1 point to validate'}

  Scenario: A session without point to validate still signals its minor proposal by a badge in the list
    Given the app is running
    When I go to the address {'/catalogue'}
    Then the session {'demi-bille-1'} has no review badge
    And the session {'demi-bille-1'} shows the review reason {'gameLink'}
    And the session {'demi-bille-1'} shows the minor badge {'Game link rule: proposal'}

  Scenario: The French interface titles the rows and counts the points in French
    Given the device language is {'fr'}
    And the app is running
    When I go to the address {'/catalogue'}
    Then the session {'posture-1'} shows the review badge {'2 points à valider'}
    And the session {'posture-2'} shows the review badge {'1 point à valider'}
    And the session {'demi-bille-1'} shows the minor badge {'Règle de lien du jeu : proposition'}
    And the session {'demi-bille-1'} has the title {'Le partage du gâteau'} and the subtitle {'Séance 1/2 · Quantité demi-bille'}
    And I see {'Les noms évocateurs sont des propositions, non des termes fédéraux.'} text

  Scenario: An empty catalogue says so
    Given the session catalogue is empty
    And the app is running
    When I go to the address {'/catalogue'}
    Then I see {'The catalogue holds no session.'} text
    And I see {'0 techniques · 0 sessions'} text

  Scenario: Without a group no row has a marker
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue'}
    Then no session is marked
    And I do not see text containing {'Recommended next'}

  Scenario: With a group the sessions given are ticked and the next recommended one is marked
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    Then the session {'posture-1'} is marked {'done'}
    And the session {'posture-2'} is marked {'next'}
    And the session {'puissance-1'} is marked {'upcoming'}
    And the catalogue marks {1} sessions as {'next'}
    And the catalogue marks {1} sessions as {'done'}
    And the catalogue marks {26} sessions as {'upcoming'}
    When I pick no group in the catalogue
    Then no session is marked

  Scenario: A session recorded without a pass or only planned is not given
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'}
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-19'} with the catalogue session {'posture-2'}
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    Then the catalogue marks {0} sessions as {'done'}
    And the session {'posture-1'} is marked {'next'}

  Scenario: A technique with several parts has one marker per part
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'retro-1'} and a pass
    And a session is recorded for the group {'Children group'} on {'2026-10-06'} with the catalogue session {'retro-2'} and a pass
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    Then the session {'retro-1'} is marked {'done'}
    And the session {'retro-2'} is marked {'done'}
    And the session {'retro-3'} is marked {'upcoming'}
    And the session {'retro-4'} is marked {'upcoming'}
    And the catalogue marks {1} sessions as {'next'}

  Scenario: Every part given, the proposed one stays recommended and the others are ticked
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
    And a session is recorded for the group {'Children group'} on {'2026-10-06'} with the catalogue session {'posture-2'} and a pass
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    Then the session {'posture-1'} is marked {'next'}
    And the session {'posture-2'} is marked {'done'}
    And the catalogue marks {1} sessions as {'next'}

  Scenario: The group chosen survives the opening of a session and the return
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    And I open the session {'posture-2'} of the catalogue
    Then the back button says {'Session catalogue'}
    When I tap the back button
    Then the group {'Children group'} is selected in the catalogue
    And the session {'posture-1'} is marked {'done'}
    And the session {'posture-2'} is marked {'next'}

  Scenario: The markers are announced by their label
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    Then the marker of {'posture-1'} is announced as {'Done'}
    And the marker of {'posture-2'} is announced as {'Recommended next'}
    And the marker of {'puissance-1'} is announced as {'Upcoming'}

  Scenario: The cards of an exercise stay on one column under 720 dp
    Given the screen is {719} by {1400}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then the exercise {'e1'} is laid out in {1} columns

  Scenario: The cards of an exercise go on two columns from 720 dp with the diagram on the left
    Given the screen is {720} by {1400}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then the exercise {'e1'} is laid out in {2} columns

  Scenario: Report a proposal copies the identifier of the session
    Given the clipboard is available
    And the app is running
    When I go to the address {'/catalogue/posture-1'}
    And I open the actions menu of the session
    And I tap {'Report a proposal'} text
    Then the clipboard holds {'Proposal to review: session posture-1 (Posture, visée et coup de queue, session 1/2)'}
    And I see {'Session identifier copied: posture-1'} text

  Scenario: Opened from the catalogue the session leads back to the catalogue
    Given the app is running
    When I tap {'Sessions'} text
    And I open the session {'demi-bille-2'} of the catalogue
    Then the back button says {'Session catalogue'}

  Scenario: Opened from the planner the session leads back to the planner
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1?from=planner'}
    Then the back button says {'Planning'}
    When I tap the back button
    Then I see {'Planning'} text

  Scenario: Opened from Today the session leads back to Today
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1?from=today'}
    Then the back button says {'Today'}
    When I tap the back button
    Then I see {'Plan the next session'} text

  Scenario: An unknown origin falls back on the catalogue
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1?from=evil'}
    Then the back button says {'Session catalogue'}

  Scenario: A deep link without origin is unchanged
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    Then the back button says {'Session catalogue'}
    When I tap the back button
    Then the catalogue lists {28} sessions

  Scenario: With an empty catalogue picking a group marks nothing
    Given the club has the student {'Léa'} in the {'children'} audience
    And the session catalogue is empty
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    Then no session is marked
    And the catalogue does not say the group has no student

  Scenario: A notion without a session of the catalogue recommends none
    Given the session catalogue holds the fixture sessions but {'posture-1'}
    And the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    Then the catalogue marks {0} sessions as {'next'}
    And the catalogue marks {0} sessions as {'done'}
    And the catalogue marks {3} sessions as {'upcoming'}
    And the catalogue does not say the group has no student

  Scenario: A group without student keeps its given sessions ticked and recommends none
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
    And the student {'Léa'} leaves the group {'Children group'} on {'2026-10-10'}
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    Then the catalogue says the group has no student
    And the session {'posture-1'} is marked {'done'}
    And the catalogue marks {0} sessions as {'next'}

  Scenario: Groups that cannot be read are reported without hiding the catalogue
    Given the groups cannot be read
    And the app is running
    When I go to the address {'/catalogue'}
    Then the catalogue shows the journey failure
