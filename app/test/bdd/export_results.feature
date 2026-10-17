# Lot 14 (ADR 0021) : les fiches résultats papier, reproduction de la fiche du
# PDF fédéral (4 grilles par page A4), noms vides par défaut.
Feature: PDF export of the results sheets

  The instructor prints the federal results sheet, four grids per A4 page, one
  series per training exercise of the session. Names are blank unless the
  instructor explicitly asks for the first names of a group.

  Scenario: Without a group, eight blank grids make two pages per exercise
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Results sheets'} text
    Then the PDF preview mentions {'Results sheet'}
    And the PDF preview has {2} pages for each exercise of {'demi-bille-1'} in the audience {'children'}

  Scenario: The grid copies the federal sheet
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Results sheets'} text
    Then the PDF preview mentions {'TRY 5'}
    And the PDF preview does not mention {'TRY 6'}
    And the PDF preview mentions {'Balls pocketed'}
    And the PDF preview draws a scale from {0} to {16}

  Scenario: The fixed texts of the sheet follow the language of the device
    Given the device language is {'fr'}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Imprimer / exporter en PDF'} text
    And I tap {'Fiches résultats'} text
    Then the PDF preview mentions {'Fiche Résultats'}
    And the PDF preview mentions {'ESSAI 5'}
    And the PDF preview mentions {'Nb de billes empochées'}
    And the PDF preview mentions {'Séance : Quantité demi-bille'}
    And the PDF preview does not mention {'TRY 5'}

  Scenario: The document follows a language change made while the screen is open
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Results sheets'} text
    Then the PDF preview mentions {'Results sheet'}
    When the device language changes to {'fr'}
    And I tap {'Fiches résultats'} text
    Then the PDF preview mentions {'Fiche Résultats'}
    And the PDF preview does not mention {'Results sheet'}

  Scenario: More passes required add attempt columns
    Given the passes required are set to {6}
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Results sheets'} text
    Then the PDF preview mentions {'TRY 6'}

  Scenario: The session, notion and technique are prefilled
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Results sheets'} text
    Then the PDF preview mentions {'Session: Quantité demi-bille'}
    And the PDF preview mentions {'Technique: Quantité demi-bille'}
    And the PDF preview mentions {'Notion: Viser la tangente'}

  Scenario: Names are blank by default and no student is read
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Results sheets'} text
    Then the PDF preview does not mention {'Léa'}
    And I do not see text containing {'will contain first names'}

  Scenario: The first names of a group are printed only on request, with a warning
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Zoé'} in the {'children'} audience
    And the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Results sheets'} text
    And I pick the group {'Children group'} for the results sheets
    Then the PDF preview does not mention {'Léa'}
    When I tap {"Print the group’s first names"} text
    Then I see text containing {'will contain first names'}
    And the PDF preview mentions {'Léa'}
    And the PDF preview mentions {'Zoé'}
    And the PDF preview lists {'Léa'} before {'Zoé'}

  Scenario: The source of the federal sheet is cited and no logo is printed
    Given the app is running
    When I go to the address {'/catalogue/demi-bille-1'}
    And I tap {'Print / export as PDF'} text
    And I tap {'Results sheets'} text
    Then the PDF preview mentions {'CFA Blackball Results Sheet, National Technical Directorate'}
    And the PDF preview draws no image
