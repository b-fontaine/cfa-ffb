# Registre des traitements — projet à valider par la fédération ou un DPO

Registre au sens de l'article 30 du RGPD, modèle pour un club. Statut : **projet, non validé** (2026-10-17). Voir [README](README.md), [ADR 0025](../adr/0025-comptes-et-donnees-de-mineurs-conformite.md).

## Identification

| Champ | Valeur |
|---|---|
| Responsable de traitement | `[nom du club, adresse]` (ou `[fédération ou comité]` si elle porte le rôle) |
| Représentant et contact | `[nom, e-mail]` |
| DPO | `[nom, ou « non désigné »]` |
| Sous-traitant | `[éditeur de l'application : nom, adresse]` |
| Sous-traitant ultérieur | Google LLC / Google Cloud EMEA Limited (Firebase) |
| Date de validation | `[à renseigner par le validateur]` |

## Traitement 1 — Suivi pédagogique des élèves

| Rubrique | Contenu |
|---|---|
| Finalité | Préparer et adapter les séances de billard (Blackball, niveau 1) ; suivre les résultats d'exercices des élèves de la saison |
| Base légale | `[Prop]` intérêt légitime du club (suivi pédagogique) ou exécution du contrat d'adhésion ; **à valider par le DPO**. Compte propre d'un élève de 15 ans et plus : il s'inscrit lui-même ; sous 15 ans, accès par le parent |
| Personnes | Élèves mineurs et adultes du club |
| Données | Prénom + initiale du nom (bornées : prénom de 40 caractères au plus, initiale d'une seule lettre) ; public (enfants, adultes) ; **dès le lot FB3, une copie minimale de la fiche (prénom, public, groupes courants) est publiée sur le serveur à la première invitation d'un élève ou d'un parent** (les autres données restent locales jusqu'au lot FB4) ; appartenance à des groupes datés ; présences ; passages et résultats d'exercices ; acquittements d'alertes ; étiquettes de séance (liste fermée, non nominatives) ; **commentaire d'évaluation** (`MaturityAssessment.comment`, texte libre facultatif, borné à `maxCommentLength`, conservé). **Exclus** : date de naissance, santé, photo, coordonnées de l'élève, tout autre texte libre (la note de jeu est sans texte libre, ADR 0023) |
| Catégories particulières | Aucune |
| Destinataires | Enseignants des groupes de l'élève ; directeur du club ; **administrateurs de l'éditeur (un à deux comptes, accès à tous les clubs, y compris aux prénoms de mineurs)** ; parent ou élève (fiche en parcours et séances planifiées seulement) ; Google (hébergement) |
| Transferts hors UE | Firestore : `europe-west9` (France), pas de transfert. **Auth : traité aux États-Unis** (e-mail des adultes) : DPF et clauses contractuelles types de Google ; `[garanties de transfert à valider par le DPO]` |
| Durée de conservation | Saison en cours + saison suivante, puis effacement ; effacement à la demande à tout moment. `[Durée proposée, à valider par le DPO]` |
| Sécurité | Règles Firestore par rôle et par club, refus par défaut, testées contre l'émulateur ; e-mail vérifié, mot de passe de 10 caractères au moins ; App Check ; HTTPS ; chiffrement au repos Google ; cache hors ligne vidé à la déconnexion ; commentaire d'évaluation borné en longueur |
| Risque propre | Le commentaire d'évaluation est un **texte libre sur un mineur** : il peut contenir des informations non prévues ; signalé à l'AIPD (R11), consigne aux animateurs de n'y porter aucune donnée de santé ni d'identité d'un tiers |

## Traitement 2 — Comptes des adultes (parents, enseignants, directeurs, administrateurs) et invitations

