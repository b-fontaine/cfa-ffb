# Parcours (d) : séance suggérée pour un groupe.
Feature: Suggested session screen

  Scenario: A children session lasts 90 minutes and is timed
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'90 min'} text
    And I see {'La puissance'} text
    And I see {'Welcome · 10 min'} text
    And I see {'Training · 35 min'} text
    And I see {'Game · 20 min'} text

  Scenario: An adults session lasts 120 minutes and may include a recall
    Given the club has the student {'Hugo'} in the {'adults'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'120 min'} text
    And I see {'Training · 50 min'} text

  # F7 : l'absence de rappel pour les enfants est voulue, l'écran l'explique.
  Scenario: A children session without recall explains that it is intended
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'No recall for this group.'} text
    And I see {'Children sessions cover a single notion: no recall is intended.'} text

  Scenario: An adults session without recall shows no children explanation
    Given the club has the student {'Hugo'} in the {'adults'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'No recall for this group.'} text
    And I do not see {'Children sessions cover a single notion: no recall is intended.'} text

  Scenario: Each exercise links to its source sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I open the source sheet of exercise {1}
    Then I see {'Technical sheet no. 2'} text
    And I see {'Required: 7 out of 9'} text

  # Lot 8 (ADR 0009) : la séance du catalogue proposée. Ces scénarios
  # dépendent de la présentation (C3) et du guide avec groupe (C4).
  Scenario: The suggestion proposes the first part of the catalogue session
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'Catalogue session'} text
    And I see {'Posture, visée et coup de queue'} text
    And I see {'Session 1/2'} text
    And I see {'Covers the lead exercise of the suggestion'} text

  Scenario: A part already given is not proposed again and the lead exercise is noted
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'A part still to do for this group'} text
    And I see {'Session 2/2'} text
    And I see text containing {'The lead exercise (no. 1) belongs to a part already given'}

  Scenario: Every part given, the part of the lead exercise is proposed again with its date
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
    And a session is recorded for the group {'Children group'} on {'2026-10-06'} with the catalogue session {'posture-2'} and a pass
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'Session 1/2'} text
    And I see {'Already given on Mon, Oct 5'} text

  Scenario: The catalogue session opens from the suggestion
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I tap {'Open the catalogue session'} text
    Then I see text containing {'Posture, visée et coup de queue'}
    And I see text containing {'session 1/2'}

  Scenario: The guided session launched from the suggestion knows the group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'adults'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Adults group'} text
    And I tap {'Suggest a session'} text
    And I tap {'Launch the guided session'} text
    And I go to the guide step {'Note the results'}
    And I tap {'Note the results'} text
    Then I see {'Record the results'} text
    And I see {'Hugo'} text
    And I do not see {'Léa'} text

  Scenario: The catalogue session is planned from the suggestion
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I tap {'Plan a session'} text
    Then the session title is {'Posture, visée et coup de queue, session 1/2'}

  Scenario: The record opened from the suggestion follows the catalogue session
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I tap {'Record the results of this session'} text
    And I tap {'Open the session'} text
    Then the opened session follows the catalogue session {'posture-1'}

  Scenario: A block without catalogue session explains it and keeps the actions
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Léa'} has validated the block {'puissance'}
    And {'Léa'} has validated the block {'bille-fantome'}
    And {'Léa'} has validated the block {'bille-pleine'}
    And {'Léa'} has validated the block {'demi-bille'}
    And {'Léa'} has validated the block {'trois-quarts'}
    And {'Léa'} has validated the block {'quart-finesses'}
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    Then I see {'No catalogue session for this notion: the block exercises are listed below'} text
    And I see {'Record the results of this session'} text
    And I see {'Plan a session'} text
    And I do not see {'Open the catalogue session'} text
    And I do not see {'Launch the guided session'} text

  Scenario: Planning without catalogue session opens the planner with no session chosen
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Léa'} has validated the block {'puissance'}
    And {'Léa'} has validated the block {'bille-fantome'}
    And {'Léa'} has validated the block {'bille-pleine'}
    And {'Léa'} has validated the block {'demi-bille'}
    And {'Léa'} has validated the block {'trois-quarts'}
    And {'Léa'} has validated the block {'quart-finesses'}
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I tap {'Plan a session'} text
    Then the session title is {''}
