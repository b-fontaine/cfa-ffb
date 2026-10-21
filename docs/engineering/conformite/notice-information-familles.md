# Notice d'information des familles — projet à valider par la fédération ou un DPO

Statut : **projet, non validé** (2026-10-17). À remettre aux familles **avant** l'invitation d'un parent ou d'un élève, puis rappelée à la première connexion. Les champs `[…]` sont à remplir par le club. Section française, puis section anglaise (même contenu, même statut).

---

## Français

### Qui traite vos données ?

`[Nom du club]`, `[adresse]` (le « club »), responsable du traitement. Contact : `[e-mail]`. Délégué à la protection des données : `[nom ou « non désigné »]`. L'application est fournie par `[éditeur]`, qui agit pour le compte du club (sous-traitant). L'hébergement est assuré par Google (Firebase).

### Pourquoi ?

Pour préparer les séances de billard (Blackball) et suivre les progrès de chaque élève au fil de la saison : exercices réussis, présences. Pas de publicité, pas de revente, pas de décision automatique.

### Base légale

`[À valider par le DPO : intérêt légitime du club pour le suivi pédagogique, ou exécution du contrat d'adhésion.]` `[À valider par le DPO : seuil de 15 ans (art. 45 loi Informatique et Libertés) et sa portée pour ce service. Dans l'application : un élève de 15 ans et plus peut créer son propre compte, avant 15 ans c'est un parent qui crée le compte.]`

### Quelles données ?

Pour un élève : prénom, initiale du nom, public (enfants ou adultes), groupes, présences, résultats d'exercices, étiquettes de séance (une liste fermée, sans nom), acquittements d'alertes par les animateurs (avec l'identifiant du compte de l'animateur) et un **commentaire d'évaluation** facultatif et court, écrit par l'enseignant. Nous ne collectons ni date de naissance, ni information de santé, ni photo. Pour un adulte : adresse e-mail, rôle dans le club, code d'invitation (rôle, club, expiration) et, pour un parent, le lien avec la fiche de son enfant. Le service de connexion de Google traite aussi l'adresse IP et le type d'appareil des adultes.

### Qui voit quoi ?

- **Vous (parent) ou votre enfant** : la fiche de progression de l'enfant et les prochaines séances des groupes de vos enfants. Pas les autres élèves. L'appareil reçoit toutefois plus que ce qu'il affiche (voir plus bas).
- **Les enseignants** : les élèves de leurs groupes. **Le directeur** : tout le club.
- **Les administrateurs de l'application** (un à deux comptes) peuvent techniquement lire les données de tous les clubs, y compris les prénoms d'élèves, pour l'assistance et la purge.
- **Google** (Firebase) héberge les données.

### Ce que montre l'espace famille *(texte de projet, à valider)*

Quand vous vous connectez en tant que parent, ou que votre enfant de 15 ans et plus se connecte, l'application ouvre directement l'espace famille, **en lecture seule** :

- le **prénom** et le **parcours** de votre enfant : les techniques, les exercices réussis, l'exercice en cours ; si vous avez plusieurs enfants, vous en choisissez un à la fois, et jamais deux ne s'affichent mélangés ;
- les **prochaines séances** (cinq au plus) des groupes de vos enfants : titre, jour et nom du groupe ;
- **rien d'autre à l'écran** : ni les autres élèves du groupe, ni les présences, ni les passages manqués, ni les alertes ou commentaires des animateurs, ni le bilan de l'enfant. Vous ne pouvez rien modifier : le parcours est mis à jour par l'animateur et s'affiche chez vous dès qu'il le saisit, sans recharger la page.

**Ce que votre appareil reçoit sans l'afficher.** Pour que l'écran fonctionne, l'appareil reçoit et garde en mémoire plus de données qu'il n'en montre :

- la **fiche complète de l'enfant**, alors que seul son prénom est affiché : son public (enfants ou adultes), l'historique daté de ses changements de public, ses groupes actuels et la date de création de la fiche ;
- **tous les passages** de l'enfant, réussis et manqués, avec leur date, leur séance et leur groupe (on peut en déduire à quelles séances l'enfant était présent) ;
- les **exercices acquis** de l'enfant, avec leur date et leur origine (par exemple « acquis par placement ») ;
- l'ensemble des **réglages du club** ;
- la **fiche de chaque groupe** de l'enfant, qui contient les identifiants de compte des enseignants du groupe (des données qui les concernent) ;
- **toutes les séances** de ces groupes, passées comprises, alors que seules les cinq prochaines sont affichées ;
- **votre propre fiche de membre** : votre nom affiché, votre rôle, vos groupes, les enfants qui vous sont liés et le code d'invitation que vous avez utilisé ;
- à la connexion : le **nom du club** et sa saison en cours, le fait que votre compte soit ou non celui d'un administrateur de l'application, et la liste de vos rattachements à des clubs.

