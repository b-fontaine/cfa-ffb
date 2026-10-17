# Lot FB3 (ADR 0024, décisions 6, 14, 16, 24 et 25) : clubs, rôles, invitations.
# Inscription fermée : un code d'invitation lié à un rôle, un club et des groupes
# ou une fiche ; usage unique, expiration (7 jours, 48 heures pour un enseignant
# ou un directeur), révocable. Navigation et actions filtrées par rôle, le garde
# de route refuse ce que le menu ne montre pas. Le texte par défaut est
# l'anglais ; « Aujourd'hui » est le lundi 12 octobre 2026, 9 h 30.
#
# Ce que prouvent ces scénarios : le comportement de l'application sur des
# dépôts qui parlent à un double en mémoire du stock de documents. Ils ne
# prouvent PAS les règles de sécurité du serveur (qui refusent, elles, ce que
# l'interface ne propose pas) : celles-ci sont testées contre l'émulateur
# Firestore par scripts/rules_test/. Les scénarios s'exécutent connectés comme
# l'animateur par défaut (directeur du club « Test club », voir UiWorld) tant
# qu'une étape ne connecte pas un autre compte.
Feature: Clubs, roles and invitations

  Scenario: The director invites a teacher and copies the code
    Given the clipboard is available
    And the app is running
    When I tap {'More'} text
    And I tap {'My club'} text
    And I tap {'Invite someone'} text
    And I tap {'Teacher'} text
    And I tap {'Create the invitation'} text
    Then I see {'Invitation code'} text
    And I see an invitation code of {12} characters
    And I see {'Valid until Oct 14, 2026 09:30'} text
    When I tap {'Copy the code'} text
    Then the clipboard holds the invitation code
    And the invitation code is stored for the role {'teacher'} in the club {'Test club'}

  Scenario: An invitation for a student or a parent is valid for seven days
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'More'} text
    And I tap {'My club'} text
    And I tap {'Invite someone'} text
    And I tap {'Parent'} text
    And I tap {'Léa · Children group'} text
    And I tap {'Create the invitation'} text
    Then I see {'Valid until Oct 19, 2026 09:30'} text
    And the invitation code is stored for the role {'guardian'} in the club {'Test club'}
    And the invitation code concerns the student {'Léa'}

  Scenario: A teacher invites a student of their own group and sees no other group
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Marc'} in the {'adults'} audience
    And {'sophie@example.org'} is a {'teacher'} of the club {'Test club'} for the group {'Children group'}
    And {'sophie@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'My club'} text
    And I tap {'Invite someone'} text
    Then I do not see {'Teacher'} text
    When I tap {'Student'} text
    Then I see {'Léa · Children group'} text
    And I do not see {'Marc · Adults group'} text
    When I tap {'Léa · Children group'} text
    And I tap {'This student is 15 or older'} text
    And I tap {'Create the invitation'} text
    Then I see {'Invitation code'} text
    And the invitation code is stored for the role {'student'} in the club {'Test club'}
    And the invitation code concerns the student {'Léa'}

  Scenario: An invitation for a student asks to confirm the age
    Given the club has the student {'Léa'} in the {'children'} audience
    And the app is running
    When I tap {'More'} text
    And I tap {'My club'} text
    And I tap {'Invite someone'} text
    And I tap {'Student'} text
    And I tap {'Léa · Children group'} text
    And I tap {'Create the invitation'} text
    Then I see {'Confirm that this student is 15 or older, or invite a parent instead.'} text
    And I do not see {'Invitation code'} text

  Scenario: A teacher only sees the actions of a teacher
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'sophie@example.org'} is a {'teacher'} of the club {'Test club'} for the group {'Children group'}
    And {'sophie@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    And I tap {'My club'} text
    Then I see {'Invite someone'} text
    And I do not see {'Team and families'} text
    And I do not see {'Rename the club'} text

  Scenario: A teacher cannot open the settings, the seasons or the administration
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'sophie@example.org'} is a {'teacher'} of the club {'Test club'} for the group {'Children group'}
    And {'sophie@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    Then I do not see {'Settings'} text
    And I do not see {'Administration'} text
    When I go to the address {'/settings'}
    Then the address is {'/'}
    When I go to the address {'/administration'}
    Then the address is {'/'}

  Scenario: A student only sees their own progress
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Marc'} in the {'children'} audience
    And {'lea@example.org'} is a {'student'} of the club {'Test club'} for the student {'Léa'}
    And {'lea@example.org'} is signed in on the device
    And the app is running
    Then I see {'Léa'} text
    And I do not see {'Marc'} text
    And I do not see {'Students'} text
    And I do not see {'Plan the next session'} text
    When I go to the address {'/students'}
    Then the address is {'/my-children'}
    When I go to the address {'/club'}
    Then the address is {'/my-children'}
    When I tap {'More'} text
    Then I do not see {'My club'} text
    And I do not see {'Administration'} text
    And I do not see {'Settings'} text

  Scenario: A student cannot open the progress of another student
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Marc'} in the {'children'} audience
    And {'lea@example.org'} is a {'student'} of the club {'Test club'} for the student {'Léa'}
    And {'lea@example.org'} is signed in on the device
    And the app is running
    When I go to the address of the showcase of {'Marc'}
    Then the address is {'/my-children'}
    When I go to the address of the showcase of {'Léa'}
    Then the address is the showcase of {'Léa'}

  Scenario: A parent joins with an invitation code and sees only their child
    Given the club has the student {'Léa'} in the {'children'} audience
    And the club has the student {'Marc'} in the {'children'} audience
    And the invitation {'GUARDIANCODE'} invites a {'guardian'} to the club {'Test club'} for the student {'Léa'}
    And nobody is signed in on the device
    And the account {'parent@example.org'} exists with the password {'correct-horse-battery'}
    And the app is running
    When I enter {'parent@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'No club'} text
    When I tap {'I have an invitation code'} text
    And I enter {'guardian-code'} into {0} input field
    And I enter {'Camille'} into {1} input field
    And I tap {'Join the club'} text
    Then I see {'Léa'} text
    And I do not see {'Marc'} text
    And I do not see {'Students'} text
    And the member {'parent@example.org'} of the club {'Test club'} has the role {'guardian'}
    And the invitation {'GUARDIANCODE'} is used

  Scenario: An invitation link opens the sign-up with the code filled in
    Given nobody is signed in on the device
    And the app is running
    When I go to the address {'/join/ABCDEFGHJKMN'}
    Then I see {'Sign up with an invitation'} text
    And I see {'ABCDEFGHJKMN'} text

  Scenario: A cold start on an invitation link opens the sign-up with the code filled in
    Given nobody is signed in on the device
    When the app is opened on the address {'/join/ABCDEFGHJKMN'}
    Then I see {'Sign up with an invitation'} text
    And I see {'ABCDEFGHJKMN'} text
    And the address is {'/register?code=ABCDEFGHJKMN'}

  Scenario: A cold start on an invitation link offers the invitation to an account without club
    Given the invitation {'TEACHERCODE'} invites a {'teacher'} to the club {'Test club'} for no group
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'}
    And {'new@example.org'} is signed in on the device
    When the app is opened on the address {'/join/TEACHERCODE'}
    Then I see {'Join a club'} text
    And I see {'TEACHERCODE'} text
    And the address is {'/join/TEACHERCODE'}

  Scenario: An account that is already signed in is offered the invitation of the link
    Given the invitation {'TEACHERCODE'} invites a {'teacher'} to the club {'Test club'} for no group
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'}
    And {'new@example.org'} is signed in on the device
    And the app is running
    Then I see {'No club'} text
    When I go to the address {'/join/TEACHERCODE'}
    Then I see {'Join a club'} text
    And I see {'TEACHERCODE'} text
    When I enter {'Sophie'} into {1} input field
    And I tap {'Join the club'} text
    Then I see {'Plan the next session'} text
    And the member {'new@example.org'} of the club {'Test club'} has the role {'teacher'}

  Scenario: The code kept at sign-up is offered after the first sign-in
    Given the invitation {'TEACHERCODE'} invites a {'teacher'} to the club {'Test club'} for no group
    And nobody is signed in on the device
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'}
    And the invitation code {'TEACHERCODE'} is held for {'new@example.org'}
    And the app is running
    When I enter {'new@example.org'} into {0} input field
    And I enter {'correct-horse-battery'} into {1} input field
    And I tap {'Sign in'} text
    Then I see {'Join a club'} text
    And I see {'TEACHERCODE'} text
    When I enter {'Sophie'} into {1} input field
    And I tap {'Join the club'} text
    Then I see {'Plan the next session'} text
    And the member {'new@example.org'} of the club {'Test club'} has the role {'teacher'}
    And no invitation code is held for {'new@example.org'}

  Scenario: An expired code is refused
    Given the invitation {'EXPIREDCODE'} invites a {'teacher'} to the club {'Test club'} for no group and expired on {'2026-10-10'}
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'}
    And {'new@example.org'} is signed in on the device
    And the app is running
    When I go to the address {'/join/EXPIREDCODE'}
    And I enter {'Sophie'} into {1} input field
    And I tap {'Join the club'} text
    Then I see {'This invitation has expired. Ask for a new one.'} text
    And no member exists for {'new@example.org'} in the club {'Test club'}

  Scenario: A code that was already used is refused
    Given the invitation {'USEDCODEUSED'} invites a {'teacher'} to the club {'Test club'} for no group and was already used
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'}
    And {'new@example.org'} is signed in on the device
    And the app is running
    When I go to the address {'/join/USEDCODEUSED'}
    And I enter {'Sophie'} into {1} input field
    And I tap {'Join the club'} text
    Then I see {'This invitation has already been used.'} text
    And no member exists for {'new@example.org'} in the club {'Test club'}

  Scenario: An unknown code is refused
    Given the account {'new@example.org'} exists with the password {'correct-horse-battery'}
    And {'new@example.org'} is signed in on the device
    And the app is running
    When I go to the address {'/join/UNKNOWNCODE2'}
    And I enter {'Sophie'} into {1} input field
    And I tap {'Join the club'} text
    Then I see {'This code does not exist. Check it and try again.'} text
    And no member exists for {'new@example.org'} in the club {'Test club'}

  Scenario: The name shown to the team is required
    Given the invitation {'TEACHERCODE'} invites a {'teacher'} to the club {'Test club'} for no group
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'}
    And {'new@example.org'} is signed in on the device
    And the app is running
    When I go to the address {'/join/TEACHERCODE'}
    And I tap {'Join the club'} text
    Then I see {'Enter your name (40 characters at most).'} text
    And no member exists for {'new@example.org'} in the club {'Test club'}

  Scenario: The director revokes an invitation sent from this device
    Given the app is running
    When I tap {'More'} text
    And I tap {'My club'} text
    And I tap {'Invite someone'} text
    And I tap {'Teacher'} text
    And I tap {'Create the invitation'} text
    And I tap {'Back to My club'} text
    Then I see {'Teacher · Waiting'} text
    When I tap {'Revoke'} text
    Then I do not see {'Teacher · Waiting'} text
    And the invitation code no longer exists

  Scenario: The director removes the access of a teacher
    Given the club has the student {'Léa'} in the {'children'} audience
    And {'sophie@example.org'} is a {'teacher'} of the club {'Test club'} for the group {'Children group'}
    And the app is running
    When I tap {'More'} text
    And I tap {'My club'} text
    Then I see {'sophie'} text
    When I tap {'Remove access'} text
    And I tap {'Remove'} text
    Then I do not see {'sophie'} text
    And no member exists for {'sophie@example.org'} in the club {'Test club'}

  Scenario: The director renames the club
    Given the app is running
    When I tap {'More'} text
    And I tap {'My club'} text
    And I tap {'Rename the club'} text
    And I enter {'Club Lyon'} into {0} input field
    And I tap {'Save'} text
    Then I see {'Club Lyon'} text
    And the club {'Test club'} is named {'Club Lyon'}

  Scenario: An administrator with no club yet creates the first club and invites its director
    Given the platform has no club yet
    And nobody is signed in on the device
    And {'root@example.org'} is an administrator
    And {'root@example.org'} is signed in on the device
    And the app is running
    Then I see {'No club'} text
    When I tap {'Administration'} text
    And I tap {'Create a club'} text
    And I enter {'Club Nice'} into {0} input field
    And I tap {'Create'} text
    Then I see {'Club Nice'} text
    When I tap {'Invite a director'} text
    Then I see {'Invitation code'} text
    And I see {'Valid until Oct 14, 2026 09:30'} text
    And the invitation code is stored for the role {'director'} in the club {'Club Nice'}

  Scenario: An administrator reaches the administration from any club
    Given {'root@example.org'} is an administrator
    And {'root@example.org'} is signed in on the device
    And the app is running
    When I tap {'More'} text
    Then I see {'Administration'} text
    And I see {'My club'} text

  Scenario: The director invited by an administrator joins the new club
    Given the platform has no club yet
    And the club {'Club Nice'} exists
    And the invitation {'DIRECTORCODE'} invites a {'director'} to the club {'Club Nice'} for no group
    And nobody is signed in on the device
    And the account {'new@example.org'} exists with the password {'correct-horse-battery'}
    And {'new@example.org'} is signed in on the device
    And the app is running
    When I go to the address {'/join/DIRECTORCODE'}
    And I enter {'Nadia'} into {1} input field
    And I tap {'Join the club'} text
    Then I see {'Plan the next session'} text
    And the member {'new@example.org'} of the club {'Club Nice'} has the role {'director'}
    When I tap {'More'} text
    Then I see {'My club'} text
    And I do not see {'Administration'} text

  Scenario: The club screens are available in French
    Given the device language is {'fr'}
    And the app is running
    When I tap {'Plus'} text
    And I tap {'Mon club'} text
    Then I see {'Inviter quelqu’un'} text
    And I see {'Équipe et familles'} text
