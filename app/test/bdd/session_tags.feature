# Lot 10b (reste), décision de l'animateur du 2026-10-17 : la note de jeu d'une
# séance est faite d'étiquettes prédéfinies, jamais de texte libre. Elles se
# choisissent à l'étape « Bilan » du guide (gardées avec la séance en cours),
# passent à la saisie à « Terminer » et se corrigent depuis le bilan de la
# séance. « Aujourd'hui » est le lundi 12 octobre 2026.
Feature: Session tags

  Scenario: The review step offers a closed list of labels and no text field
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=99'}
    Then the session tags offered are {'Game enjoyed,Instructions to rephrase,Too long,Too short,Too hard,Too easy,To do again,Not enough equipment'}
    And I see no free text field
    And the session tag {'Too long'} is not selected

  Scenario: Several labels can be picked and one can be dropped
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=99'}
    And I tap {'Too long'} text
    And I tap {'To do again'} text
    Then the session tag {'Too long'} is selected
    And the session tag {'To do again'} is selected
    When I tap {'Too long'} text
    Then the session tag {'Too long'} is not selected
    And the session tag {'To do again'} is selected

  Scenario: The labels survive a relaunch of the app
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=99'}
    And I tap {'Game enjoyed'} text
    And I relaunch the app
    And I resume the session in progress
    Then the session tag {'Game enjoyed'} is selected
    And the session tag {'Too long'} is not selected

  Scenario: Without a results sheet open the guide says the labels are not kept
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=99'}
    Then I see {'No results sheet is open from this guide: these labels will not be kept when the session ends.'} text

  Scenario: Ending the session with a results sheet open gives the labels to the summary
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    And I tap {'Open the session'} text
    And I add {4} balls potted for {'Léa'}
    And I record the pass of {'Léa'}
    And I tap {'Back to the guided session'} text
    And I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=99'}
    And I tap {'Too long'} text
    And I tap {'Instructions to rephrase'} text
    And I end the guided session
    And I tap {'Confirm'} text
    Then I see {'Session summary'} text
    And the session tag {'Too long'} is selected
    And the session tag {'Instructions to rephrase'} is selected
    And the session tag {'Game enjoyed'} is not selected

  Scenario: Ending the session without a results sheet forgets the labels
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=99'}
    And I tap {'Too long'} text
    And I end the guided session
    And I tap {'Confirm'} text
    And I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=99'}
    Then the session tag {'Too long'} is not selected

  Scenario: The labels are corrected from the summary and kept
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'} and a pass
    When I open the summary of the session of the group {'Children group'} on {'2026-10-12'}
    Then the session tag {'To do again'} is not selected
    When I tap {'To do again'} text
    And I reload the page
    Then the session tag {'To do again'} is selected
    When I tap {'To do again'} text
    And I reload the page
    Then the session tag {'To do again'} is not selected
