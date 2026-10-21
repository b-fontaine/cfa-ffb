# FB7, partie B : qui voit l'entrée « Migrer mes données locales » et où elle
# mène. Le menu est filtré par rôle ET la route est refusée à qui n'a pas le
# droit (un lien tapé à la main ne contourne rien). Sous le backend local
# (`drift`, le défaut), il n'y a rien à migrer : « Plus » n'offre que
# « Sauvegarde » (pas de seconde entrée vers la même page) et la route d'import
# reste redirigée vers l'ancienne sauvegarde. Le texte par défaut est l'anglais.
Feature: Access to the import into the club

  Scenario: Under the local backend there is no migrate entry, only the backup
    Given the app is running
    When I tap {'More'} text
    Then I do not see {'Move my local data'} text
    When I tap {'Backup'} text
    Then the address is {'/backup'}
    And I see {'Import a backup'} text

  Scenario: Under the local backend the import route leads to the old backup
    Given the app is running
    When I go to the address {'/more/import'}
    Then the address is {'/backup'}

  Scenario: Under the club backend the director reaches the import screen
    Given the club data lives on a server shared with other devices
    And the club backend is active for the import
    And the app is running
    When I tap {'More'} text
    And I tap {'Move my local data'} text
    Then the address is {'/more/import'}
    And I see {'Import into the club'} text
    And I see {'Choose a backup file'} text
    And I see {'You are importing as: Director.'} text

  Scenario: Under the club backend the old backup page points to the import screen
    Given the club data lives on a server shared with other devices
    And the club backend is active for the import
    And the app is running
    When I go to the address {'/backup'}
    Then I do not see {'Import a backup'} text
    And I see {'Import into the club'} text

  Scenario: A teacher has the entry and imports under their own role
    Given the club backend is active for the import
    And the club has the student {'Léa'} in the {'children'} audience
    And {'sophie@example.org'} is a {'teacher'} of the club {'Test club'} for the group {'Children group'}
    And {'sophie@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Move my local data'} text
    Then I see {'You are importing as: Teacher.'} text

  Scenario: A parent has no entry and the route is refused
    Given the club data lives on a server shared with other devices
    And the club backend is active for the import
    And the club has the student {'Léa'} in the {'children'} audience
    And {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    Then I do not see {'Move my local data'} text
    When I go to the address {'/more/import'}
    Then the address is {'/my-children'}

  Scenario: A student of 15 or older has no entry and the route is refused
    Given the club data lives on a server shared with other devices
    And the club backend is active for the import
    And the club has the student {'Léa'} in the {'children'} audience
    And {'leo@example.org'} follows the student {'Léa'} as a {'student'} in the club {'Test club'}
    And {'leo@example.org'} is signed in on the device
    And the app is running
    When I go to the address {'/more/import'}
    Then the address is {'/my-children'}
