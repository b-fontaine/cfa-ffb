# Lot FB2 (ADR 0024, décisions 22, 24 et 31) : aucune route sans compte,
# connexion par e-mail et mot de passe, adresse vérifiée exigée, messages
# génériques (anti-énumération), choix du club actif. Les scénarios des autres
# fichiers s'exécutent connectés (compte de l'animateur, un seul club : voir
# UiWorld). Le texte par défaut est l'anglais ; « Aujourd'hui » est le lundi
# 12 octobre 2026.
#
# Ce que prouvent les scénarios d'échec de connexion : le message affiché pour
# `invalidCredentials`. Ils tournent sur le double en mémoire, pas sur Firebase :
# l'anti-énumération de l'implémentation réelle (mêmes échecs pour « mauvais mot
# de passe » et « adresse inconnue ») est gardée par la suite de contrat
# `auth_repository_contract_test.dart`, exécutée sur les deux implémentations.
Feature: Account access

  Scenario: A verified account signs in and the app opens
    Given nobody is signed in on the device
    And the account {'coach@example.org'} exists with the password {'correct-horse-battery'}
    And {'coach@example.org'} is a {'director'} of the club {'Club Nice'}
    And the app is running
    Then I see {'Sign in to the app'} text
    When I enter {'coach@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'Plan the next session'} text
    And the address is {'/'}

  Scenario: A wrong password gives a generic message
    Given nobody is signed in on the device
    And the account {'coach@example.org'} exists with the password {'correct-horse-battery'}
    And the app is running
    When I enter {'coach@example.org'} into {0} input field
    And I enter {'not-the-password'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'Incorrect e-mail address or password.'} text
    And I see {'Sign in to the app'} text

  Scenario: An unknown address gets the very same message
    Given nobody is signed in on the device
    And the app is running
    When I enter {'nobody@example.org'} into {0} input field
    And I enter {'whatever-password'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'Incorrect e-mail address or password.'} text

  Scenario: A malformed address is refused before any request
    Given nobody is signed in on the device
    And the app is running
    When I enter {'not an address'} into {0} input field
    And I enter {'whatever-password'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'Enter a valid e-mail address.'} text

  Scenario: An address that is not verified cannot enter
    Given nobody is signed in on the device
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'} but is not verified
    And the app is running
    When I enter {'new@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'Your e-mail address is not verified yet. Open the link you received by e-mail, then sign in.'} text
    And I see {'Sign in to the app'} text
    And I see {'Resend the verification e-mail'} text

  Scenario: The verification e-mail can be sent again
    Given nobody is signed in on the device
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'} but is not verified
    And the app is running
    When I enter {'new@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    And I tap {'Resend the verification e-mail'} text
    Then I see {'A verification e-mail has just been sent. Open the link it contains, then sign in.'} text
    And a verification e-mail was sent to {'new@example.org'}

  Scenario: A forgotten password sends a reset e-mail
    Given nobody is signed in on the device
    And the account {'coach@example.org'} exists with the password {'correct-horse-battery'}
    And the app is running
    When I tap {'Forgot your password?'} text
    And I enter {'coach@example.org'} into {0} input field
    And I tap {'Send the link'} text
    Then I see {'If an account exists for this address, a reset e-mail has just been sent.'} text
    And a reset e-mail was sent to {'coach@example.org'}

  Scenario: An unknown address gets the same confirmation and no e-mail
    Given nobody is signed in on the device
    And the app is running
    When I tap {'Forgot your password?'} text
    And I enter {'nobody@example.org'} into {0} input field
    And I tap {'Send the link'} text
    Then I see {'If an account exists for this address, a reset e-mail has just been sent.'} text
    And no reset e-mail was sent

  Scenario: Signing out leads back to the sign-in screen
    Given the app is running
    When I tap {'More'} text
    And I tap {'Sign out'} text
    Then I see {'Sign in to the app'} text
    And no club is remembered for {'animateur@example.org'}

  Scenario: A protected address is not reachable without an account
    Given nobody is signed in on the device
    And the app is running
    When I go to the address {'/backup'}
    Then I see {'Sign in to the app'} text
    When I go to the address {'/exercises/puissance/1'}
    Then I see {'Sign in to the app'} text

  Scenario: The requested address is opened after signing in
    Given nobody is signed in on the device
    And the account {'coach@example.org'} exists with the password {'correct-horse-battery'}
    And {'coach@example.org'} is a {'director'} of the club {'Club Nice'}
    And the app is running
    When I go to the address {'/backup'}
    And I enter {'coach@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then the address is {'/backup'}

  Scenario: The sign-in screen is displayed in French on a French device
    Given the device language is {'fr'}
    And nobody is signed in on the device
    And the app is running
    Then I see {'Connexion à l’application'} text
    And I see {'Se connecter'} text
    And I see {'Mot de passe oublié ?'} text

  Scenario: A session persisted on the device opens straight on the app
    Given the app is running
    Then I see {'Plan the next session'} text
    When I relaunch the app
    Then I see {'Plan the next session'} text

  Scenario: An account in several clubs chooses the active club
    Given nobody is signed in on the device
    And the account {'coach@example.org'} exists with the password {'correct-horse-battery'}
    And {'coach@example.org'} is a {'director'} of the club {'Club Nice'}
    And {'coach@example.org'} is a {'teacher'} of the club {'Club Lyon'}
    And the app is running
    When I enter {'coach@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'Choose a club'} text
    And I see {'Club Nice'} text
    And I see {'Club Lyon'} text
    When I tap {'Club Lyon'} text
    Then I see {'Plan the next session'} text
    And the remembered club of {'coach@example.org'} is {'Club Lyon'}

  Scenario: The remembered club opens without asking again
    Given {'coach@example.org'} is a {'director'} of the club {'Club Nice'}
    And {'coach@example.org'} is a {'teacher'} of the club {'Club Lyon'}
    And the club {'Club Lyon'} is remembered for {'coach@example.org'} on the device
    And {'coach@example.org'} is signed in on the device
    And the app is running
    Then I see {'Plan the next session'} text
    And I do not see {'Choose a club'} text

  Scenario: The club can be switched from More
    Given {'animateur@example.org'} is a {'teacher'} of the club {'Club Lyon'}
    And the club {'Test club'} is remembered for {'animateur@example.org'} on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'Switch club'} text
    Then I see {'Director · Active club'} text
    When I tap {'Club Lyon'} text
    Then I see {'Plan the next session'} text
    And the remembered club of {'animateur@example.org'} is {'Club Lyon'}

  Scenario: A guided session in progress forbids switching club
    Given {'animateur@example.org'} is a {'teacher'} of the club {'Club Lyon'}
    And the club {'Test club'} is remembered for {'animateur@example.org'} on the device
    And the app is running
    When I go to the address {'/catalogue/posture-1/guide?audience=children&step=5'}
    And I count {2} successes on the initiation
    And I go to the address {'/more/club'}
    Then I see {'Finish or leave the current session before switching club.'} text
    When I tap {'Club Lyon'} text
    Then the remembered club of {'animateur@example.org'} is {'Test club'}

  Scenario: An account without any club is told so
    Given nobody is signed in on the device
    And the account {'lonely@example.org'} exists with the password {'correct-horse-battery'}
    And the app is running
    When I enter {'lonely@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'No club'} text
    And I see {'Your account is not attached to any club. Ask your club for an invitation, then refresh this screen.'} text

  Scenario: The service being unavailable is shown with a retry
    Given the account service is unavailable
    And the app is running
    Then I see {'Service unavailable'} text
    When the account service is available again
    And I tap {'Retry'} text
    Then I see {'Plan the next session'} text

  Scenario: A device already signed in opens offline on its remembered club
    Given the club {'Test club'} is remembered for {'animateur@example.org'} on the device
    And the clubs of the account cannot be read
    And the app is running
    Then I see {'Plan the next session'} text

  Scenario: Without a remembered club, unreadable clubs mean unavailable
    Given the clubs of the account cannot be read
    And nobody is signed in on the device
    And the account {'coach@example.org'} exists with the password {'correct-horse-battery'}
    And {'coach@example.org'} is a {'director'} of the club {'Club Nice'}
    And the app is running
    When I enter {'coach@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'Service unavailable'} text

  Scenario: Sign-up needs an invitation code and creates only the account
    Given nobody is signed in on the device
    And the app is running
    When I tap {'I have an invitation code'} text
    And I enter {'ABCD-EFGH-JKMN'} into {0} input field
    And I enter {'new@example.org'} into {1} input field
    And I enter {'long-enough-password'} into {2} input field
    And I tap {'Create my account'} text
    Then I see {'Account created. Open the link in the verification e-mail, then sign in.'} text
    And an account exists for {'new@example.org'}
    And a verification e-mail was sent to {'new@example.org'}
    And the invitation code {'ABCDEFGHJKMN'} is kept for {'new@example.org'}

  Scenario: A short password is refused at sign-up
    Given nobody is signed in on the device
    And the app is running
    When I tap {'I have an invitation code'} text
    And I enter {'ABCDEFGHJKMN'} into {0} input field
    And I enter {'new@example.org'} into {1} input field
    And I enter {'short'} into {2} input field
    And I tap {'Create my account'} text
    Then I see {'The password must be at least 10 characters long.'} text
    And no account exists for {'new@example.org'}

  Scenario: A password of exactly 10 characters is accepted at sign-up
    Given nobody is signed in on the device
    And the app is running
    When I tap {'I have an invitation code'} text
    And I enter {'ABCDEFGHJKMN'} into {0} input field
    And I enter {'new@example.org'} into {1} input field
    And I enter {'0123456789'} into {2} input field
    And I tap {'Create my account'} text
    Then I see {'Account created. Open the link in the verification e-mail, then sign in.'} text
    And an account exists for {'new@example.org'}

  Scenario: A malformed invitation code is refused at sign-up
    Given nobody is signed in on the device
    And the app is running
    When I tap {'I have an invitation code'} text
    And I enter {'1234'} into {0} input field
    And I enter {'new@example.org'} into {1} input field
    And I enter {'long-enough-password'} into {2} input field
    And I tap {'Create my account'} text
    Then I see {'The invitation code does not have the expected shape: at least 10 characters, letters A to Z and digits 2 to 7.'} text
    And no account exists for {'new@example.org'}
