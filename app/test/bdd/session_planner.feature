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
    And I see {'Children · 90 min'} text

  Scenario: An adult session lasts 2h
    Given the app is running
    When I tap {'Plan a session'} text
    And I enter {'Position play'} into {0} input field
    And I tap {'Adults'} text
    And I tap {'Add session'} text
    Then I see {'Position play'} text
    And I see {'Adults · 120 min'} text

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
    And I see {'Children · 90 min'} text

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
    And I see {'Adults · 120 min'} text
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
    And I see {'Adults · 120 min'} text

  Scenario: An unknown catalogue session is shown as unavailable without error
    Given a session {'Old plan'} is planned with the catalogue session {'inconnue-9'}
    And the app is running
    When I tap {'Plan a session'} text
    Then I see {'Old plan'} text
    And I see {'Catalogue session unavailable'} text
    And I see {'Choose a session'} text
