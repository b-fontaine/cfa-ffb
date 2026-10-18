# Une séance planifiée a un groupe (ADR 0007 amendé) : de la revue, du détail
# d'une séance du catalogue et de la suggestion, le groupe connu arrive dans
# l'adresse du planificateur (`/planner?group=…`), où il est présélectionné.
Feature: Planner route

  Scenario: The detail of a catalogue session opens the planner with its group
    Given the club has the student {'Hugo'} in the {'adults'} audience
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Adults group'} in the catalogue
    And I open the session {'demi-bille-2'} of the catalogue
    And I tap {'Plan this session'} text
    Then the planner address carries the group {'Adults group'}

  Scenario: The suggestion opens the planner with its group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I tap {'Plan a session'} text
    Then the planner address carries the group {'Children group'}

  Scenario: The summary of a session opens the planner with its group
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And {'Léa'} has validated the block {'puissance'}
    And {'Léa'} has validated the block {'bille-fantome'}
    And {'Léa'} has validated the block {'bille-pleine'}
    And {'Léa'} has validated the block {'demi-bille'}
    And {'Léa'} has validated the block {'trois-quarts'}
    And {'Léa'} has validated the block {'quart-finesses'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    And the app is running
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    And I tap {'Open the planner'} text
    Then the planner address carries the group {'Children group'}
