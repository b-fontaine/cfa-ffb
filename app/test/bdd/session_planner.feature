Feature: Session planner

  Scenario: Nothing is planned at first
    Given the app is running
    When I tap {'Plan a session'} text
    Then I see {'No session planned yet.'} text

  Scenario: A children session lasts 1h30
    Given the app is running
    When I tap {'Plan a session'} text
    And I enter {'Posture basics'} into {0} input field
    And I tap {'Add session'} text
    Then I see {'Posture basics'} text
    And I see {'Mon, Oct 12 · Children · 90 min'} text

  Scenario: An adult session lasts 2h
    Given the app is running
    When I tap {'Plan a session'} text
    And I enter {'Position play'} into {0} input field
    And I tap {'Adults'} text
    And I tap {'Add session'} text
    Then I see {'Position play'} text
    And I see {'Mon, Oct 12 · Adults · 120 min'} text

  Scenario: A session needs a title
    Given the app is running
    When I tap {'Plan a session'} text
    And I tap {'Add session'} text
    Then I see {'The session title is required.'} text

  # Lien séance planifiée <-> séance du catalogue (L5, ADR 0004).
  Scenario: A catalogue session prefills the title and is kept with the session
    Given the app is running
    When I tap {'Plan a session'} text
    And I choose the catalogue session {'puissance-1'}
    Then the session title is {'La puissance, session 1/2'}
    When I tap {'Add session'} text
    Then I see {'La puissance, session 1/2'} text
    And I see {'Catalogue session: La puissance, session 1/2'} text
    And I see {'Mon, Oct 12 · Children · 90 min'} text

  Scenario: The prefilled title stays editable
    Given the app is running
    When I tap {'Plan a session'} text
    And I choose the catalogue session {'puissance-1'}
    And I enter {'Les bases de la puissance'} into {0} input field
    And I tap {'Add session'} text
    Then I see {'Les bases de la puissance'} text
    And I see {'Catalogue session: La puissance, session 1/2'} text

  Scenario: A session without catalogue session offers to choose one
    Given the app is running
    When I tap {'Plan a session'} text
    And I enter {'Posture basics'} into {0} input field
    And I tap {'Add session'} text
    Then I see {'Posture basics'} text
    And I see {'Choose a session'} text
    When I tap {'Choose a session'} text
    Then I see {'Session catalogue'} text

  Scenario: The second session of a technique is planned and opens its detail
    Given the app is running
    When I tap {'Plan a session'} text
    And I choose the catalogue session {'demi-bille-2'}
    And I tap {'Adults'} text
    And I tap {'Add session'} text
    Then I see {'Quantité demi-bille, session 2/2'} text
    And I see {'Catalogue session: Quantité demi-bille, session 2/2'} text
    And I see {'Mon, Oct 12 · Adults · 120 min'} text
    When I tap {'Catalogue session: Quantité demi-bille, session 2/2'} text
    Then I see {'Previous session: Quantité demi-bille, session 1/2'} text

  Scenario: A catalogue session is planned from its detail
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-2'}
    And I tap {'Adults · 120 min'} text
    And I tap {'Plan this session'} text
    Then the session title is {'Quantité demi-bille, session 2/2'}
    When I tap {'Add session'} text
    Then I see {'Catalogue session: Quantité demi-bille, session 2/2'} text
    And I see {'Mon, Oct 12 · Adults · 120 min'} text

  # U4 (lot 2, U-9) : « Planifier cette séance » emporte le groupe du catalogue.
  Scenario: Plan this session from the detail keeps the group chosen in the catalogue
    Given the club has the student {'Hugo'} in the {'adults'} audience
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Adults group'} in the catalogue
    And I open the session {'demi-bille-2'} of the catalogue
    And I tap {'Plan this session'} text
    Then the session title is {'Quantité demi-bille, session 2/2'}
    When I tap {'Add session'} text
    Then I see {'Mon, Oct 12 · Adults group · Adults · 120 min'} text

  Scenario: An unknown catalogue session is shown as unavailable without error
    Given a session {'Old plan'} is planned with the catalogue session {'inconnue-9'}
    And the app is running
    When I tap {'Plan a session'} text
    Then I see {'Old plan'} text
    And I see {'Catalogue session unavailable'} text
    And I see {'Choose a session'} text

  # Date et groupe sur la séance planifiée, lien avec la saisie (ADR 0007).
  # « Aujourd'hui » des scénarios : lundi 12 octobre 2026.
  Scenario: A planned session has a date and a group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Plan a session'} text
    And I enter {'Posture basics'} into {0} input field
    And I choose the group {'Children group'}
    And I tap {'Add session'} text
    Then I see {'Mon, Oct 12 · Children group · Children · 90 min'} text
    And I see {'Note the results'} text

  Scenario: Choosing a group sets the audience of the session
    Given the club has the student {'Hugo'} in the {'adults'} audience
    And the app is running
    When I tap {'Plan a session'} text
    And I enter {'Position play'} into {0} input field
    And I choose the group {'Adults group'}
    And I tap {'Add session'} text
    Then I see {'Mon, Oct 12 · Adults group · Adults · 120 min'} text

  Scenario: Planned sessions are listed by date
    Given the app is running
    When I tap {'Plan a session'} text
    And I enter {'Later'} into {0} input field
    And I move the session date to day {19}
    And I tap {'Add session'} text
    And I enter {'Sooner'} into {0} input field
    And I move the session date to day {12}
    And I tap {'Add session'} text
    Then the planned session {'Sooner'} is listed before {'Later'}
    And I see {'Mon, Oct 12 · Children · 90 min'} text
    And I see {'Mon, Oct 19 · Children · 90 min'} text

  Scenario: Noting the results of a planned session opens a record that knows its catalogue session
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Plan a session'} text
    And I choose the catalogue session {'puissance-1'}
    And I choose the group {'Children group'}
    And I tap {'Add session'} text
    And I tap {'Note the results'} text
    Then I see {'Record the results'} text
    And I see {'Mon, Oct 12'} text
    When I tap {'Open the session'} text
    Then I see {'Children group · Catalogue session: La puissance, session 1/2'} text
    And the opened session has the main block {'puissance'} and the recall block {'posture'}
    When I tap {'Today'} text
    And I tap {'Plan a session'} text
    Then I see {'Results recorded'} text
    And I do not see {'Note the results'} text

  Scenario: A planned session already recorded opens its record
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'puissance-1'}
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'puissance-1'}
    And the app is running
    When I tap {'Plan a session'} text
    Then I see {'Mon, Oct 5 · Children group · Children · 90 min'} text
    And I see {'Results recorded'} text
    When I tap {'Results recorded'} text
    Then I see {'Session of Mon, Oct 5'} text
    And I see {'Children group · Catalogue session: La puissance, session 1/2'} text

  # D1 (ADR 0016) : une saisie est identifiée par (groupe, jour, séance du
  # catalogue). Une autre séance du catalogue le même jour ne la « saisit » pas.
  Scenario: A planned session offers to note the results although another catalogue session was recorded the same day
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-2'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Plan a session'} text
    Then I see {'Note the results'} text
    And I do not see {'Results recorded'} text

  Scenario: Noting the second session of the day opens a second record and keeps the first
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-2'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Plan a session'} text
    And I tap {'Note the results'} text
    And I tap {'Open the session'} text
    Then the group {'Children group'} has {2} recorded sessions on {'2026-10-12'}
    And the group {'Children group'} has a recorded session with the catalogue session {'posture-1'} on {'2026-10-12'}
    And the group {'Children group'} has a recorded session with the catalogue session {'posture-2'} on {'2026-10-12'}
    When I tap {'Today'} text
    And I tap {'Plan a session'} text
    Then I see {'Results recorded'} text
    And I do not see {'Note the results'} text

  Scenario: A record without catalogue session is taken for the planned session of the day
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} without a catalogue session
    And the app is running
    When I tap {'Plan a session'} text
    Then I see {'Results recorded'} text
    And I do not see {'Note the results'} text

  Scenario: Deleting a planned session keeps its record
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'puissance-1'}
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'puissance-1'}
    And the app is running
    When I tap {'Plan a session'} text
    And I delete the planned session {'Cours'}
    Then I see {'No session planned yet.'} text
    And the group {'Children group'} has a recorded session with the catalogue session {'puissance-1'} on {'2026-10-05'}
