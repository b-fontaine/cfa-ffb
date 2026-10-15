# Lot 9 (F8, ADR 0012), écran : réglages du club sous « Plus ». États en
# bleu-tapis, aucun rouge comme état ; les bornes sont celles de RulesConfig.
Feature: Settings screen

  Scenario: Settings is reached from More and keeps More selected
    Given the app is running
    When I tap {'More'} text
    And I tap {'Settings'} text
    Then I see {'Exercise validation'} text
    And the destination {'More'} is selected

  Scenario: A fresh installation shows the default values
    Given the app is running
    When I go to the address {'/settings'}
    Then the setting {'Successful passes to validate an exercise'} shows {5}
    And the setting {'Consecutive failures before an alert'} shows {3}
    And the setting {'Sessions without practice before a recall'} shows {4}
    And the setting {'Group failure share (%) that recalls an exercise'} shows {50}
    And the setting {'Days before a backup reminder'} shows {30}

  Scenario: The screen says that entered passes are not changed
    Given the app is running
    When I go to the address {'/settings'}
    Then I see text containing {'does not change the passes already entered'}

  Scenario: Fewer required passes change the validation state at entry
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I go to the address {'/settings'}
    And I tap the control {'Fewer successful passes required'}
    And I tap the control {'Fewer successful passes required'}
    And I tap {'Save settings'} text
    Then I see {'Settings saved.'} text
    When I open the session of the group {'Children group'}
    Then I see {'0 of 3 successful passes'} text

  Scenario: Counters stop at their bounds
    Given the app is running
    When I go to the address {'/settings'}
    And I tap the control {'More failures before an alert'}
    And I tap the control {'More failures before an alert'}
    Then the setting {'Consecutive failures before an alert'} shows {5}
    And the control {'More failures before an alert'} is disabled
    And the control {'Fewer failures before an alert'} is enabled

  Scenario: The failure share moves by steps of ten
    Given the app is running
    When I go to the address {'/settings'}
    And I tap the control {'Lower the failure share'}
    Then the setting {'Group failure share (%) that recalls an exercise'} shows {40}

  Scenario: Settings refused by the rules show a message and write nothing
    Given the persistent alert threshold is {3}
    And the app is running
    When I go to the address {'/settings'}
    And I tap the control {'More failures before an alert'}
    And I tap {'Save settings'} text
    Then I see {'These settings are not accepted: nothing was saved.'} text
    And the setting {'Consecutive failures before an alert'} shows {4}
    When the app restarts
    And I go to the address {'/settings'}
    Then the setting {'Consecutive failures before an alert'} shows {3}

  Scenario: Restoring the default values asks for confirmation
    Given the app is running
    When I go to the address {'/settings'}
    And I tap the control {'More failures before an alert'}
    And I tap {'Save settings'} text
    And I tap {'Restore default values'} text
    Then I see {'Restore default values?'} text
    When I tap {'Cancel'} text
    Then the setting {'Consecutive failures before an alert'} shows {4}

  Scenario: Confirming restores the default values
    Given the app is running
    When I go to the address {'/settings'}
    And I tap the control {'More failures before an alert'}
    And I tap {'Save settings'} text
    And I tap {'Restore default values'} text
    And I tap {'Confirm'} text
    Then I see {'Default values restored.'} text
    And the setting {'Consecutive failures before an alert'} shows {3}

  Scenario: Saved settings survive an application restart
    Given the app is running
    When I go to the address {'/settings'}
    And I tap the control {'More successful passes required'}
    And I tap {'Save settings'} text
    And the app restarts
    And I go to the address {'/settings'}
    Then the setting {'Successful passes to validate an exercise'} shows {6}

  Scenario: Leaving with unsaved changes drops them
    Given the app is running
    When I go to the address {'/settings'}
    And I tap the control {'More successful passes required'}
    And I tap {'Back to More'} text
    And I tap {'Settings'} text
    Then the setting {'Successful passes to validate an exercise'} shows {5}

  Scenario: The backup reminder delay set here changes the banner
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'Léa'} has {2} successful passes on {'puissance 1'}
    And the app is running
    When I go to the address {'/settings'}
    And I tap the control {'Fewer days before a reminder'}
    And I tap the control {'Fewer days before a reminder'}
    And I tap the control {'Fewer days before a reminder'}
    And I tap the control {'Fewer days before a reminder'}
    And I tap the control {'Fewer days before a reminder'}
    And I tap {'Save settings'} text
    And I tap {'Today'} text
    And I tap {'Back up now'} text
    And I tap {'Export a backup (JSON)'} text
    And the day advances by {8} days
    And I tap {'Today'} text
    Then I see text containing {'8 days ago'}

  Scenario: Settings are in French on a French device
    Given the device language is {'fr'}
    And the app is running
    When I tap {'Plus'} text
    And I tap {'Réglages'} text
    Then I see {'Validation des exercices'} text
    And I see {'Enregistrer les réglages'} text
    And I see {'Rétablir les valeurs par défaut'} text
