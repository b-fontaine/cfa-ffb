# Suppression de son propre compte (FB8 partie B, tranche B2 ; ADR 0025
# décision 7(e) ; décisions D1 et D4 du 2026-10-24). Ordre sûr : mot de passe
# vérifié (réauthentification) avant toute écriture, contrôles (envois en
# attente, administrateur, dernier directeur), puis pour chaque club où le
# compte a un `member` (lu au serveur) : ses invitations inutilisées (lues au
# serveur, depuis n'importe quel appareil), ses marqueurs (B1) et son `member`
# en dernier ; enfin le compte d'authentification, puis
# les mêmes nettoyages locaux que la déconnexion. Les fiches des élèves restent
# au club. Le club est le stock de documents en mémoire des scénarios ; les
# règles réelles sont jouées contre l'émulateur (scripts/rules_test/) et le
# parcours complet dans le navigateur (scripts/emulator_e2e/e2e.test.mjs).
# Le texte par défaut est l'anglais.
Feature: Deleting one's own account

  Scenario: A teacher deletes their account and the traces they left in the club
    Given nobody is signed in on the device
    And {'coach@example.org'} is a {'teacher'} of the club {'Test club'}
    And {'coach@example.org'} left an import marker in the club {'Test club'}
    And {'coach@example.org'} issued a waiting invitation from this device in the club {'Test club'}
    And {'coach@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    Then I see {'Student records, their results and the sessions stay with the club: they belong to the club, not to your account.'} text
    When I enter {'correct-horse-battery'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Sign in to the app'} text
    And no account exists for {'coach@example.org'}
    And no member exists for {'coach@example.org'} in the club {'Test club'}
    And {'coach@example.org'} has no marker left in the club {'Test club'}
    And the invitation issued by {'coach@example.org'} no longer exists
    And nothing of {'coach@example.org'} is kept on the device
    And the member {'animateur@example.org'} of the club {'Test club'} has the role {'director'}

  Scenario: A parent of two students deletes their account and both records stay
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Tom'} in the {'children'} audience
    And nobody is signed in on the device
    And {'anne@example.org'} is a {'guardian'} of the club {'Test club'} for the students {'Léa'} and {'Tom'}
    And {'anne@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And I enter {'correct-horse-battery'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Sign in to the app'} text
    And no account exists for {'anne@example.org'}
    And no member exists for {'anne@example.org'} in the club {'Test club'}
    And the students {'Léa'} and {'Tom'} are still in the club

  Scenario: A parent one of whose students was already erased deletes their account
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Tom'} in the {'children'} audience
    And nobody is signed in on the device
    And {'anne@example.org'} is a {'guardian'} of the club {'Test club'} for the students {'Léa'} and {'Tom'}
    And the student {'Tom'} has already been erased from the club
    And {'anne@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And I enter {'correct-horse-battery'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Sign in to the app'} text
    And no account exists for {'anne@example.org'}
    And no member exists for {'anne@example.org'} in the club {'Test club'}
    And the students {'Léa'} and {'Léa'} are still in the club

  Scenario: A student with their own account deletes it and their record stays
    Given the club has the student {'Camille'} in the {'children'} audience
    And nobody is signed in on the device
    And {'camille@example.org'} is a {'student'} of the club {'Test club'} for the student {'Camille'}
    And {'camille@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And I enter {'correct-horse-battery'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Sign in to the app'} text
    And no account exists for {'camille@example.org'}
    And the students {'Camille'} and {'Camille'} are still in the club

  Scenario: The last director of a club is refused and nothing is deleted
    Given the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And I enter {'mot-de-passe-12'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'You are the last director of Test club. Ask the administrator to appoint another director, then try again. Nothing has been deleted.'} text
    And the member {'animateur@example.org'} of the club {'Test club'} has the role {'director'}
    And an account exists for {'animateur@example.org'}

  Scenario: A director who has a successor can delete their account
    Given {'second@example.org'} is a {'director'} of the club {'Test club'}
    And the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And I enter {'mot-de-passe-12'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Sign in to the app'} text
    And no account exists for {'animateur@example.org'}
    And the member {'second@example.org'} of the club {'Test club'} has the role {'director'}

  Scenario: An administrator is told why the app cannot delete their account
    Given nobody is signed in on the device
    And {'root@example.org'} is an administrator
    And {'root@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    Then I see {'An administrator account cannot be deleted from the app: it is deleted in the Firebase console, following the rights and erasure procedure.'} text
    And I do not see {'Delete my account permanently'} text
    And an account exists for {'root@example.org'}

  Scenario: A wrong password deletes nothing
    Given nobody is signed in on the device
    And {'coach@example.org'} is a {'teacher'} of the club {'Test club'}
    And {'coach@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And I enter {'not-the-password'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Incorrect password. Nothing has been deleted.'} text
    And the member {'coach@example.org'} of the club {'Test club'} has the role {'teacher'}
    And an account exists for {'coach@example.org'}

  Scenario: Offline, nothing is deleted
    Given nobody is signed in on the device
    And {'coach@example.org'} is a {'teacher'} of the club {'Test club'}
    And {'coach@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And the device goes offline
    And I enter {'correct-horse-battery'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'No connection: nothing has been deleted. Try again once you are online.'} text
    And the member {'coach@example.org'} of the club {'Test club'} has the role {'teacher'}
    And an account exists for {'coach@example.org'}

  Scenario: Changes not sent yet block the deletion
    Given nobody is signed in on the device
    And {'coach@example.org'} is a {'teacher'} of the club {'Test club'}
    And {'coach@example.org'} is signed in on the device
    And the app is running
    And a change waits to be sent to the server
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And I enter {'correct-horse-battery'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Some changes made on this device have not been sent yet. Go back online, wait until they are sent, then try again. Nothing has been deleted.'} text
    And the member {'coach@example.org'} of the club {'Test club'} has the role {'teacher'}

  Scenario: Interrupted after the club data, the deletion resumes safely
    Given nobody is signed in on the device
    And {'coach@example.org'} is a {'teacher'} of the club {'Test club'}
    And {'coach@example.org'} left an import marker in the club {'Test club'}
    And {'coach@example.org'} is signed in on the device
    And the app is running
    And the connection will drop just before the account itself is deleted
    When I tap {'More'} text
    And I tap {'Delete my account'} text
    And I enter {'correct-horse-battery'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Your club data has been removed, but the account itself could not be deleted: no connection. Try again once you are online.'} text
    And no member exists for {'coach@example.org'} in the club {'Test club'}
    And {'coach@example.org'} has no marker left in the club {'Test club'}
    And an account exists for {'coach@example.org'}
    When I tap {'Delete my account permanently'} text
    Then I see {'Sign in to the app'} text
    And no account exists for {'coach@example.org'}

  Scenario: An account without any club can delete itself
    Given nobody is signed in on the device
    And the account {'lonely@example.org'} exists with the password {'correct-horse-battery'}
    And {'lonely@example.org'} is signed in on the device
    And the app is running
    Then I see {'No club'} text
    When I tap {'Delete my account'} text
    And I enter {'correct-horse-battery'} into {0} input field
    And I tap {'Delete my account permanently'} text
    Then I see {'Sign in to the app'} text
    And no account exists for {'lonely@example.org'}

  Scenario: The deletion screen is in French on a French device
    Given the device language is {'fr'}
    And the app is running
    When I tap {'Plus'} text
    And I tap {'Supprimer mon compte'} text
    Then I see {'Supprimer définitivement mon compte'} text
