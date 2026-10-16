# U4 (lot 1/2) : modes du guide. « Mener » pour une séance planifiée ou la
# séance suggérée, « Relecture » sans séance planifiée (décision Q4). Les
# scénarios vérifient ce que l'animateur voit : la case « Mode relecture » du
# menu ⋮ et les badges de provenance de l'étape (les sections repliées sont
# dans session_guide.feature). Le détail des paramètres d'adresse est dans
# shell_routes_test (AppRoutes.guide) et, pour l'omission du mode par défaut,
# dans run_sheet_cubit_test (routeMode).
Feature: Guide modes

  Scenario: A guide opened without a planned session is in review mode
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    And I go to the guide step {'Note the results'}
    Then the guide is in {'review'} mode
    And I see {4} provenance badges and {3} proposal badges

  Scenario: A guide launched from a detail is in review mode
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Launch'} text
    And I go to the guide step {'Note the results'}
    Then the guide is in {'review'} mode
    And I see {4} provenance badges and {3} proposal badges

  Scenario: A guide launched from a planned session is in lead mode
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    And I go to the guide step {'Note the results'}
    Then the guide is in {'lead'} mode
    And the provenance badges are {'hidden'}

  Scenario: A guide launched from the suggestion is in lead mode
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I tap {'Launch the guided session'} text
    And I go to the guide step {'Note the results'}
    Then the guide is in {'lead'} mode
    And the provenance badges are {'hidden'}

  Scenario: A shared link to the lead mode opens the guide in lead mode and keeps it through Next
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?mode=lead'}
    And I tap {'Next'} text
    Then the guide is in {'lead'} mode
    And the provenance badges are {'hidden'}

  Scenario: The lead mode is kept after a reload of the guide
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?mode=lead'}
    And I tap {'Next'} text
    And I reload the guide
    Then the guide is in {'lead'} mode

  Scenario: The default mode is kept after a reload of the guide
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    And I tap {'Next'} text
    And I reload the guide
    Then the guide is in {'review'} mode

  Scenario: A mode kept by the guide survives a resume from Today
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5&mode=lead'}
    And I count {2} successes on the initiation
    And I go to the address {'/'}
    And I tap {'Resume at step 6'} text
    Then the guide is in {'lead'} mode
    And the provenance badges are {'hidden'}
