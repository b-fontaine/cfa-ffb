# Lot 14 (ADR 0021) : la feuille de l'animateur d'une séance du catalogue en
# PDF, sans aucun nom d'élève, enregistrée ou imprimée hors ligne.
Feature: PDF export of a session sheet

  The instructor prints the animator sheet of a catalogue session: run-down
  with minutes, instructions, table diagrams, provenance and sources. The
  document never contains a student name and is produced on the device.

  Scenario: The animator sheet of a children session shows 90 minutes
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    Then I see {'PDF export'} text
    And the PDF preview mentions {'Quantité demi-bille'}
    And the PDF preview mentions {'Children, 90 min'}
    And the PDF preview mentions {'Total: 90 min'}

  Scenario: The animator sheet of an adults session shows 120 minutes
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1?audience=adults'}
    And I tap {'Print / export as PDF'} text
    Then the PDF preview mentions {'Adults, 120 min'}
    And the PDF preview mentions {'Total: 120 min'}
    And the PDF preview mentions {'Recall exercise: chosen during the session'}

  Scenario: Changing the audience rebuilds the document
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Adults · 120 min'} text
    Then the PDF preview mentions {'Adults, 120 min'}
    And the PDF preview does not mention {'Children, 90 min'}

  Scenario: Proposals are marked and the legend is printed
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    Then the PDF preview mentions {'[Prop]'}
    And the PDF preview mentions {'[Prop]: unsourced proposal, to be validated.'}
    And the PDF preview mentions {'Minutes are [Prop]'}

  Scenario: No student or group name is ever printed
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the group {'Wednesday'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    Then the PDF preview does not mention {'Léa'}
    And the PDF preview does not mention {'Wednesday'}
    And the PDF preview does not mention {'Children group'}

  Scenario: An exercise with a diagram prints its table
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    Then the PDF preview draws a table with {6} pockets
    And the PDF preview letters every ball

  Scenario: An illustration that is not a table prints its caption
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    Then the PDF preview mentions {'Plein et demi-bille, côte à côte.'}

  Scenario: Saving writes a named PDF file
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Save PDF'} text
    Then I see {'PDF saved.'} text
    And the saved PDF is named {'session-demi-bille-1-children.pdf'}
    And the saved PDF is a PDF document

  Scenario: Cancelling the save dialog writes nothing
    Given the save dialog is cancelled
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Save PDF'} text
    Then I see {'Save cancelled.'} text
    And no PDF was saved

  Scenario: An unknown session shows the missing page and no file
    Given the app is running
    When I go to the address {'/catalogue/inconnue-9/export'}
    Then I see {'Page not found'} text
    And no PDF was saved

  Scenario: Printing is offered only where the platform can print
    Given the platform can print
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Print'} text
    Then the PDF was sent to print

  Scenario: Printing is hidden where the platform cannot print
    Given the platform cannot print
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    Then I see {'Save PDF'} text
    And I do not see {'Print'} text

  Scenario: The guide offers the same export
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1/guide'}
    And I open the guide menu
    And I tap {'Print / export as PDF'} text
    Then I see {'PDF export'} text
    And the PDF preview mentions {'Total: 90 min'}

  Scenario: The document is produced without any network access
    Given network access is forbidden
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Save PDF'} text
    Then I see {'PDF saved.'} text
    And no network request was attempted
