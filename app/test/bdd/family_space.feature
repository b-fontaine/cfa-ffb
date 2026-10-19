# Lot FB6 (ADR 0024, décisions 16 et 26 ; ADR 0025) : l'espace d'un parent ou d'un
# élève de 15 ans et plus, en LECTURE SEULE. Il y voit le parcours de ses élèves liés
# (un à la fois) et les prochaines séances planifiées de ses groupes ; jamais une
# saisie, une alerte, un bilan, la liste des camarades ni un autre élève. Les données
# vivent sur un serveur partagé (dépôts Firestore, comme pour un parent connecté) :
# l'animateur est un AUTRE appareil du même club. Le texte par défaut est l'anglais.
# « Aujourd'hui » est le lundi 12 octobre 2026.
Feature: Family space

  Background:
    Given the club data lives on a server shared with other devices
    And the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Tom'} in the {'children'} audience
    And the club has the student {'Marc'} in the {'children'} audience

  Scenario: A parent lands on the path of their child and the next sessions of the group
    Given {'Léa'} has {5} successful passes on {'puissance 1'}
    And a session {'Rebond au centre'} is planned for the group {'Children group'} on {'2026-10-14'} without a catalogue session
    And {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I see {'1 exercise validated'} text
    And I see {'Next sessions'} text
    And I see {'Rebond au centre'} text
    And I see {'You are viewing this information read-only. The coach keeps it up to date.'} text
    And I do not see {'Marc'} text
    And I do not see {'Tom'} text

  Scenario: A parent with two children switches from one to the other without mixing them
    Given {'Léa'} has {5} successful passes on {'puissance 1'}
    And {'Tom'} has {5} successful passes on {'puissance 1'}
    And {'Tom'} has {5} successful passes on {'posture 1'}
    And {'anne@example.org'} follows the students {'Léa'} and {'Tom'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then the child {'Léa'} is selected
    And I see {'1 exercise validated'} text
    And I do not see {'Marc'} text
    When I select the child {'Tom'}
    Then the child {'Tom'} is selected
    And I see {'2 exercises validated'} text
    And I do not see {'1 exercise validated'} text
    When I select the child {'Léa'}
    Then the child {'Léa'} is selected
    And I see {'1 exercise validated'} text
    And I do not see {'2 exercises validated'} text

  Scenario: A parent has no action of a coach, and the routes of a coach are refused
    Given {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I do not see {'Students'} text
    And I do not see {'Results'} text
    And I do not see {'Plan the next session'} text
    And I do not see {'Record'} text
    And I do not see {'Done'} text
    When I go to the address {'/students'}
    Then the address is {'/my-children'}
    When I go to the address {'/record'}
    Then the address is {'/my-children'}
    When I go to the address {'/planner'}
    Then the address is {'/my-children'}
    When I go to the address {'/club'}
    Then the address is {'/my-children'}
    When I go to the address {'/settings'}
    Then the address is {'/my-children'}
    When I tap {'More'} text
    Then I do not see {'My club'} text
    And I do not see {'Settings'} text

  Scenario: The screen of the parent follows a pass recorded by the coach
    Given {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I see {'Path to start'} text
    When {'Léa'} has {5} successful passes on {'puissance 1'}
    Then I see {'1 exercise validated'} text
    And I do not see {'Path to start'} text

  Scenario: The screen of the parent follows a session planned by the coach
    Given {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I see {'No session is planned for now.'} text
    When a session {'Rebond au centre'} is planned for the group {'Children group'} on {'2026-10-14'} without a catalogue session
    Then I see {'Rebond au centre'} text
    And I do not see {'No session is planned for now.'} text

  Scenario: The parent only asks the server for the data of their own children
    Given {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I see {'Path to start'} text
    And the device asked the server for no data of {'Marc'}
    And the device asked the server for no data of {'Tom'}
    And the device asked the server for no list of the students, the records or the assessments

  Scenario: A student of 15 or older lands on their own progress
    Given {'Léa'} has {5} successful passes on {'puissance 1'}
    And {'lea@example.org'} follows the student {'Léa'} as a {'student'} in the club {'Test club'}
    And {'lea@example.org'} is signed in on the device
    And the app is running
    Then I see {'1 exercise validated'} text
    And I do not see {'Marc'} text
    And I do not see {'Students'} text

  Scenario: The screen of a parent follows a pass recorded for the second child
    Given {'Léa'} has {5} successful passes on {'puissance 1'}
    And {'Tom'} has {5} successful passes on {'puissance 1'}
    And {'Tom'} has {5} successful passes on {'posture 1'}
    And {'anne@example.org'} follows the students {'Léa'} and {'Tom'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    When {'Tom'} has {5} successful passes on {'posture 2'}
    And I select the child {'Tom'}
    Then the child {'Tom'} is selected
    And I see {'3 exercises validated'} text
    And I do not see {'2 exercises validated'} text

  Scenario: A parent who loses the link to only one of two children keeps the other
    Given {'Léa'} has {5} successful passes on {'puissance 1'}
    And {'anne@example.org'} follows the students {'Léa'} and {'Tom'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I see {'1 exercise validated'} text
    When the link of {'anne@example.org'} to the student {'Tom'} is removed by the club
    Then I see {'1 exercise validated'} text
    And I do not see {'Tom'} text
    And I do not see {'Access denied'} text
    And I do not see {'Access removed'} text

  Scenario: A parent whose link is removed loses the access live and is told so
    Given {'Léa'} has {5} successful passes on {'puissance 1'}
    And {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I see {'1 exercise validated'} text
    When the access of {'anne@example.org'} is removed by the club
    Then I see {'Access removed'} text
    And I do not see {'1 exercise validated'} text
    And I do not see {'Léa'} text
    And no subscription stays open on the shared server

  Scenario: A refusal of the server is told apart from an unreachable service
    Given {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the server refuses the students of the club to the device
    And the app is running
    Then I see {'Access denied'} text
    And I do not see {'Access removed'} text
    And I do not see {'The service is not responding. Check your connection and try again.'} text

  Scenario: A parent offline keeps the information received and catches up later
    Given {'Léa'} has {5} successful passes on {'puissance 1'}
    And {'anne@example.org'} follows the student {'Léa'} as a {'guardian'} in the club {'Test club'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    Then I see {'1 exercise validated'} text
    When the device loses its connection to the server
    And the network is lost
    Then I see {'Offline'} text
    And I see {'1 exercise validated'} text
    When {'Léa'} has {5} successful passes on {'posture 1'}
    Then I see {'1 exercise validated'} text
    When the device gets its connection to the server back
    And the network comes back
    Then I see {'2 exercises validated'} text
    And I see {'Up to date'} text
