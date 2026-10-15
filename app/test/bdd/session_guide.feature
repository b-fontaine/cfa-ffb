# Parcours (L6, ADR 0004) : suivre une séance du catalogue en séance guidée,
# la montrer aux élèves, noter les résultats et relire les propositions.
Feature: Guided session

  The instructor launches a catalogue session, follows its phases step by
  step, shows the diagrams to the students, notes the results and can read the
  whole session, without students, to validate the proposals in context.

  Scenario: Launching a session opens the welcome step with the recall
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Launch'} text
    Then I see {'Step 1 of 10'} text
    And I see {'Welcome · 10 min'} text
    And I see {'Previous session: Quantité de bille pleine, session 2/2'} text
    And I see text containing {'Flash question:'}
    And I see {'Children · 90 min'} text

  Scenario: The notion step follows the welcome and shows the illustration
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Launch'} text
    And I tap {'Next'} text
    Then I see {'Step 2 of 10'} text
    And I see {'Notion and initiation · 20 min'} text
    And I see {'Viser la moitié de la bille'} text
    And I see text containing {'Demi-bille : la blanche, un peu plus petite, couvre la moitié de la bille de couleur ; le procédé vise le centre de la blanche.'}
    And the element {'theory:tangente'} is marked as sourced

  Scenario: An exercise shows its diagram, set-up, instruction and expected result
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    Then I see {'Step 6 of 10'} text
    And the phase {'training'} is on screen
    And I see {'Exercise 1 · Les six parts de gâteau'} text
    And I see {'Exercise 1 of 2'} text
    And I see text containing {'Target:'}
    And the set-up diagram of the exercise {1} is shown
    And I see text containing {'Set-up: La rouge du schéma sous la poche du milieu'}
    And I see text containing {'Instruction: Empocher la rouge en demi-bille'}
    And I see text containing {'Expected: Le contact reste en demi à toute distance'}
    And I see {'Frequent mistakes (instructor)'} text
    And the element {'exercise:e1'} is marked as sourced
    And the element {'playful:e1'} is marked as a proposal

  Scenario: The training ends with a recall exercise taken from the previous sessions
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=7'}
    Then I see {'Step 8 of 10'} text
    And the phase {'training'} is on screen
    And I see {'Recall · Exercise 4 · Le X vers les poches du milieu'} text
    And I see {'From Quantité de bille pleine, session 2/2'} text
    And I see {'No student followed: the last exercise of the previous session is proposed.'} text
    And the set-up diagram of the exercise {4} is shown
    And the element {'minutes'} is marked as a proposal

  Scenario: The recall exercise is the one the most students have not validated
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has validated the block {'bille-pleine'}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=7'}
    Then I see {'Recall · Exercise 2 · La fantôme imaginée'} text
    And I see {'From Viser pour empocher (bille fantôme), session 1/1'} text
    And I see {'1 student of 1 has not validated it yet.'} text
    When I tap {'Note the results'} text
    And I tap {'Open the session'} text
    Then the exercise {'bille-fantome 2'} is selected for the record

  Scenario: The first session has no recall exercise
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children'}
    Then the guide goes through the phases {'welcome,notionAndInitiation,training,game,review'}
    And I do not see text containing {'Recall · Exercise'}

  Scenario: Showing the diagram opens the presentation and closing it comes back
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=adults&step=5'}
    And I tap {'Show'} text
    Then the presentation is open
    And the set-up diagram of the exercise {1} is shown
    And I do not see text containing {'Set-up:'}
    And I do not see {'Note the results'} text
    When I tap {'Close'} text
    Then I see {'Step 6 of 10'} text
    And I see {'Adults · 120 min'} text

  Scenario Outline: The presentation fits the figure, its controls and its caption on one screen
    Given the screen is {<width>} by {<height>}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=<step>'}
    Then the presentation is open
    And the figure, its controls and its caption are above the navigation bar

    Examples:
      | width | height | step |
      | 1280  | 800    | 5    |
      | 1280  | 800    | 6    |
      | 1280  | 800    | 7    |
      | 1280  | 800    | 8    |

  Scenario: The presentation can be opened directly for an audience
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=1'}
    Then the presentation is open
    And I see text containing {'Demi-bille : la blanche, un peu plus petite, couvre la moitié de la bille de couleur ; le procédé vise le centre de la blanche.'}

  Scenario: An initiation is counted locally and is not recorded
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {3} successes on the initiation
    Then I see {'3 of 4 successes'} text
    And I see text containing {'Not recorded'}

  Scenario: Noting the results opens the record on the exercise and comes back with the counters
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=4'}
    And I count {2} successes on the initiation
    And I tap {'Next'} text
    And I tap {'Note the results'} text
    Then I see {'Record the results'} text
    When I tap {'Open the session'} text
    Then I see text containing {'Catalogue session: Quantité demi-bille, session 1/2'}
    And the exercise {'demi-bille 1'} is selected for the record
    When I tap {'Back to the guided session'} text
    Then I see {'Step 6 of 10'} text
    When I tap {'Previous'} text
    Then I see {'2 of 2 successes'} text

  Scenario: The record offers to go back to the guide before opening a session
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    Then I see {'Back to the guided session'} text
    When I tap {'Back to the guided session'} text
    Then I see {'Step 6 of 10'} text

  Scenario: An outside return address is ignored by the record
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/record/new?main=posture&exercise=2&from=https://example.org/page'}
    Then I do not see {'Back to the guided session'} text
    When I tap {'Open the session'} text
    Then the exercise {'posture 2'} is selected for the record
    And I do not see {'Back to the guided session'} text

  Scenario: A return address outside the catalogue is ignored by the record
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/record/new?main=posture&from=/backup'}
    Then I do not see {'Back to the guided session'} text

  Scenario: The second exercise is the one preselected for the record
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=6'}
    And I tap {'Note the results'} text
    And I tap {'Open the session'} text
    Then the exercise {'demi-bille 2'} is selected for the record

  Scenario: The record takes the previous different block as the recall
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-2/guide?audience=children&step=6'}
    And I tap {'Note the results'} text
    And I tap {'Open the session'} text
    Then the opened session has the main block {'demi-bille'} and the recall block {'bille-pleine'}

  Scenario: The first session has no recall block for the record
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=6'}
    And I tap {'Note the results'} text
    And I tap {'Open the session'} text
    Then the opened session has the main block {'posture'} and no recall block

  Scenario: An exercise of a proposed block is badged and noted on its block
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=6'}
    Then the element {'exercise:e1'} is marked as a proposal
    And I see {'This target is a proposal, not a federal figure.'} text
    When I tap {'Note the results'} text
    And I tap {'Open the session'} text
    Then the exercise {'posture 1'} is selected for the record

  Scenario: The first session welcomes instead of recalling
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide'}
    Then I see {'Step 1 of 10'} text
    And I see {'First session of the catalogue: welcome, no recall.'} text
    And I see {'Welcome · 10 min'} text
    And I do not see text containing {'Previous session:'}

  Scenario: The five phases are walked through in order
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    Then the guide goes through the phases {'welcome,notionAndInitiation,training,game,review'}

  Scenario: Previous goes back and the outline jumps to the game
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    And I tap {'Next'} text
    And I tap {'Next'} text
    And I tap {'Previous'} text
    Then I see {'Step 2 of 10'} text
    When I tap {'Outline'} text
    And I tap {'8 billes dans une poche'} text
    Then I see {'Step 9 of 10'} text
    And the phase {'game'} is on screen
    When I tap {'Previous'} text
    Then I see {'Step 8 of 10'} text

  Scenario: A proposed game is read in context with its badges
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1/guide?audience=children&step=8'}
    Then the element {'game'} is marked as a proposal
    And the element {'link'} is marked as a proposal
    And the element {'variant'} is marked as a proposal
    And the element {'minutes'} is marked as a proposal
    And I see text containing {'adaptation to validate'}

  Scenario: The presentation keeps the badge on the illustration of a proposal
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1/presentation?audience=children&step=8'}
    Then the presentation is open
    And the illustration is marked as a proposal

  Scenario: A federal game is shown without proposal badge on its illustration
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/presentation?audience=children&step=8'}
    Then the presentation is open
    And the illustration is not marked as a proposal

  Scenario: A session is read from start to end without students
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1'}
    And I tap {'Launch'} text
    Then the guide goes through the phases {'welcome,notionAndInitiation,training,game,review'}
    When I tap {'End session'} text
    And I tap {'Confirm'} text
    Then I see {'Viser pour empocher (bille fantôme), session 1/1'} text
    And nothing is recorded

  Scenario: Ending the session resets what was counted
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I tap {'End session'} text
    And I tap {'Confirm'} text
    And I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    Then I see {'0 of 4 successes'} text

  Scenario: Ending the session asks for confirmation and keeps everything when cancelled
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I tap {'End session'} text
    Then I see {'End the guided session?'} text
    When I tap {'Cancel'} text
    Then I see {'2 of 4 successes'} text
    And I see {'Step 6 of 10'} text

  Scenario: Launching again a started session offers to resume it or to start over
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/catalogue/posture-1'}
    And I tap {'Launch'} text
    Then I see {'This session is already under way: step 6 of 10.'} text
    When I tap {'Resume at step 6'} text
    Then I see {'Step 6 of 10'} text
    And I see {'2 of 4 successes'} text
    And I do not see text containing {'already under way'}
    When I go to the address {'/catalogue/posture-1'}
    And I tap {'Launch'} text
    And I tap {'Start over'} text
    Then I see {'Step 1 of 10'} text
    And I do not see text containing {'already under way'}

  Scenario: A planned session leads back to the planner when it ends
    Given the app is running
    And je planifie la séance {'Cours'} pour les {'adultes'} avec la séance du catalogue {'demi-bille-2'}
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    And I tap {'End session'} text
    And I tap {'Confirm'} text
    Then I see {'Planning'} text
    And I see {'Cours'} text

  Scenario: A planned session keeps its counters and audience through the presentation
    Given the app is running
    And je planifie la séance {'Cours'} pour les {'adultes'} avec la séance du catalogue {'demi-bille-2'}
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    And I tap {'Outline'} text
    And I tap {'Près puis loin'} text
    And I count {2} successes on the initiation
    And I tap {'Show'} text
    Then the presentation is open
    When I tap {'Close'} text
    Then I see {'2 of 2 successes'} text
    And I see {'Adults · 120 min'} text
    And I see {'Step 7 of 12'} text

  Scenario: The playful theme and the notion are read in the guide with their badge
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1/guide?audience=children'}
    Then I see {'Theme: Le chasseur de fantômes'} text
    And the element {'theme'} is marked as a proposal
    When I tap {'Theme: Le chasseur de fantômes'} text
    Then I see text containing {'Notion:'}

  Scenario: An unreadable diagram library says so in the guide
    Given the diagram library cannot be read
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    Then I see {'This exercise diagram is invalid and cannot be displayed.'} text
    And I see text containing {'Set-up:'}
    And I do not see the billiard table

  Scenario: The group and the absentees chosen for one exercise are kept for the next
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    And I tap {'Hugo'} text
    And I tap {'Open the session'} text
    And I tap {'Back to the guided session'} text
    And I tap {'Next'} text
    And I tap {'Note the results'} text
    Then the student {'Hugo'} is marked absent in the roster
    And the student {'Léa'} is marked present in the roster

  Scenario: A planned session launches with its audience
    Given the app is running
    And je planifie la séance {'Cours'} pour les {'adultes'} avec la séance du catalogue {'demi-bille-2'}
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    Then I see {'Adults · 120 min'} text
    And I see {'Step 1 of 12'} text

  Scenario: An unknown session is a missing page and the step is clamped
    Given the app is running
    When I go to the address {'/catalogue/unknown-9/guide'}
    Then I see {'Page not found'} text
    When I go to the address {'/catalogue/demi-bille-1/guide?step=99'}
    Then I see {'Step 10 of 10'} text

  Scenario: The French interface labels the guide in French
    Given the device language is {'fr'}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    Then I see {'Étape 1 sur 10'} text
    And I see {'Suivant'} text
    And I see {'Montrer'} text

  # Lancer une séance planifiée pour un groupe pré-remplit la saisie (ADR 0007).
  Scenario: Launching a planned session prefills the record with its group and date
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'adults'} audience
    And a session {'Cours'} is planned for the group {'Adults group'} on {'2026-10-19'} with the catalogue session {'demi-bille-1'}
    And the app is running
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    Then I see {'Adults · 120 min'} text
    When I tap {'Next'} text
    And I tap {'Next'} text
    And I tap {'Next'} text
    And I tap {'Next'} text
    And I tap {'Next'} text
    And I tap {'Note the results'} text
    Then I see {'Record the results'} text
    And I see {'Mon, Oct 19'} text
    And I see {'Hugo'} text
    And I do not see {'Léa'} text
    When I tap {'Open the session'} text
    Then I see {'Adults group · Catalogue session: Quantité demi-bille, session 1/2'} text
    And the opened session has the main block {'demi-bille'} and the recall block {'bille-pleine'}
