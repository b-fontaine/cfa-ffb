# FB7c : l'export en LECTURE SEULE de la base locale (drift) dans le build qui
# lit le club sur Firestore, tant que drift n'est pas retiré. Ce que prouvent
# ces scénarios : ce que l'animateur voit et peut faire (bandeau, entrée de
# « Plus », écran sans compte, contrôle des nombres AVANT d'enregistrer, fichier
# vide jamais « enregistré ») sur les dépôts de la scène, qui jouent ici la base
# locale. Les garanties sur la vraie base SQLite (détection sans création ni
# écriture, export sans modification, aller-retour jusqu'au club) sont dans
# test/unit/shared/persistence/local_store_probe_test.dart et
# test/unit/features/backup_data/local_export_roundtrip_test.dart. Le texte par
# défaut est l'anglais.
Feature: Export the data left on this device

  Scenario: A teacher with local data sees the reminder and exports a file read with its counts
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And the app is running
    Then I see text containing {'Data on this device has not yet been exported or imported into the club (6 students, 72 passes).'}
    When I tap {'More'} text
    Then I see {'Export my local data'} text
    When I tap {'Export now'} text
    Then I see {'What the file contains'} text
    And I see {'6 students'} text
    And I see {'72 passes'} text
    And I do not see {'File saved'} text
    When I tap {'Save the file'} text
    Then I see text containing {'File saved: 6 students, 72 passes.'}
    And the saved local file holds {6} students and {72} passes
    And the local data still hold {6} students and {72} passes

  Scenario: Without local data there is neither reminder nor entry
    Given the club build keeps no local data
    And the app is running
    Then I do not see {'Export now'} text
    When I tap {'More'} text
    Then I do not see {'Export my local data'} text

  Scenario: Without an account the sign-in screen offers the export
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And nobody is signed in on the device
    And the app is running
    Then I see {'Sign in to the app'} text
    And I see text containing {'(6 students, 72 passes)'}
    And I do not see {'I have imported my data into the club'} text
    When I tap {'Export now'} text
    Then I see {'What the file contains'} text
    And I see {'6 students'} text
    When I tap {'Save the file'} text
    Then I see text containing {'File saved: 6 students, 72 passes.'}
    And the saved local file holds {6} students and {72} passes

  Scenario: A file with nothing in it is flagged and cannot be saved
    Given the club build keeps no local data
    And the app is running
    When I go to the address {'/local-export'}
    Then I see text containing {'This file is empty: export from the place where you entered your data (browser tab or installed app).'}
    And I do not see {'Save the file'} text
    And no local file was saved

  Scenario: A base written by a newer version is refused, not read
    Given the club build keeps a local base written by a newer version
    And the app is running
    Then I see text containing {'Data on this device may not yet have been exported or imported into the club.'}
    And I do not see {'I have imported my data into the club'} text
    And I see {'Read the data again'} text
    When I tap {'Export now'} text
    Then I see text containing {'This data was written by a newer version of the app.'}
    And I do not see {'Save the file'} text
    And no local file was saved

  Scenario: Cancelling the save location saves nothing and says so
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And the backup dialog is cancelled
    And the app is running
    When I tap {'Export now'} text
    And I tap {'Save the file'} text
    Then I see {'Saving cancelled: no file was saved.'} text
    And I do not see text containing {'File saved'}
    And no local file was saved

  Scenario: The reminder goes away only when the teacher says the data are imported
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And the app is running
    When I tap {'Export now'} text
    And I tap {'Save the file'} text
    And I go to the address {'/'}
    Then I see {'I have imported my data into the club'} text
    When I tap {'I have imported my data into the club'} text
    Then I see {'Hide this reminder?'} text
    When I tap {'Yes, hide the reminder'} text
    Then I do not see {'I have imported my data into the club'} text
    When I tap {'More'} text
    Then I see {'Export my local data'} text
    And the local data still hold {6} students and {72} passes

  Scenario: On a shared device the reminder confirmed by one teacher still shows for another
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And {'anne@example.org'} is a {'teacher'} of the club {'Test club'}
    And {'ben@example.org'} is a {'teacher'} of the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    When I tap {'I have imported my data into the club'} text
    And I tap {'Yes, hide the reminder'} text
    Then I do not see {'I have imported my data into the club'} text
    When I tap {'More'} text
    And I tap {'Sign out'} text
    Then I see {'Sign in to the app'} text
    When I enter {'ben@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'I have imported my data into the club'} text

  Scenario: The reminder cannot be hidden while changes wait to be sent to the club
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And the app is running
    And a change waits to be sent to the server
    When I tap {'I have imported my data into the club'} text
    And I tap {'Yes, hide the reminder'} text
    Then I see {'Some changes have not been sent yet'} text
    When I tap {'Understood'} text
    Then I see {'I have imported my data into the club'} text
    When the server acknowledges the changes
    And I tap {'I have imported my data into the club'} text
    And I tap {'Yes, hide the reminder'} text
    Then I do not see {'I have imported my data into the club'} text

  Scenario: Declining the confirmation keeps the reminder
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And the app is running
    When I tap {'I have imported my data into the club'} text
    And I tap {'Cancel'} text
    Then I see {'I have imported my data into the club'} text

  Scenario: The reminder and the screen speak French on a French device
    Given the device language is {'fr'}
    And the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And the app is running
    Then I see text containing {'Des données de cet appareil n’ont pas encore été exportées ou importées dans le club (6 élèves, 72 passages).'}
    When I tap {'Exporter maintenant'} text
    Then I see {'Exporter mes données locales'} text
    And I see {'Ce que contient le fichier'} text
    And I see {'6 élèves'} text
    When I tap {'Enregistrer le fichier'} text
    Then I see text containing {'Fichier enregistré : 6 élèves, 72 passages.'}

  Scenario: Under the local backend there is no export entry and the route leads to the backup
    Given the app is running
    When I tap {'More'} text
    Then I do not see {'Export my local data'} text
    When I go to the address {'/local-export'}
    Then the address is {'/backup'}

  Scenario Outline: A parent or a student never sees the teacher's export
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And the club has the student {'Léa'} in the {'children'} audience
    And {'anne@example.org'} is a {'<role>'} of the club {'Test club'} for the student {'Léa'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I do not see {'Export now'} text
    And I do not see {'I have imported my data into the club'} text
    When I go to the address {'/more'}
    Then I do not see {'Export my local data'} text

    Examples:
      | role     |
      | guardian |
      | student  |

  Scenario: Without a club the choice screen offers the export
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And nobody is signed in on the device
    And the account {'lonely@example.org'} exists with the password {'correct-horse-battery'}
    And the app is running
    When I enter {'lonely@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'No club'} text
    And I see text containing {'(6 students, 72 passes)'}
    And I see {'Export now'} text
    And I do not see {'I have imported my data into the club'} text

  Scenario: The registration screen offers the export
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And nobody is signed in on the device
    And the app is running
    When I go to the address {'/register'}
    Then I see {'Export now'} text
    And I do not see {'I have imported my data into the club'} text

  Scenario: The unavailable service screen offers the export
    Given the club build keeps local data of {2} groups, {3} students per group and {3} sessions per group
    And the account service is unavailable
    And the app is running
    Then I see {'Service unreachable'} text
    And I see {'Export now'} text

  Scenario: Under the local backend there is no reminder even if local data are announced
    Given the local backend announces local data of {2} groups, {3} students per group and {3} sessions per group
    And nobody is signed in on the device
    And the app is running
    Then I see {'Sign in to the app'} text
    And I do not see {'Export now'} text
