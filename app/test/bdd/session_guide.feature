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
    Then I see the guide at step {1} of {10}
    And I see {'Welcome · 10 min'} text
    And I see {'Previous session: Quantité de bille pleine, session 2/2'} text
    And I see text containing {'Flash question:'}
    And I see the session audience {'Children · 90 min'}

  Scenario: The notion step follows the welcome and shows the illustration
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Launch'} text
    And I tap {'Next'} text
    Then I see the guide at step {2} of {10}
    And I see {'Notion and initiation · 20 min'} text
    And I see {'Viser la moitié de la bille'} text
    And I see text containing {'Demi-bille : la blanche, un peu plus petite, couvre la moitié de la bille de couleur ; le procédé vise le centre de la blanche.'}
    And the element {'theory:tangente'} is marked as sourced

  Scenario: An exercise shows its diagram, set-up, instruction and expected result
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    Then I see the guide at step {6} of {10}
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
    Then I see the guide at step {8} of {10}
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
    Then I see the guide at step {6} of {10}
    And I see the session audience {'Adults · 120 min'}

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
    Then I see the guide at step {6} of {10}
    When I tap {'Previous'} text
    Then I see {'2 of 2 successes'} text

  # U5 : la saisie depuis le guide s'ouvre en feuille basse, le guide reste en place.
  Scenario: Noting the results opens a bottom sheet on the current exercise and the guide stays on its step
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    Then the record sheet is open
    And I see the guide at step {6} of {10}
    When I tap {'Open the session'} text
    Then the exercise {'demi-bille 1'} is selected for the record
    And the record sheet is open
    When I tap {'Back to the guided session'} text
    Then the record sheet is closed
    And I see the guide at step {6} of {10}

  Scenario: The system back gesture closes the record sheet and the guide stays on its step
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    And I tap {'Open the session'} text
    Then the exercise {'demi-bille 1'} is selected for the record
    When I press the system back button
    Then the record sheet is closed
    And I see the guide at step {6} of {10}
    And I see {'Note the results'} text

  Scenario: The record offers to go back to the guide before opening a session
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    And I tap {'Note the results'} text
    Then I see {'Back to the guided session'} text
    When I tap {'Back to the guided session'} text
    Then I see the guide at step {6} of {10}

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
    Then I see the guide at step {1} of {10}
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
    Then I see the guide at step {2} of {10}
    When I open the guide outline
    And I tap {'8 billes dans une poche'} text
    Then I see the guide at step {9} of {10}
    And the phase {'game'} is on screen
    When I tap {'Previous'} text
    Then I see the guide at step {8} of {10}

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
    When I end the guided session
    And I tap {'Confirm'} text
    Then I see {'Viser pour empocher (bille fantôme), session 1/1'} text
    And nothing is recorded

  Scenario: Ending the session resets what was counted
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I end the guided session
    And I tap {'Confirm'} text
    And I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    Then I see {'0 of 4 successes'} text

  Scenario: Ending the session asks for confirmation and keeps everything when cancelled
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I end the guided session
    Then I see {'End the guided session?'} text
    When I tap {'Cancel'} text
    Then I see {'2 of 4 successes'} text
    And I see the guide at step {6} of {10}

  Scenario: Launching again a started session offers to resume it or to start over
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/catalogue/posture-1'}
    And I tap {'Launch'} text
    Then I see {'This session is already under way: step 6 of 10.'} text
    When I tap {'Resume at step 6'} text
    Then I see the guide at step {6} of {10}
    And I see {'2 of 4 successes'} text
    And I do not see text containing {'already under way'}
    When I go to the address {'/catalogue/posture-1'}
    And I tap {'Launch'} text
    And I tap {'Start over'} text
    Then I see the guide at step {1} of {10}
    And I do not see text containing {'already under way'}

  Scenario: A planned session leads back to the planner when it ends
    Given the app is running
    And je planifie la séance {'Cours'} pour les {'adultes'} avec la séance du catalogue {'demi-bille-2'}
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    And I end the guided session
    And I tap {'Confirm'} text
    Then I see {'Planning'} text
    And I see {'Cours'} text

  Scenario: A planned session keeps its counters and audience through the presentation
    Given the app is running
    And je planifie la séance {'Cours'} pour les {'adultes'} avec la séance du catalogue {'demi-bille-2'}
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    And I open the guide outline
    And I tap {'Près puis loin'} text
    And I count {2} successes on the initiation
    And I tap {'Show'} text
    Then the presentation is open
    When I tap {'Close'} text
    Then I see {'2 of 2 successes'} text
    And I see the session audience {'Adults · 120 min'}
    And I see the guide at step {7} of {12}

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
    Then I see the session audience {'Adults · 120 min'}
    And I see the guide at step {1} of {12}

  Scenario: An unknown session is a missing page and the step is clamped
    Given the app is running
    When I go to the address {'/catalogue/unknown-9/guide'}
    Then I see {'Page not found'} text
    When I go to the address {'/catalogue/demi-bille-1/guide?step=99'}
    Then I see the guide at step {10} of {10}

  Scenario: The French interface labels the guide in French
    Given the device language is {'fr'}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?step=1'}
    Then I see the button {'Étape 2 sur 10'}
    And I see {'Suivant'} text
    And I see {'Précédent'} text
    And I see {'Montrer'} text
    When I open the guide menu
    Then I see {'Sommaire'} text
    And I see {'Mode relecture'} text
    And I see {'La séance'} text
    And I see {'Terminer la séance'} text

  # Lancer une séance planifiée pour un groupe pré-remplit la saisie (ADR 0007).
  Scenario: Launching a planned session prefills the record with its group and date
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'adults'} audience
    And a session {'Cours'} is planned for the group {'Adults group'} on {'2026-10-19'} with the catalogue session {'demi-bille-1'}
    And the app is running
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    Then I see the session audience {'Adults · 120 min'}
    When I tap {'Next'} text
    Then I see the guide at step {2}
    When I tap {'Next'} text
    And I tap {'Next'} text
    Then I see the guide at step {4}
    When I tap {'Next'} text
    And I tap {'Next'} text
    Then I see the guide at step {6}
    When I tap {'Note the results'} text
    Then I see {'Record the results'} text
    And I see {'Mon, Oct 19'} text
    And I see {'Hugo'} text
    And I do not see {'Léa'} text
    When I tap {'Open the session'} text
    Then I see {'Adults group · Catalogue session: Quantité demi-bille, session 1/2'} text
    And the opened session has the main block {'demi-bille'} and the recall block {'bille-pleine'}

  # D1 (ADR 0016) : noter depuis le guide de la 2e séance du jour ouvre une
  # nouvelle saisie et laisse intacte celle de la 1re séance.
  Scenario: Noting from the guide of the second session of the day opens a new record
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-2'}
    And a session is recorded for the group {'Children group'} on {'2026-10-12'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    And I tap {'Next'} text
    Then I see the guide at step {2}
    When I tap {'Next'} text
    And I tap {'Next'} text
    Then I see the guide at step {4}
    When I tap {'Next'} text
    And I tap {'Next'} text
    Then I see the guide at step {6}
    When I tap {'Note the results'} text
    And I tap {'Open the session'} text
    Then the group {'Children group'} has {2} recorded sessions on {'2026-10-12'}
    And the group {'Children group'} has a recorded session with the catalogue session {'posture-1'} on {'2026-10-12'}

  # U4 (lot 2) : le guide est un écran de premier niveau (comme la
  # présentation) : ni rail ni barre de navigation en séance.
  Scenario Outline: The guide shows no navigation bar and no rail
    Given the screen is {<width>} by {<height>}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    Then I see the guide at step {1} of {10}
    And I see the {'none'} navigation

    Examples:
      | width | height |
      | 390   | 844    |
      | 1280  | 800    |

  # U4 (lot 2, solde de U-9) : le retour du guide mène à son origine.
  Scenario: A planned session launched from Planned leads back to Planned
    Given the app is running
    And je planifie la séance {'Cours'} pour les {'adultes'} avec la séance du catalogue {'demi-bille-2'}
    When I tap {'Plan a session'} text
    And I tap {'Launch'} text
    And I tap the back button
    Then the sessions tab {'Planned'} is selected
    And I see {'Cours'} text

  Scenario: A guide launched from a detail opened from the catalogue leads back to that detail then to the catalogue with the chosen group
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session is recorded for the group {'Children group'} on {'2026-10-05'} with the catalogue session {'posture-1'} and a pass
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Children group'} in the catalogue
    And I open the session {'posture-2'} of the catalogue
    And I tap {'Launch'} text
    And I tap the back button
    Then the back button says {'Session catalogue'}
    And I see {'Launch'} text
    And I do not see the sessions tabs
    When I tap the back button
    Then the group {'Children group'} is selected in the catalogue

  Scenario: A guide launched from a detail opened from Today leads back to the detail then to Today
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1?from=today'}
    And I tap {'Launch'} text
    And I tap the back button
    Then the back button says {'Today'}
    And I see {'Launch'} text
    And I see text containing {'Quantité demi-bille'}
    When I tap the back button
    Then the destination {'Today'} is selected

  Scenario: A guide launched from the suggestion leads back to the suggestion
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'Sessions'} text
    And I tap {'Suggestion'} text
    And I tap {'Suggest a session'} text
    And I tap {'Launch the guided session'} text
    And I tap the back button
    Then the sessions tab {'Suggestion'} is selected

  Scenario: An unknown origin value falls back to the session of the catalogue
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?from=evil'}
    And I tap the back button
    Then the back button says {'Session catalogue'}
    And I see {'Launch'} text
    And I see text containing {'Quantité demi-bille'}

  Scenario: The group chosen in the catalogue is proposed to the record opened from the guide
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Hugo'} in the {'adults'} audience
    And the app is running
    When I go to the address {'/catalogue'}
    And I pick the group {'Adults group'} in the catalogue
    And I open the session {'demi-bille-1'} of the catalogue
    And I tap {'Launch'} text
    And I go to the guide step {'Note the results'}
    And I tap {'Note the results'} text
    Then I see {'Record the results'} text
    And I see {'Hugo'} text
    And I do not see {'Léa'} text

  Scenario: Closing the presentation and the record sheet keeps the origin of the guide
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'demi-bille-1'}
    And the app is running
    When I tap {'Launch'} text
    And I tap {'Next'} text
    And I tap {'Show'} text
    Then the presentation is open
    When I tap {'Close'} text
    And I go to the guide step {'Note the results'}
    And I tap {'Note the results'} text
    Then the record sheet is open
    When I tap {'Back to the guided session'} text
    And I tap the back button
    Then the destination {'Today'} is selected

  # U4 (lot 2) : en-tête compact, schéma en premier, barre basse.
  Scenario: The header shows the step title once, the position and the phase timeline
    Given the screen is {390} by {844}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    Then I see {'Exercise 1 · Les six parts de gâteau'} text
    And I see the guide at step {6} of {10}
    And I see the button {'Phase 3 of 5: Training, 35 min, current'}
    And the phase {'training'} is on screen
    And the phase timeline is above the phase {'training'}
    And the guide header takes at most a quarter of the screen

  Scenario Outline: The diagram of an exercise is visible without scrolling
    Given the screen is {<width>} by {<height>}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=<step>'}
    Then the set-up diagram of the exercise {<number>} is shown
    And the diagram is fully visible without scrolling
    And the guide header takes at most a quarter of the screen

    Examples:
      | width | height | step | number |
      | 390   | 844    | 5    | 1      |
      | 390   | 844    | 7    | 4      |
      | 1280  | 800    | 5    | 1      |
      | 1280  | 800    | 7    | 4      |

  Scenario: The diagram comes before the set-up and the instruction
    Given the screen is {390} by {844}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    Then the diagram is above the text {'Set-up: La rouge du schéma sous la poche du milieu'}

  Scenario: Tapping a phase of the timeline jumps to its first step
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    And I tap the phase {4}
    Then I see the guide at step {9} of {10}
    And the phase {'game'} is on screen
    When I tap the phase {1}
    Then I see the guide at step {1} of {10}

  Scenario: The bottom bar offers Previous, Note the results and Next on an exercise
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    Then the bottom bar offers {'Previous,Note the results,Next'}

  Scenario: The bottom bar offers only Previous and Next on a notion step
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=1'}
    Then the bottom bar offers {'Previous,Next'}
    And I do not see {'Note the results'} text

  Scenario: The bottom bar of a phone keeps arrows around Note the results
    Given the screen is {390} by {844}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    Then the bottom bar offers {'Previous,Note the results,Next'}
    When I tap the tooltip {'Next'}
    Then I see the guide at step {7} of {10}
    When I tap the tooltip {'Previous'}
    Then I see the guide at step {6} of {10}

  Scenario: The last step offers Finish instead of Next and asks for confirmation
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=9'}
    Then the bottom bar offers {'Previous,Finish'}
    And I do not see {'Next'} text
    When I tap {'Finish'} text
    Then I see {'End the guided session?'} text
    When I tap {'Cancel'} text
    Then I see the guide at step {10} of {10}
    When I tap {'Finish'} text
    And I tap {'Confirm'} text
    Then I see text containing {'Quantité demi-bille, session 1/2'}

  Scenario: Finishing from the menu asks for confirmation and Cancel keeps the guide
    Given the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I end the guided session
    Then I see {'End the guided session?'} text
    When I tap {'Cancel'} text
    Then I see {'2 of 4 successes'} text

  Scenario: The bottom bar and the header fit at 320 dp with text at 200 percent
    Given the screen is {320} by {640}
    And the text size is {200} percent
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=5'}
    Then the bottom bar stays on the screen
    And the bottom bar offers {'Note the results,Previous,Next'}
    When I tap {'Next'} text
    Then I see the guide at step {7} of {10}
    When I open the guide menu
    Then I see {'Outline'} text
    And I see {'End session'} text

  Scenario: The bottom bar and the header fit at 320 dp on a step without notes
    Given the screen is {320} by {640}
    And the text size is {200} percent
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=1'}
    Then the bottom bar stays on the screen
    And the bottom bar offers {'Previous,Next'}

  # Minuteur (R9) : temps restant en en-tête, ton qui change.
  Scenario Outline: The timer changes tone under one minute and past the planned time
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    Then I see {'10:00'} text
    And the timer chip uses the {'neutral'} tone
    When the guide timer has run {<seconds>} seconds
    Then I see {'<text>'} text
    And the timer chip uses the {'<tone>'} tone

    Examples:
      | seconds | tone      | text   |
      | 540     | neutral   | 01:00  |
      | 541     | attention | 00:59  |
      | 600     | attention | 00:00  |
      | 601     | overdue   | +00:01 |

  Scenario: The timer is reset by the menu and by a change of phase
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    And the guide timer has run {30} seconds
    Then I see {'09:30'} text
    When I open the guide menu
    And I tap {'Reset the timer'} text
    Then I see {'10:00'} text
    When the guide timer has run {30} seconds
    And I tap {'Next'} text
    Then I see {'20:00'} text

  Scenario: The timer pauses when the guide is left
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    And I tap the tooltip {'Start the timer'}
    Then the guided session of {'demi-bille-1'} has its timer {'running'}
    When I tap the back button
    Then I see {'Launch'} text
    And the guided session of {'demi-bille-1'} has its timer {'paused'}

  # Modes Mener / Relecture : badges et sections.
  Scenario: A guide launched from a planned session hides the provenance badges and folds the notes
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    And I go to the guide step {'Note the results'}
    Then the provenance badges are {'hidden'}
    And the proposal is announced to screen readers
    And the section {'Frequent mistakes (instructor)'} is {'folded'}
    And the section {'Hook and challenge'} is {'folded'}
    And I do not see {'This target is a proposal, not a federal figure.'} text

  Scenario: In lead mode the game notes are folded and the recall stays readable
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1/guide?audience=children&step=8&mode=lead'}
    Then the section {'Playful variant'} is {'folded'}
    And the section {'Link with the previous session'} is {'folded'}
    And the section {'Adaptation for this audience'} is {'folded'}
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=children&step=0&mode=lead'}
    Then I see {'Previous session: Quantité de bille pleine, session 2/2'} text

  Scenario: In review mode the game notes are open
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1/guide?audience=children&step=8&mode=review'}
    Then the section {'Playful variant'} is {'open'}
    And the section {'Link with the previous session'} is {'open'}
    And the section {'Adaptation for this audience'} is {'open'}

  Scenario: The menu switches to review mode, which shows the badges and opens the sections
    Given the club has the student {'Léa'} in the {'children'} audience
    And a session {'Cours'} is planned for the group {'Children group'} on {'2026-10-14'} with the catalogue session {'posture-1'}
    And the app is running
    When I tap {'Launch'} text
    And I go to the guide step {'Note the results'}
    And I switch the guide to {'review'} mode
    Then I see {4} provenance badges and {4} proposal badges
    And the section {'Frequent mistakes (instructor)'} is {'open'}
    And the section {'Hook and challenge'} is {'open'}
    And the guide is in {'review'} mode
    When I reload the guide
    Then the guide is in {'review'} mode
    When I tap {'Next'} text
    Then I see {4} provenance badges and {4} proposal badges
    When I switch the guide to {'lead'} mode
    Then the provenance badges are {'hidden'}
    And the guide is in {'lead'} mode

  Scenario: A guide launched from a detail without a planned session shows the badges and opens the sections
    Given the app is running
    When I go to the address {'/catalogue/posture-1'}
    And I tap {'Launch'} text
    And I go to the guide step {'Note the results'}
    Then I see {4} provenance badges and {4} proposal badges
    And the section {'Frequent mistakes (instructor)'} is {'open'}
    And the guide is in {'review'} mode

  Scenario: The session sheet names the theme, the notion and the proposals of the step
    Given the app is running
    When I go to the address {'/catalogue/bille-fantome-1/guide?audience=children&step=8&mode=lead'}
    And I open the guide menu
    And I tap {'The session'} text
    Then I see {'Theme: Le chasseur de fantômes'} text
    And I see text containing {'Notion:'}
    And I see text containing {'proposals on this step'}

  Scenario: A mode switched in the guide is kept through the presentation and the record sheet
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide?audience=adults&step=5'}
    And I switch the guide to {'lead'} mode
    And I tap {'Show'} text
    Then the presentation is open
    When I tap {'Close'} text
    Then the guide is in {'lead'} mode
    When I tap {'Note the results'} text
    Then the record sheet is open
    When I tap {'Back to the guided session'} text
    Then the guide is in {'lead'} mode
