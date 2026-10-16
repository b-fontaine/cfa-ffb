# Retours et sorties des écrans touchés par le catalogue de séances : chaque
# écran ramène là d'où il a été ouvert ; une adresse mal formée mène à une page
# introuvable qui ramène à l'accueil.
Feature: Leaving a screen

  Scenario: The date of the record is changed to the exact day chosen
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/record/new'}
    Then I see text containing {'Oct 12'}
    When I tap {'Change the date'} text
    And I pick the day {5} in the date picker
    Then I see text containing {'Oct 5'}
    And I do not see text containing {'Oct 12'}

  Scenario: The record opens on the date and the group of the guided session
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/record/new?main=demi-bille&exercise=1&date=2026-10-05&from=%2Fcatalogue%2Fdemi-bille-1%2Fguide%3Fstep%3D5'}
    Then I see text containing {'Oct 5'}
    And I see {'Back to the guided session'} text
    When I tap {'Back to the guided session'} text
    Then I see {'Step 6 of 10'} text

  Scenario: A record without a way back offers none and an unreadable date is ignored
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/record/new?date=pas-une-date'}
    Then I see text containing {'Oct 12'}
    And I do not see {'Back to the guided session'} text

  Scenario: A club without students sends the record to the students screen
    Given the app is running
    When I go to the address {'/record/new'}
    And I tap {'Add students'} text
    Then I see {'New student'} text
    When I tap the back button
    Then I see {'Club students'} text

  Scenario: A club without students sends the suggestion to the students screen
    Given the app is running
    When I go to the address {'/session'}
    And I tap {'Add students'} text
    Then I see {'New student'} text

  Scenario: The suggestion opens the record for its group and notion
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Group suggestion'} text
    And I tap {'Suggest a session'} text
    And I tap {'Record the results of this session'} text
    Then I see {'Record the results'} text
    When I tap {'Open the session'} text
    Then I see text containing {'Catalogue session:'}

  Scenario: An exercise sheet leads back to the suggestion
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'posture'}
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Group suggestion'} text
    And I tap {'Suggest a session'} text
    And I open the source sheet of exercise {1}
    And I tap the back button
    Then I see {'Suggested session'} text

  Scenario: A student sheet leads back to the students
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Students'} text
    And I tap {'Léa'} text
    And I tap {'Edit the first name'} text
    Then I see {'Edit student'} text
    When I tap the back button
    And I tap {'Maturity review'} text
    And I tap the back button
    And I tap the back button
    Then I see {'Club students'} text

  Scenario: The guide leads back to the session of the catalogue
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    And I tap the back button
    Then I see {'Launch'} text
    And I see {'Quantité demi-bille, session 1/2'} text

  Scenario: A session opened from the planner leads back to the planner
    Given the app is running
    And je planifie la séance {'Cours'} pour les {'adultes'} avec la séance du catalogue {'demi-bille-2'}
    When I tap {'Plan a session'} text
    And I tap {'Catalogue session: Quantité demi-bille, session 2/2'} text
    Then I see {'Launch'} text
    When I tap the back button
    Then I see {'Cours'} text
    And I see {'Planning'} text

  Scenario: A malformed session address is a missing page that leads home
    Given the app is running
    When I go to the address {'/catalogue/Not_A_Slug/guide'}
    Then I see {'Page not found'} text
    When I tap {'Back to home'} text
    Then I see {'Plan the next session'} text
    When I go to the address {'/catalogue/Not_A_Slug/presentation'}
    Then I see {'Page not found'} text
    When I tap {'Back to home'} text
    Then I see {'Plan the next session'} text

  Scenario: An unknown session is a missing page that leads home, on every screen
    Given the app is running
    When I go to the address {'/catalogue/unknown-9/presentation'}
    Then I see {'Page not found'} text
    When I tap {'Back to home'} text
    Then I see {'Plan the next session'} text
    When I go to the address {'/catalogue/unknown-9'}
    Then I see {'Page not found'} text
    When I tap {'Back to home'} text
    Then I see {'Plan the next session'} text
    When I go to the address {'/catalogue/unknown-9/guide'}
    Then I see {'Page not found'} text
    When I tap {'Back to home'} text
    Then I see {'Plan the next session'} text

  Scenario: A planned session can be deleted after confirmation
    Given the app is running
    And je planifie la séance {'Cours'} pour les {'adultes'} avec la séance du catalogue {'demi-bille-2'}
    When I tap {'Plan a session'} text
    Then I see {'Cours'} text
    When I delete the planned session {'Cours'}
    Then I see {'No session planned yet.'} text