| Rubrique | Contenu |
|---|---|
| Finalité | Authentifier les utilisateurs, appliquer les droits par rôle et par club, inviter les membres |
| Base légale | `[Prop]` intérêt légitime du club (accès sécurisé au service) ; **à valider par le DPO** |
| Données | Adresse e-mail, mot de passe (haché par Google), identifiant de compte, rôle par club, lien avec une ou plusieurs fiches élèves (parent), adresses IP et agent utilisateur traités par Google Auth ; **ajoutées par le lot FB3** : le **nom affiché** que l'invité saisit à l'inscription (40 caractères au plus, visible de l'équipe du club), le document `members` (rôle, groupes, fiches liées, date de rattachement, **code d'invitation utilisé**), le document d'invitation (code Base32, rôle, club, groupes ou fiches liées, identifiant du créateur, dates de création et d'expiration, état « utilisée » et identifiant de l'utilisateur), un **journal local des codes émis** sur l'appareil de l'inviteur (jamais envoyé au serveur, effacé à la déconnexion), le code gardé sur l'appareil entre l'inscription et la première connexion |
| Destinataires | Directeur du club (liste des membres : nom affiché et rôle) ; administrateurs (tous les clubs, y compris les listes de membres) ; Google (Auth, Firestore). **Un enseignant, un élève ou un parent ne lit que son propre `member`** (règles Firestore, testées) |
| Transferts hors UE | **Auth : États-Unis** (DPF, clauses contractuelles types) ; `[garanties de transfert à valider par le DPO]` |
| Durée de conservation | Parent : fin de la saison suivante du dernier enfant lié ; enseignant et directeur : 12 mois après le dernier rattachement ; invitation : purgée à la clôture de saison (validité 7 jours, 48 h pour un enseignant) ; compte supprimé : sauvegardes Google purgées sous 180 jours. **Durées proposées, à valider** |
| Sécurité | Inscription fermée par code d'invitation à usage unique (10 caractères Base32), e-mail vérifié, App Check, MFA directeur et administrateur à étudier |

## Traitement 3 — Protection technique du service (App Check, reCAPTCHA)

| Rubrique | Contenu |
|---|---|
| Finalité | Réserver les appels à Firebase à l'application authentique |
| Données | Jeton d'attestation (7 jours au plus), adresse IP vue par reCAPTCHA sur web (destinataire : Google) |
| Destinataires | Google |
| Durée | Jetons de 7 jours au plus (source Firebase) ; durée de reCAPTCHA **non vérifiée** : `[à valider par le DPO]` |

## Traitement 3 bis — Sonde de connectivité du SDK Firestore web

| Rubrique | Contenu |
|---|---|
| Constat | Le SDK web de Firestore (WebChannel) charge une image de sonde `https://www.google.com/images/cleardot.gif` pour tester la connectivité (observé le 2026-10-17 dans le build web compilé, `scripts/web_smoke.sh`) |
| Données | Adresse IP et agent utilisateur du navigateur, vus par Google ; aucune donnée du club |
| Destinataire | Google |
| Mesure | Aucune : appel fait par le SDK, non désactivable par un paramètre documenté ; à lister aux destinataires de la notice et à l'AIPD `[à valider par le DPO]` |

## Traitement 4 — Cache local hors ligne et sauvegardes JSON

| Rubrique | Contenu |
|---|---|
| Finalité | Usage en salle sans réseau ; portabilité des données du club |
| Données | Copie locale des données du club accessibles à l'utilisateur (IndexedDB du navigateur sur web, stockage de l'appareil sur mobile) ; fichier JSON de sauvegarde (nominatif) |
| Risque | Données en clair sur un appareil partagé ; fichiers exportés hors de portée de l'effacement |
| Mesures | Vidage du cache à la déconnexion ; avertissement « appareil partagé » ; sauvegarde automatique Android et iCloud désactivées ; avertissement sur le contenu nominatif de l'export |

## Exercice des droits

Voir [procedure-droits-et-effacement.md](procedure-droits-et-effacement.md). Délai de réponse : un mois.

## Violations de données

`[À compléter par le responsable : qui prévient la CNIL sous 72 heures, qui informe les familles, journal des incidents.]` L'éditeur prévient le club sans délai dès qu'il en a connaissance.