**Les alertes.** Aucune alerte n'est enregistrée sur le serveur : l'appareil les **calcule lui-même** à partir des passages et des réglages reçus (par exemple « technique à revoir »). Ce calcul se fait même si l'écran ne les montre pas : une technique à revoir y apparaît simplement « en cours ». Seuls les « Vu » des animateurs (la mention qu'une alerte a été regardée) ne sont jamais reçus par votre appareil. Il ne reçoit pas non plus les autres élèves, ni les saisies de séance, ni les bilans.

*(Phrase à valider par la fédération ou un DPO.)*

Si le club retire votre accès, l'écran passe aussitôt à « Accès retiré » et n'affiche plus rien ; les données gardées sur l'appareil sont effacées à la déconnexion. Sans connexion, les dernières informations reçues restent visibles sur votre appareil, avec la mention « Hors ligne ».

### Où sont-elles ?

Les données de suivi sont hébergées en France (Paris, `europe-west9`). **Le service de connexion de Google (Firebase Authentication) traite les adresses e-mail aux États-Unis**, selon le cadre de protection des données UE-États-Unis et les clauses contractuelles types de Google `[garanties de transfert à valider par le DPO]`. Pour le web, la protection anti-abus (reCAPTCHA) transmet l'adresse IP à Google.

### Combien de temps ?

Élèves : la saison en cours et la saison suivante, puis effacement. Parents : jusqu'à la fin de la saison suivante du dernier enfant lié. Enseignants et directeurs : 12 mois après le dernier rattachement. Invitations : effacées à la clôture de saison. `[Durées à valider.]` **L'effacement est lancé par le directeur du club à la clôture de saison : il n'est pas automatique** ; un club qui tarde garde les données plus longtemps, d'où une alerte puis un blocage de la saisie. Vous pouvez demander l'effacement à tout moment.

### Vos droits

Accès (avec un export de la fiche de votre enfant), rectification, effacement, limitation, opposition. Écrivez à `[e-mail du club]` ; réponse sous un mois. En cas de désaccord, vous pouvez saisir la CNIL (cnil.fr).

### À savoir

