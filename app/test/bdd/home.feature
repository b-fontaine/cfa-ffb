# Lot U7 : l'accueil « Aujourd'hui » rassemble ce que l'animateur doit savoir à
# l'ouverture : séance en cours, prochaine séance, alertes, semaine. Le rappel
# de sauvegarde du lot U6 reste posé au-dessus des cartes.
Feature: Today home

  Scenario: Without any student or session, the home offers to plan, to see the suggestion and to add students
    Given the app is running
    Then I see {'Today · Mon, Oct 12'} text
    And I see {'Plan the next session'} text
    And I see {'See the suggestion'} text
    And I see {'Add a student'} text
    And I see {'Nobody needs watching'} text

  Scenario: With students and no planned session, the home keeps the plan and suggestion actions
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    Then I see {'Plan the next session'} text
    And I see {'See the suggestion'} text
    And I do not see {'Add a student'} text
    And I see {'No pass entered in the last 7 days'} text

  Scenario: The suggestion opens from the home
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'See the suggestion'} text
    Then I see {'Suggest a session'} text

  Scenario: The next planned session is shown with its date, group, Prepare and Launch
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    Then I see {'Next'} text
    And I see {'Cours'} text
    And I see {'Wed, Oct 14 · Children group · Children · 90 min'} text
    And I see {'Prepare'} text
    And I see {'Launch'} text
    And I do not see {'Plan the next session'} text

  Scenario: A session planned for today without results is the next session
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    And the app is running
    Then I see {'Next'} text
    And I see {'Cours'} text

  Scenario: A session planned for today with results already recorded is not proposed
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    And the app is running
    Then I do not see {'Cours'} text
    And I see {'Plan the next session'} text

  Scenario: Only the first session of a day is shown, with the count of the others
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And a session {'Atelier'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-2'}
    And the app is running
    Then I see {'Cours'} text
    And I do not see {'Atelier'} text
    And I see {'+ 1 other session that day'} text

  Scenario: A past planned session without results in the last seven days is offered to be noted
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-08'} with the catalogue session {'posture-1'}
    And the app is running
    Then I see {'To note'} text
    And I see {'Cours · Thu, Oct 8'} text
    And I see {'Note the results'} text
    When I tap {'Note the results'} text
    Then I see {'Record the results'} text

  Scenario: A planned session without a catalogue session is opened in Planned
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} without a catalogue session
    And the app is running
    Then I see {'Open in Planned'} text
    And I do not see {'Launch'} text
    And I do not see {'Prepare'} text
    When I tap {'Open in Planned'} text
    Then I see {'Planning'} text

  Scenario: Launch from the home opens the guide of the planned session
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    Then I see {'Step 1 of 10'} text
    And I see {'Children · 90 min'} text

  Scenario: Prepare from the home opens the catalogue session
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Prepare'} text
    Then I see text containing {'Posture, visée et coup de queue'}

  Scenario: A started guided session is shown with its step and Resume
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/'}
    Then I see {'In progress'} text
    And I see {'Posture, visée et coup de queue, session 1/2'} text
    And I see {'Step 6 of 10'} text
    And I see {'Resume at step 6'} text

  Scenario: Resume reopens the guide at the saved step with its counters
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/'}
    And I tap {'Resume at step 6'} text
    Then I see {'Step 6 of 10'} text
    And I see {'2 of 4 successes'} text

  Scenario: A guide without any progress is not in progress
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=0'}
    And I go to the address {'/'}
    Then I do not see {'In progress'} text

  Scenario: A started session and the next session are both shown
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-2'}
    And the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/'}
    Then I see {'In progress'} text
    And I see {'Next'} text

  Scenario: A started session can be abandoned after a confirmation
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/'}
    And I tap {'Abandon'} text
    Then I see {'Abandon this session?'} text
    When I tap {'Cancel'} text
    Then I see {'In progress'} text
    When I tap {'Abandon'} text
    And I tap {'Confirm'} text
    Then I do not see {'In progress'} text

  Scenario: A student with an active alert is listed with the exercise and the failures
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'posture 1'}
    And the app is running
    Then I see {'To watch'} text
    And I see {'Léa'} text
    And I see text containing {'Posture, visée et coup de queue · exercise 1 · Proposal · 3 failures in a row'}

  Scenario: Persistent alerts come before attention alerts
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'posture 1'}
    And {'Hugo'} has {5} failed passes on {'posture 1'}
    And the app is running
    Then {'Hugo'} is shown above {'Léa'}
    And I see {'Action needed'} text

  Scenario: At most five students are listed, with a link to all of them
    Given the club has the student {'Anna'} in the {'children'} audience
    And the club has the student {'Bob'} in the {'children'} audience
    And the club has the student {'Chloé'} in the {'children'} audience
    And the club has the student {'Dan'} in the {'children'} audience
    And the club has the student {'Emma'} in the {'children'} audience
    And the club has the student {'Fred'} in the {'children'} audience
    And {'Anna'} has {3} failed passes on {'posture 1'}
    And {'Bob'} has {3} failed passes on {'posture 1'}
    And {'Chloé'} has {3} failed passes on {'posture 1'}
    And {'Dan'} has {3} failed passes on {'posture 1'}
    And {'Emma'} has {3} failed passes on {'posture 1'}
    And {'Fred'} has {3} failed passes on {'posture 1'}
    And the app is running
    Then I see {'Anna'} text
    And I see {'Emma'} text
    And I do not see {'Fred'} text
    And I see {'See all students (6)'} text
    When I tap {'See all students (6)'} text
    Then I see {'Club students'} text

  Scenario: A validated exercise never shows an alert
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'posture 1'}
    And {'Léa'} has {5} successful passes on {'posture 1'}
    And the app is running
    Then I see {'Nobody needs watching'} text

  Scenario: A listed student opens the student sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {3} failed passes on {'posture 1'}
    And the app is running
    When I tap {'Léa'} text
    Then I see {'Léa'} text
    And I do not see {'To watch'} text

  Scenario: The last seven days count passes and sessions given
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-10'} with the catalogue session {'posture-1'} and a pass
    And the app is running
    Then I see {'Last 7 days'} text
    And I see {'1 pass entered'} text
    And I see {'0 exercises validated'} text
    And I see {'1 session given'} text

  Scenario: A pass eight days old is not counted
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-04'} with the catalogue session {'posture-1'} and a pass
    And the app is running
    Then I see {'No pass entered in the last 7 days'} text

  Scenario: The backup reminder is kept above the cards
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    Then I see {'Back up now'} text
    And I see {'Plan the next session'} text
    And {'Back up now'} is shown above {'Plan the next session'}

  Scenario: The home is French on a French device
    Given the device language is {'fr'}
    And the app is running
    Then I see text containing {'· lun. 12 oct.'}
    And I see {'Planifier la prochaine séance'} text
    And I see {'Voir la suggestion'} text
    And I see {'Aucun élève à surveiller'} text

  Scenario: Every button of the home is at least 48 dp high
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    Then the buttons are at least {48} dp high
