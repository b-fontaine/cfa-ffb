# Lot FB5a (ADR 0024, C4) : indicateur de synchronisation, cache local vidé à
# la déconnexion, avertissement « appareil partagé ». Le texte par défaut est
# l'anglais. Les scénarios tournent sur les doubles en mémoire (réseau, suivi
# des envois, cache local) : le comportement du SDK Firestore hors ligne est
# éprouvé par les tests de règles et le parcours navigateur, pas ici.
Feature: Synchronization and local data

  Scenario: The sign-in screen warns about shared devices
    Given nobody is signed in on the device
    And the app is running
    Then I see {'On a shared device, always sign out when you leave: the club data kept on this device for offline use is deleted when you sign out.'} text

  Scenario: Everything is sent and the network is there
    Given the app is running
    Then I see {'Up to date'} text

  Scenario: Offline with nothing to send, then back online
    Given the app is running
    When the network is lost
    Then I see {'Offline'} text
    When the network comes back
    Then I see {'Up to date'} text

  Scenario: A change made offline waits, then is sent when the network returns
    Given the app is running
    When the network is lost
    And a change waits to be sent to the server
    Then I see {'Offline, waiting to send (1)'} text
    When the network comes back
    And the server acknowledges the changes
    Then I see {'Up to date'} text

  Scenario: A change waiting while online is counted
    Given the app is running
    When a change waits to be sent to the server
    And a change waits to be sent to the server
    Then I see {'Waiting to send (2)'} text

  Scenario: A change refused by the rules is reported soberly
    Given the app is running
    When the server refuses a change
    Then I see {'A change could not be saved and was undone on this device.'} text
    When I tap {'Got it'} text
    Then I do not see {'A change could not be saved and was undone on this device.'} text
    And I see {'Up to date'} text

  Scenario: Signing out clears the data kept for offline use
    Given the app is running
    When I tap {'More'} text
    And I tap {'Sign out'} text
    Then I see {'Sign in to the app'} text
    And the local data cache was cleared {1} times
    And the local data cache is then reopened

  Scenario: A cache that cannot be cleared at sign-out is reported, then cleared on retry
    Given the app is running
    And the local data cache cannot be cleared
    When I tap {'More'} text
    And I tap {'Sign out'} text
    Then I see {'Sign in to the app'} text
    And I see {'The offline data on this device could not be deleted: close the other tabs, then try again.'} text
    And I see {'Retry deletion'} text
    When I tap {'Retry deletion'} text
    Then I see {'The offline data on this device could not be deleted: close the other tabs, then try again.'} text
    And the local data cache was cleared {0} times
    When the local data cache can be cleared again
    And I tap {'Retry deletion'} text
    Then I do not see {'The offline data on this device could not be deleted: close the other tabs, then try again.'} text
    And I do not see {'Retry deletion'} text
    And the local data cache was cleared {1} times

  Scenario: Signing out with changes not sent yet asks before losing them
    Given the app is running
    And a change waits to be sent to the server
    When I tap {'More'} text
    And I tap {'Sign out'} text
    Then I see {'Changes not sent yet'} text
    And I see {'Sign out and lose them'} text
    When I tap {'Cancel'} text
    Then I do not see {'Changes not sent yet'} text
    And I do not see {'Sign in to the app'} text
    And the local data cache was cleared {0} times

  Scenario: Confirmed, signing out loses the changes and clears the cache
    Given the app is running
    And a change waits to be sent to the server
    When I tap {'More'} text
    And I tap {'Sign out'} text
    And I tap {'Sign out and lose them'} text
    Then I see {'Sign in to the app'} text
    And the local data cache was cleared {1} times

  Scenario: Changes queued before a restart still ask before being lost
    Given changes are still queued in the SDK from a previous run
    And the app is running
    Then I see {'Waiting to send (1)'} text
    When I tap {'More'} text
    And I tap {'Sign out'} text
    Then I see {'Changes not sent yet'} text
    And the local data cache was cleared {0} times