- Les données peuvent être mémorisées sur l'appareil (cache hors ligne) ; elles sont effacées à la déconnexion. Évitez de rester connecté sur un appareil partagé.
- Les fichiers que le club exporte (sauvegarde, PDF) et les copies d'écran **ne sont pas effaçables par l'application**.
- Les comptes supprimés disparaissent des sauvegardes de Google sous 180 jours.
- **Reprise de l'historique d'un appareil** *(texte de projet, à valider)* : un animateur peut reprendre dans le club l'historique qu'il avait saisi sur son appareil avant la synchronisation, à partir d'un fichier de sauvegarde. Ce fichier **peut contenir des prénoms d'enfants et leurs résultats** ; il **quitte l'appareil** et son contenu est envoyé au club (serveur), comme toute saisie. L'application n'en garde pas de copie ; le fichier reste chez l'animateur, qui doit le conserver en lieu sûr puis le supprimer. Le club garde une trace technique de l'import (empreinte du fichier, nombre d'écritures, identifiant du compte de l'animateur, sans nom ni donnée d'enfant) pour qu'un même compte n'importe pas deux fois le même fichier (un autre compte le pourrait, mais n'écraserait aucune donnée déjà présente). **Conséquence** : si une fiche a été effacée du club entre-temps, un second import du même fichier par un autre compte peut la recréer, sous la même confirmation du nombre exact d'élèves rétablis.

---

## English

### Who processes your data?

`[Club name]`, `[address]` (the "club"), data controller. Contact: `[e-mail]`. Data protection officer: `[name or "none appointed"]`. The application is supplied by `[publisher]`, acting on the club's behalf (processor). Hosting is provided by Google (Firebase).

### Why?

To prepare billiards sessions (Blackball) and follow each student's progress over the season: exercises passed, attendance. No advertising, no resale, no automated decisions.

### Legal basis

`[To be validated by the DPO: the club's legitimate interest in following progress, or performance of the membership contract.]` `[To be validated by the DPO: the age threshold of 15 (art. 45 of the French Data Protection Act) and its scope for this service. In the application: a student aged 15 or over may create their own account, under 15 a parent creates the account.]`

### What data?

For a student: first name, initial of the surname, audience (children or adults), groups, attendance, exercise results, session labels (a closed list, with no names), alert acknowledgements by instructors (with the instructor's account identifier) and an optional, short **evaluation comment** written by the teacher. We do not collect date of birth, health information or photos. For an adult: e-mail address, role in the club, invitation code (role, club, expiry) and, for a parent, the link to their child's record. Google's sign-in service also processes adults' IP address and device type.

### Who sees what?

- **You (parent) or your child**: the child's progress record and the next sessions of your children's groups. No other students. The device does, however, receive more than it displays (see below).
- **Teachers**: the students in their groups. **The club director**: the whole club.
- **The application's administrators** (one or two accounts) can technically read the data of all clubs, including students' first names, for support and purging.
- **Google** (Firebase) hosts the data.

### What the family space shows *(draft text, to be validated)*

When you sign in as a parent, or your child aged 15 or over signs in, the application opens the family space directly, **read-only**:

- your child's **first name** and **progress**: the techniques, the exercises passed, the current exercise; with several children you pick one at a time, and two are never shown mixed together;
- the **next sessions** (five at most) of your children's groups: title, day and group name;
- **nothing else on screen**: no other students in the group, no attendance, no missed attempts, no instructor alerts or comments, no assessment of your child. You cannot change anything: the instructor updates the progress and it appears on your screen as soon as it is entered, without reloading the page.

**What your device receives without displaying it.** For the screen to work, the device receives and keeps in memory more data than it shows:

- the child's **full record**, although only the first name is displayed: their group type (children or adults), the dated history of changes to it, their current groups and the date the record was created;
- **every attempt** by the child, passed and missed, with its date, its session and its group (attendance at sessions can be inferred from them);
- the child's **acquired exercises**, with their date and origin (for example "acquired by placement");
- all of the club's **settings**;
- the **record of each of the child's groups**, which holds the account identifiers of the group's teachers (data about them);
- **all the sessions** of those groups, past ones included, although only the next five are displayed;
- **your own member record**: your display name, your role, your groups, the children linked to you and the invitation code you used;
- when you sign in: the **club's name** and its current season, whether or not your account is an administrator of the application, and the list of your club memberships.

**Alerts.** No alert is stored on the server: the device **works them out itself** from the attempts and settings it receives (for example "technique to review"). This calculation happens even though the screen does not show alerts: a technique to review simply appears "in progress". Only the instructors' "Seen" marks (the note that an alert has been looked at) are never received by your device. It does not receive other students, session entries or assessments either.

*(Sentence to be validated by the federation or a DPO.)*

If the club removes your access, the screen immediately changes to "Access removed" and shows nothing; the data kept on the device is erased at sign-out. Without a connection, the latest information received stays visible on your device, marked "Offline".

### Where is it?

Tracking data is hosted in France (Paris, `europe-west9`). **Google's sign-in service (Firebase Authentication) processes e-mail addresses in the United States**, under the EU-US Data Privacy Framework and Google's standard contractual clauses `[transfer safeguards to be validated by the DPO]`. On the web, abuse protection (reCAPTCHA) sends the IP address to Google.

### How long?

Students: the current season and the next one, then erasure. Parents: until the end of the season following their last linked child's. Teachers and directors: 12 months after their last club assignment. Invitations: erased at season closure. `[Durations to be validated.]` **Erasure is launched by the club director at season closure: it is not automatic**; a club that delays keeps the data longer, hence a warning and then a block on data entry. You can request erasure at any time.

### Your rights

Access (with an export of your child's record), rectification, erasure, restriction, objection. Write to `[club e-mail]`; reply within one month. If you disagree, you may complain to the CNIL (cnil.fr).

### Good to know

- Data may be kept on the device (offline cache); it is erased on sign-out. Do not stay signed in on a shared device.
- Files the club exports (backup, PDF) and screenshots **cannot be erased by the application**.
- Deleted accounts disappear from Google's backups within 180 days.
- **Moving the history of a device** *(draft text, to be validated)*: a coach can move into the club the history entered on their device before synchronisation, from a backup file. That file **may contain children's first names and their results**; it **leaves the device** and its content is sent to the club (server), like any entry. The app keeps no copy; the file stays with the coach, who must keep it safe and then delete it. The club keeps a technical trace of the import (file fingerprint, number of writes, the coach's account identifier, no name or child data) so that the same account does not import the same file twice (another account could, but would overwrite no data already present). **Consequence**: if a record was erased from the club in the meantime, a second import of the same file by another account may recreate it, under the same confirmation of the exact number of restored students.
