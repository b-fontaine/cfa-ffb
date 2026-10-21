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
| Données | Prénom + initiale du nom (bornées : prénom de 40 caractères au plus, initiale d'une seule lettre) ; public (enfants, adultes) ; **dès le lot FB3, une copie minimale de la fiche (prénom, public, groupes courants) est publiée sur le serveur à la première invitation d'un élève ou d'un parent** (les autres données restent locales jusqu'au lot FB4) ; appartenance à des groupes datés ; présences ; passages et résultats d'exercices ; acquittements d'alertes (**avec l'identifiant du compte de l'animateur qui l'a donné, `createdBy`, donnée personnelle d'animateur, FB4c, ADR 0024 B5 : « Vu » partagé par club**) ; étiquettes de séance (liste fermée, non nominatives) ; **commentaire d'évaluation** (`MaturityAssessment.comment`, texte libre facultatif, borné à `maxCommentLength`, conservé). **Exclus** : date de naissance, santé, photo, coordonnées de l'élève, tout autre texte libre (la note de jeu est sans texte libre, ADR 0023) |
| Catégories particulières | Aucune |
| Destinataires | Enseignants des groupes de l'élève ; directeur du club ; **administrateurs de l'éditeur (un à deux comptes, accès à tous les clubs, y compris aux prénoms de mineurs)** ; parent ou élève (sa fiche et les séances planifiées de ses groupes ; l'appareil reçoit davantage que ce qui est affiché : traitement 1 bis) ; Google (hébergement) |
| Transferts hors UE | Firestore : `europe-west9` (France), pas de transfert. **Auth : traité aux États-Unis** (e-mail des adultes) : DPF et clauses contractuelles types de Google ; `[garanties de transfert à valider par le DPO]` |
| Durée de conservation | Saison en cours + saison suivante, puis effacement ; effacement à la demande à tout moment. `[Durée proposée, à valider par le DPO]` |
| Sécurité | Règles Firestore par rôle et par club, refus par défaut, testées contre l'émulateur ; e-mail vérifié, mot de passe de 10 caractères au moins ; App Check ; HTTPS ; chiffrement au repos Google ; cache hors ligne vidé à la déconnexion ; commentaire d'évaluation borné en longueur |
| Risque propre | Le commentaire d'évaluation est un **texte libre sur un mineur** : il peut contenir des informations non prévues ; signalé à l'AIPD (R11), consigne aux animateurs de n'y porter aucune donnée de santé ni d'identité d'un tiers |

## Traitement 1 bis — Espace famille (consultation par un parent ou un élève de 15 ans et plus, lot FB6)

> Texte de projet, **à valider par le DPO** (2026-10-19). Aucune donnée nouvelle ni nouveau destinataire par rapport au traitement 1 : c'est la **vue** qu'en a un parent ou un élève.

| Rubrique | Contenu |
|---|---|
| Finalité | Permettre à un parent (ou à l'élève de 15 ans et plus) de suivre le parcours de son enfant et de connaître les prochaines séances de son groupe |
| Personnes | Parents et élèves de 15 ans et plus disposant d'un compte, liés à une ou plusieurs fiches (un parent d'un club peut avoir plusieurs enfants) |
| Données affichées (structure « affiché / reçu sans être affiché ») | **Affiché** : le **prénom** de l'élève lié (champ de sa fiche `students`) ; son **parcours** (techniques, exercices validés, exercice en cours, nombre de passages réussis) ; pour chacune des cinq prochaines séances planifiées de l'**union des groupes du compte** : **titre, jour, nom du groupe** (`FamilySpaceView` n'affiche rien d'autre : le public de la séance est reçu, non affiché). **Alerte « à revoir »** : jamais affichée comme alerte (une technique « à revoir » apparaît « en cours ») ; voir la ligne suivante |
| Données **jamais** lues | Autres élèves et **liste des camarades** (appartenances), saisies de séance, **« Vu »** (acquittements d'alertes) des animateurs, bilans de maturité et commentaires d'évaluation, étiquettes de séance, archives de saison, liste des membres |
| Données **reçues et mises en cache sans être affichées** (point de l'AIPD ; fait foi : `scripts/rules_test/family_reads.json`, **contrôlé** : `scripts/check_family_register.dart` échoue si un chemin de cette liste n'est pas nommé ici entre apostrophes inverses), champ par champ : **`attempts`** : **tous** les passages de la fiche liée, réussis **et manqués**, avec leur date, leur séance et leur groupe (billes réussies et total) ; la **présence aux séances s'en déduit** (non affichée, mais reçue) ; **`acquisitions`** : les blocs acquis de la fiche, avec leur **date** et leur **source** (`placement` : acquis par placement) ; **`students`** (document de la fiche liée **en entier**, dont seul le prénom est affiché) : le **public** (`audience`), l'**historique des changements de public, datés** (`audienceHistory`), les **groupes courants** (`groupIds`), la date de création (`createdAt`) ; **`settings/main`** : le document **en entier** ; **`groups`** : le document de **chaque groupe**, qui porte les identifiants de compte des enseignants (`teacherUids`, **données d'un tiers**) ; **`sessions`** : **toutes** les séances de ces groupes, passées comprises (cinq seulement affichées), avec leur public ; **`members`** (le propre document du compte) : nom affiché (`displayName`), rôle (`role`), groupes (`groupIds`), fiches liées (`studentIds`), **code d'invitation utilisé** (`invitationCode`) ; **alertes** : aucune alerte n'est stockée sur le serveur, elle est **calculée sur l'appareil** (`StudentProgress.derive` puis `techniqueSummary` produisent `BlockStatus.toReview`) à partir des passages (`attempts`) et de `settings/main` reçus, **même sans les « Vu »** ; elle n'est masquée qu'à l'affichage (une technique « à revoir » est montrée « en cours ») ; seuls les « Vu » ne sont jamais lus ; **lectures de connexion** : **`clubs/{club}`** (nom du club, `currentSeasonId`), **`admins/{uid}`** (existence seule : le compte est-il administrateur), et la requête de groupe **`members`** `uid=` (retrouver ses rattachements aux clubs) |
| Titre d'une séance | Texte saisi par l'animateur (borné) : il est visible de toutes les familles du groupe ; consigne aux animateurs de n'y porter aucun nom d'élève |
| Destinataires | Le seul compte lié (le parent ou l'élève) ; rien de plus que le traitement 1 |
| Lecture seule | Aucune écriture possible depuis cet espace : ni côté interface (aucun bouton, routes d'animateur refusées), ni côté serveur (règles : aucune écriture pour `student` ni `guardian`, hors son propre nom affiché) |
| Isolation | Les requêtes de l'espace sont limitées à la fiche liée et aux groupes du compte (liste exacte : `scripts/rules_test/family_reads.json`, jouée contre les règles et comparée au journal des demandes de l'application) |
| Retrait du lien | Si le club retire le lien, l'application le sait par l'écoute du lien du compte (le `member`) : l'écran passe en direct à « Accès retiré », ferme ses écoutes et n'affiche plus aucune donnée. Côté serveur, les règles refusent toute **nouvelle** lecture ; une écoute de données déjà ouverte n'est refusée qu'à la prochaine modification d'une séance ou du document de ce groupe (un renommage suffit), ou du document écouté (pas de coupure instantanée garantie sur un client modifié qui garderait son écoute). Le cache de l'appareil est vidé à la déconnexion. Retrait d'une seule fiche : cette fiche n'est plus lue, les autres restent affichées. Retrait d'un **groupe** seul : limite connue jusqu'à FB7 (le groupe reste servi à l'écoute ouverte, voir l'ADR 0024 notes FB6) |
| Hors ligne | Les dernières données reçues restent affichées (cache de l'appareil, traitement 4) avec la pastille « Hors ligne » ; vidées à la déconnexion |
| Journaux | Aucune donnée personnelle : les journaux techniques ne reçoivent que des codes (jamais prénom, e-mail, identifiant d'élève ou de compte) |
| Durée | Celle du traitement 1 (élèves) et du traitement 2 (compte du parent) |
| Choix technique à signaler | Le build par défaut lit Firestore pour **tous** les rôles dès son déploiement (lot de bascule du 2026-10-21, décision 28 amendée ; l'aiguillage par rôle a été écarté le 2026-10-19, ADR 0024 notes FB6). Ce qui protège les mineurs avant la validation de la conformité est la garde A3 (ADR 0025) : aucune invitation réelle, donc aucun compte élève ou parent réel, avant cette validation |

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
| État réel (FB5a, 2026-10-19) | **Persistance hors ligne activée explicitement** (IndexedDB, multi-onglets) ; le cache a **un compte propriétaire** : vidé avant lecture si un autre compte se connecte, et à la **déconnexion voulue** (avec confirmation si des envois sont en attente : ils seraient perdus) ; **conservé** si la session se perd autrement (jeton révoqué, autre onglet : des écritures hors ligne peuvent y être), jusqu'à la prochaine connexion d'un autre compte ; l'effacement (`terminate` puis `clearPersistence`) **abandonne le stockage sans le réécrire** (le SDK le précise) : les données ne sont plus lisibles par l'application, pas détruites cryptographiquement ; avertissement « appareil partagé » à l'écran de connexion ; **SDK web servi par l'application** (plus de chargement depuis gstatic.com, plus d'adresse IP transmise à ce titre) ; natif : effacement et rechargement **non exercés** |
| Écoutes temps réel (FB5b, 2026-10-19) | **Aucune donnée nouvelle ni nouveau destinataire** : les écoutes (`snapshots`) lisent les mêmes documents que les lectures, sous les mêmes règles par rôle (aucune écoute de ce que les règles cachent à la famille) ; elles maintiennent une connexion ouverte vers Firestore pendant l'affichage d'un écran, fermée avec lui ; au changement de club, de rôle ou de périmètre et à la déconnexion, la fermeture d'une écoute de l'ancienne portée est immédiate (`ClubStore` ferme les flux épinglés dès l'écriture de la portée, avant tout événement), puis les écrans rouvrent leur écoute sous la nouvelle portée (`LiveReload`) ; l'état conservé hors ligne est le cache déjà décrit ci-dessus ; une écriture faite hors ligne est mise en file dans le même stockage jusqu'à l'envoi |

## Traitement 4 bis — Import d'une sauvegarde dans le club (migration depuis l'appareil, lot FB7)

| Rubrique | Contenu |
|---|---|
| Finalité | Reprendre dans le club synchronisé l'historique saisi sur un appareil avant la synchronisation (fichier JSON de sauvegarde) ; portabilité |
| Base légale | Celle du traitement 1 (aucune finalité nouvelle) ; `[à valider par le DPO]` |
| Personnes | Élèves du fichier (mineurs et adultes) ; l'animateur qui importe (directeur, administrateur ou enseignant de ses groupes) |
| Données | **Aucune donnée nouvelle** : celles du traitement 1 (prénoms, public, appartenances, séances, passages, blocs acquis, bilans, acquittements, archives). **Marqueur d'import** `clubs/{club}/imports/{empreinte}_{uid}` : empreinte SHA-256 du fichier et du plan, nombres de lots et d'écritures, nombre d'élèves dont le rétablissement a été confirmé, rôle de l'auteur (`director`, `admin`, `teacher`), **identifiant du compte de l'auteur** (`createdBy` et suffixe de l'identifiant du document : le marqueur porte l'`uid` de son auteur **par construction**, pseudonyme, même nature que `createdBy` d'un acquittement ; lu individuellement (`get`) par son seul auteur, qui seul le fait avancer ; tous les marqueurs sont lisibles en liste par le directeur et l'administrateur), deux dates du serveur. **Aucun prénom ni identifiant d'élève** dans le marqueur ; l'empreinte ne permet pas de retrouver le contenu. Chaque document créé porte une date du serveur `importedAt` à la création (aucune donnée personnelle ; ne prouve pas l'origine d'import) |
| Destinataires | Ceux du traitement 1 ; chaque marqueur n'est lisible que par son auteur (liste du dossier : directeur et administrateur) ; jamais par un parent ou un élève |
| Durée de conservation | Données importées : celle du traitement 1. **Marqueur : conservé avec le club** (il empêche un même compte d'importer deux fois le même fichier — un autre compte le pourrait, sans rien écraser — et permet de reprendre un import interrompu) ; l'application ne le supprime pas, seul l'administrateur le peut (console) `[durée et procédure à valider par le DPO]` |
| Sécurité | Règles Firestore par rôle (l'enseignant n'écrit que dans ses groupes, ni saison ni groupe) ; plan calculé et contrôlé **avant** toute écriture ; aucun document existant n'est modifié ; journaux sans donnée personnelle (le rapport ne contient que des codes, des compteurs et des identifiants techniques) |
| Risque propre | **Rétablissement d'élèves effacés** : importer un fichier antérieur à une clôture ou à un effacement recrée des fiches effacées. Mesures : le plan détecte ce que le club permet de voir (saison close à la date d'export ou après, sauvegarde plus récente fournie) et exige la confirmation du **nombre exact** d'élèves concernés ; **non détectable** : l'effacement d'un seul élève hors clôture, un club vide ; consigne aux animateurs : supprimer les anciens fichiers de sauvegarde (ADR 0019, limites). Un fichier de sauvegarde reste hors de portée de l'effacement. **Copie locale** (FB7c) : la copie drift d'un élève **effacé dans le club** reste dans la base locale de l'appareil, **exportable sans compte** et **réimportable** (l'application ne supprime aucune donnée locale avant le lot de retrait de drift) ; mesure : confirmation du nombre exact quand la date du fichier (dernière modification de la base) précède une clôture, consigne de supprimer les anciens fichiers et de ne pas réimporter, retrait de drift à planifier |
| État réel (FB7b, 2026-10-20) | Moteur (FB7a) **et écran d'import (FB7b)** livrés, sous `DATA_BACKEND=firestore` seulement (sous `drift`, le parcours est l'ancienne sauvegarde locale). **Le fichier de sauvegarde peut contenir des données d'enfants et quitte l'appareil vers le club** : mention dans la notice (« Reprise de l'historique d'un appareil », `[à valider par le DPO]`) et dans l'écran (« Le fichier peut contenir des données d'enfants… »). L'écran n'écrit rien dans les journaux, n'affiche ni identifiant de compte ni empreinte, et ne montre un prénom que dans le choix des élèves sans groupe (donnée de l'animateur qui importe). Texte du guide et de l'écran `[à valider par le DPO]` |
| État réel (FB7c, 2026-10-21) | **Export local en lecture seule** dans le build `firestore` (lot FB7c) : le fichier de sauvegarde est produit **sur l'appareil** à partir de la base locale, enregistré à l'emplacement que choisit l'animateur, **sans passer par le serveur** ; il contient les mêmes catégories que l'export ordinaire (prénoms d'enfants compris). **L'écran d'export est ouvert sans compte** : les données locales ne dépendent d'aucun compte (c'était déjà le cas avant l'authentification) ; sur un appareil partagé, toute personne qui l'utilise peut les exporter (l'écran le dit). **Limite assumée** (décision du DPO à prendre : exiger un compte animateur, ou l'inscrire à l'AIPD). Repère local « J'ai importé mes données dans le club » : une clé propre à un compte sur l'appareil, sans donnée personnelle (hachage de l'identifiant, empreinte de compteurs), refusé tant que des écritures attendent d'être envoyées. La date du fichier d'export est celle de la dernière modification de la base. Aucune donnée locale n'est supprimée par l'application. Texte de l'écran et du bandeau `[à valider par le DPO]` |

## Exercice des droits

Voir [procedure-droits-et-effacement.md](procedure-droits-et-effacement.md). Délai de réponse : un mois.

## Violations de données

`[À compléter par le responsable : qui prévient la CNIL sous 72 heures, qui informe les familles, journal des incidents.]` L'éditeur prévient le club sans délai dès qu'il en a connaissance.
