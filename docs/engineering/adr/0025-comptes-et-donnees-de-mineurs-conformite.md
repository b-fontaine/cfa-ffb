# ADR 0025 — Comptes et données de mineurs : responsabilité, garde-fou de mise en production, minimisation, conservation, effacement

- Statut : **accepté sur les recommandations** (2026-10-17) pour le lot FB0 de l'horizon H5. Décisions A1 à A4, B2, B3, C1, C3 et C4 du
  relevé de décisions H5 : l'utilisateur a retenu la recommandation de chacune et a fixé la région (A1 : base créée en `europe-west9`).
  Complète l'ADR « Firebase source de vérité » (0024, modèle de données et matrice des droits). **Amende** l'[ADR 0001](0001-persistance-locale-drift.md)
  (durée de conservation `[Prop]` remplacée par la décision 8 de la roadmap, précisée ici) et l'[ADR 0019](0019-cloture-de-saison-archive-agregee-et-effacement-en-lot.md)
  (déc. 3, « aucune trace nominative » : nuancée par la décision 8). Livrables types : [../conformite/](../conformite/README.md).
- **Mis à jour le 2026-10-24 (FB8 partie B)** : décision 6 précisée par l'animateur (durées des comptes adultes organisationnelles, sans
  date), décision 7 annotée de ce qui est réalisé (purge à la clôture, suppression de compte) et de ce qui reste en FB8 partie C
  (échéance `expireOn`, bandeau, blocage, purge forcée, document de demande, export du droit d'accès) ; voir l'[ADR 0024](0024-firebase-source-de-verite-comptes-clubs-roles.md), notes FB8b.
- **Aucun texte de ce lot n'est un avis juridique.** Registre, AIPD, notice, DPA et procédure sont des **projets à valider par la fédération
  ou un DPO** avant tout usage avec de vrais élèves (décision 3).
- Contexte : H5 fait passer les prénoms, présences et résultats d'élèves mineurs d'un seul appareil (ADR 0001, « aucune donnée ne quitte
  l'appareil ») vers un service cloud partagé entre clubs, avec comptes de parents, d'enseignants, de directeurs et d'administrateurs.
  Cela crée un traitement à responsable identifiable, plusieurs destinataires, un sous-traitant américain (Auth) et des mineurs : AIPD
  probable, information des familles obligatoire, durée de conservation à justifier. Données du service : prénom + initiale, public,
  appartenance à des groupes datés, présences, passages et résultats d'exercices, étiquettes de séance (ADR 0023), adresses e-mail des
  adultes.

## Décision

1. **Régions et projet (A1).** Base Firestore `(default)` en **`europe-west9` (Paris)**, irréversible ; `firebase.json` et `firestore.rules`
   alignés (refus par défaut, seul fournisseur `emailPassword`). Un seul projet `animation-billard` tant qu'il n'y a pas de vrai élève ;
   previews de PR non connectées à Firestore ; deux projets (prod et dev) au plus tard à l'arrivée de vrais élèves. Base `(default)`
   **créée par l'animateur en `europe-west9` le 2026-10-17** (fait, déclaré par l'animateur) ; reste à constater la région effective dans la
   console (`[à confirmer]`). La branche « base existante en `eur3` » (option 3 du relevé) est écartée. **Auth reste traité aux États-Unis** quelle que soit la
   région Firestore (vérifié à la source, voir « Vérifications » ci-dessous) ; **garanties de transfert à valider par le DPO**.
2. **Rôles RGPD (A2).** Cible : **chaque club est responsable de traitement** de ses élèves ; **l'éditeur (titulaire du projet Firebase) est
   sous-traitant du club** et fournit un paquet de livrables types (registre, AIPD, notice, DPA/sous-traitants, procédure) ; **Google est
   sous-traitant ultérieur**. Si une fédération ou un comité se manifeste, elle devient **responsable unique** (option B), les clubs
   utilisateurs, l'éditeur toujours sous-traitant : les livrables sont écrits pour que ce basculement ne change que la désignation du
   responsable et le signataire (voir README de `conformite/`). Aucun accord fédéral n'est supposé. Le développement FB1 à FB5 sous émulateur
   n'est pas bloqué.
3. **Garde-fou de mise en production (A3).** **Aucune base de production ne contient de vrai élève** (ni de vrai parent ou enseignant invité
   pour des vrais élèves) tant que : (a) l'AIPD n'est pas validée ; (b) registre, notice d'information, DPA et procédure ne sont pas validés ;
   (c) le responsable de traitement est désigné par écrit. Développement et tests : émulateurs et comptes de test seulement. Tout texte
   juridique (registre, AIPD, notice, consentement, DPA) porte la mention **« projet à valider par la fédération ou un DPO »** en tête, dans
   le dépôt comme dans l'application (clé de traduction dédiée en FB3 tant que non validé). Le garde-fou est écrit dans la roadmap (§ H5, « Garde-fou de mise en production »)
   comme jalon hors code, avec renvoi vers `conformite/README.md` ; il est levé par une décision `[U]` datée consignée dans `conformite/README.md`.
4. **Âge et identité d'un élève (A4).** (a) **Case déclarative « a 15 ans ou plus »**, posée par l'adulte qui invite (directeur ou
   enseignant) ; **aucun âge ni date de naissance stocké**. Elle conditionne seulement la possibilité d'inviter l'élève à créer son propre
   compte ; sinon l'accès passe par un compte parent. (b) **Identité = prénom + initiale du nom, bornées** : validation dans le domaine
   (`firstName` : longueur bornée, initiale d'une seule lettre) ; c'est de la **minimisation, pas de la pseudonymisation** : prénom et
   initiale restent des données à caractère personnel, l'ADR et les textes n'emploient pas « pseudonymisé » pour cela. (c) Le
   **commentaire d'évaluation** (`MaturityAssessment.comment`, existant) est **facultatif, borné à `maxCommentLength`, conservé, et signalé à l'AIPD
   comme texte libre sur un mineur** (recommandation A4 : le garder facultatif et borné). Seule la **note de jeu** (ADR 0023) est sans texte libre. (d) L'âge de 15 ans (art. 45 de la loi Informatique et Libertés) est confirmé à la source CNIL (voir
   « Vérifications »). La case est une **déclaration**, non vérifiée par l'application : la responsabilité en incombe au club (limite assumée).
5. **Visibilité parent et élève (B2).** Un parent ou un élève ne voit que : la **fiche en parcours de l'élève** (type `StudentShowcase`, ADR 0014,
   prénom et parcours) et les **prochaines séances planifiées des groupes de l'élève**. Il ne lit **ni assiduité, ni `session_records`, ni
   saisies de groupe, ni alertes, ni bilans, ni autre élève** (une règle Firestore ne filtre pas les champs : le périmètre est tenu par la
   structure des documents et par un garde de route sur le lien uid). Le bouton « Montrer à l'élève » reste réservé aux rôles animateurs.
   L'assiduité côté famille est à rouvrir avec la fédération après retours (ne pas dupliquer sans transaction). Un parent garde la lecture quand
   l'élève de 15 ans a son compte ; le directeur peut la retirer.
6. **Conservation (B3).** Remplace la durée `[Prop]` de l'ADR 0001. Durées proposées, à valider par le responsable de traitement (la CNIL ne
   fixe pas de durée chiffrée pour les suivis de mineurs : voir recherche) :

   | Donnée | Durée | Déclencheur |
   |---|---|---|
   | Élève (fiche, appartenances, présences, passages, résultats, étiquettes de saisie) | **saison en cours + saison suivante** (décision 8 du 2026-10-16) | clôture de saison (lot 11) |
   | Compte parent | **fin de la saison suivante** du dernier enfant lié (**organisationnelle**, sans date dans les données : voir ci-dessous) | effacement de la dernière fiche liée (le `member` part par ricochet, à la clôture ou à la demande), retrait par le directeur, ou suppression du compte par son titulaire |
   | Compte enseignant ou directeur | **12 mois** après le dernier rattachement actif à un club (**organisationnelle**, sans date dans les données) | retrait par le directeur (enseignant) ou l'administrateur (directeur), ou suppression du compte par son titulaire |
   | Invitation acceptée, expirée ou révoquée | purgée à la **clôture de saison** (expiration d'usage : 7 jours pour un élève ou un parent, 48 h pour un enseignant **ou un directeur** ; la règle tolère une heure d'horloge : 169 h et 49 h) ; une invitation révoquée est supprimée dès la révocation | clôture de saison (FB8 partie B : étape de la clôture, invitations utilisées ou échues du club) |
   | Marqueur d'import ou d'opération (`uid` de l'auteur, aucune donnée d'élève) | le temps de l'opération ; supprimé par son auteur avec son compte ; **90 jours** sans avancement (`updatedAt`), puis supprimable par tout gestionnaire du club (durée à valider par le DPO) | fin de l'opération, suppression du compte, action « Marqueurs abandonnés » |
   | Archive agrégée non nominative (ADR 0019, seuil de 3) | non limitée : non personnelle | — |
   | Compte Auth (e-mail) | supprimé avec le compte ; Google purge les sauvegardes sous 180 jours | suppression du compte |

   **Effacement à la demande à tout moment** (décision 8). Étend la décision 8, qui ne couvrait que les élèves : **à confirmer par
   l'utilisateur** (nouvelles durées pour parents, enseignants, directeurs, invitations).
   **Confirmé par l'animateur le 2026-10-24 (décision D2 du plan FB8b)** : les durées des comptes adultes (parent, enseignant, directeur)
   restent **organisationnelles, sans date** : aucun `expireOn` ni date de détachement n'est porté par les `members` ; le `member` disparaît
   au retrait, par ricochet à l'effacement de la dernière fiche liée, ou à la suppression du compte par son titulaire. Les 12 mois et la
   « fin de la saison suivante » sont donc tenus par le club (revue de l'équipe à la clôture), pas vérifiés par l'application. Un compte
   d'authentification resté **sans club** ne contient plus aucune donnée de club ; il ne se supprime que par son titulaire, ou en console par
   le titulaire du projet. Les durées elles-mêmes restent **à valider par la fédération ou le DPO**.
7. **Purge et effacement sans Functions (C1).** Spark n'a pas de Cloud Functions : (a) la **purge de fin de saison** est lancée depuis
   l'application par le directeur, **par lots reprenables** (écritures par lots de 400 au plus, quota Spark de 20 000 suppressions par jour),
   chaque document porte `expireOn` ; bandeau d'avertissement puis **blocage de la saisie à l'échéance** ; l'administrateur peut forcer la
   purge d'un club défaillant ; (b) la **garantie de durée est organisationnelle, non automatique**, et la notice le dit ; (c) l'effacement
   d'un élève marque d'abord la fiche `erasing` (marqueur **transitoire**, sans nom, supprimé en fin de purge), ce qui **amende la
   déc. 3 de l'ADR 0019** : pas de journal ni de liste d'identifiants (aucun tombstone), mais un marqueur le temps de reprendre un lot interrompu ;
   la clôture n'est plus atomique mais idempotente et reprenable ; (d) **le parent demande l'effacement par un document sans nom d'enfant**,
   traité par le directeur sous un mois ; (e) l'utilisateur supprime lui-même son compte Auth après réauthentification ; un directeur désigne
   un successeur avant de supprimer le sien ; (f) `clearPersistence` à la déconnexion (décision 10) ; (g) une règle `exists()` sur la fiche
   élève atténue la résurrection d'une donnée par un appareil retardataire. Les fichiers JSON de sauvegarde exportés restent **hors de portée** :
   ils sont mentionnés dans la notice. Procédure : [../conformite/procedure-droits-et-effacement.md](../conformite/procedure-droits-et-effacement.md).

   **État de réalisation au 2026-10-24 (FB8 parties A et B ; [ADR 0024](0024-firebase-source-de-verite-comptes-clubs-roles.md), notes FB8a et FB8b).**
   - **(a) Réalisé en partie.** La clôture de saison est une opération par lots reprenables (FB8a) qui efface les élèves choisis et, depuis
     FB8b, **supprime les invitations utilisées ou échues du club** (étape de la clôture ; un directeur ne voit ni ne purge les invitations
     de directeur, purgées par la clôture d'un administrateur ou éteintes à l'expiration). **Non réalisé, reporté en FB8 partie C (décision
     D6 du 2026-10-24)** : « chaque document porte `expireOn` » (aucun document ne le porte ; la forme d'une fiche tolère seulement ce nom de
     champ), le bandeau d'avertissement, le **blocage de la saisie à l'échéance** et la **purge forcée** d'un club défaillant par
     l'administrateur. La garantie de durée repose donc **entièrement** sur (b).
   - **(b) Inchangé** : organisationnelle, non automatique ; la notice le dit et ne promet plus ni alerte ni blocage.
   - **(d) Non réalisé, reporté en FB8 partie C (D6)** : aucune collection ni écran de demande n'existe, et un parent n'écrit rien hors son
     nom affiché. La demande se fait **par e-mail au club**, sans nom d'enfant dans l'application (procédure).
   - **(e) Réalisé (FB8 partie B, tranche B2)** : « Supprimer mon compte » (tout rôle sauf l'administrateur) vérifie le mot de passe
     (réauthentification) **avant toute écriture**, refuse si des écritures attendent l'envoi, puis, club par club, révoque les invitations en
     attente émises depuis l'appareil, supprime les marqueurs de l'auteur et son `member` **en dernier**, enfin le compte Auth. **Successeur
     du directeur (décision D1 du 2026-10-24)** : « un directeur désigne un successeur » est remplacé par : **le dernier directeur d'un club
     ne peut pas supprimer son compte** (refus de l'application, qui compte les directeurs du club ; une règle ne compte pas les membres) ;
     le successeur est **invité par l'administrateur** (invitation de directeur) ; aucune règle de promotion n'est ouverte (décision 14 de
     l'ADR 0024 inchangée). Limite : deux directeurs qui se suppriment au même moment peuvent laisser un club sans directeur (filet : une
     invitation de directeur par l'administrateur). Le compte administrateur se supprime en console.
   - **Marqueurs** (décision D4 du 2026-10-24) : supprimés par leur auteur avec son compte ; filet de **90 jours** sans avancement pour tout
     gestionnaire (« Marqueurs abandonnés », action explicite ; durée à valider par le DPO). **`createdBy` d'un acquittement** garde l'`uid`
     de son auteur après la suppression de son compte (décision D5 : pseudonyme sans compte, déclaré au registre et dans la notice).
8. **Sécurité de l'accès (C3).** **App Check** en **surveillance** au lancement puis **application stricte** (délai à fixer en FB8 ;
   critère : taux de jetons valides observé à la console) ; fournisseur web **reCAPTCHA** (envoie l'IP à Google : destinataire à lister au registre) ;
   attestations Play Integrity et App Attest pour Android et iOS (empreintes et compte Apple selon C5). **MFA pour directeur et administrateur :
   à étudier** (FB8) ; sur Spark, l'authentification multifacteur par SMS n'est pas disponible (Phone Auth non applicable sur Spark, vérifié) : une
   MFA par application TOTP dépend de l'offre Identity Platform, **à vérifier en FB8**. Mot de passe d'au moins 10 caractères, e-mail vérifié exigé dans les règles.
9. **Administrateurs et accès aux prénoms de mineurs.** L'administrateur a tous les droits (matrice du 2026-10-16) et **peut donc lire les prénoms
   de mineurs de tous les clubs**. Le directeur lit tout son club. Cet accès est **déclaré au registre** (destinataires) et à l'AIPD ; **un à deux
   comptes administrateur** au plus, créés à la main en console, `write: false` sur `admins` dans les règles ; la liste nominative des
   administrateurs est tenue par le responsable de traitement. Un accès administrateur à des données d'un club est une opération exceptionnelle
   (support, purge forcée) ; une journalisation côté application n'existe pas (Spark) : limite assumée.
10. **Cache hors ligne web (C4).** La persistance Firestore est activée sur web (désactivée par défaut) pour l'usage en salle : les données sont alors
    **stockées en clair dans IndexedDB du navigateur**. Mesures : `clearPersistence` à la déconnexion, avertissement « appareil partagé » à la
    première connexion web, gestion des onglets multiples, pastille discrète (À jour / Envoi en attente (n) / Hors ligne), libellés fr/en à valider.
    Risque déclaré à l'AIPD. Alternative écartée : persistance désactivée sur web (rien de stocké, mais plus d'usage hors ligne en salle).
11. **Export des données d'un élève (droit d'accès).** Le directeur (ou l'administrateur) produit, pour un élève, un fichier JSON lisible
    (fiche, appartenances, présences, passages, résultats, étiquettes de ses saisies) et une feuille PDF réutilisant l'export du lot 14 ; réponse
    sous un mois. Le format de sauvegarde v5 reste l'export de portabilité du club. Le parent obtient l'export par la demande de la procédure.
    Implémentation : FB8 (cas d'usage `ExportStudentData`, testé par BDD). **Non réalisé au 2026-10-24** : reporté en FB8 partie C ;
    d'ici là, aucun texte ne doit présenter cet export comme disponible (procédure, notice, AIPD l'annoncent « à venir »).
12. **Information des familles.** Notice remise **avant** l'invitation (papier ou page du club) et rappelée dans l'application à la première connexion d'un
    parent ou d'un élève ; contenu : responsable, finalités, base légale, destinataires (dont Google), transfert hors UE (Auth), durées, droits, contact, caractère
    non automatique de la purge, fichiers exportés hors de portée. Textes fr et en : [../conformite/notice-information-familles.md](../conformite/notice-information-familles.md). Base légale
    `[Prop]` : intérêt légitime du club pour le suivi pédagogique, ou exécution du contrat d'adhésion ; **à valider par le DPO** (aucun consentement n'est
    la base principale ; le seuil de 15 ans (art. 45 loi Informatique et Libertés) et sa portée pour ce service pour le compte propre d'un élève sont **à valider par le DPO**).

## Vérifications faites en FB0 (2026-10-17, avec source)

| Point | Résultat | Source |
|---|---|---|
| Âge de consentement numérique | **Confirmé : 15 ans** (art. 45 loi Informatique et Libertés ; en dessous, accord conjoint du mineur et du parent) | cnil.fr, recommandation 4 (« Rechercher le consentement d'un parent pour les mineurs de moins de 15 ans ») |
| Quotas Spark Firestore Standard | **Confirmés** : 1 GiB stockés, 10 GiB/mois de sortie, 20 000 écritures/jour, 50 000 lectures/jour, 20 000 suppressions/jour | firebase.google.com/pricing |
| Auth sur Spark | 50 000 MAU (avec Identity Platform) ; Phone Auth « non applicable » | firebase.google.com/pricing |
| Functions sur Spark | Pas de quota sans coût listé (colonne « non applicable ») | firebase.google.com/pricing |
| Auth traité aux États-Unis | **Confirmé** : « The Firebase Authentication service is run only from US data centers » ; IP conservées quelques semaines | firebase.google.com/support/privacy |
| Suppression de compte Auth | **Confirmé** : retrait des systèmes live et sauvegardes sous 180 jours | firebase.google.com/support/privacy |
| Google sous-traitant, DPF | **Confirmé** : Google « generally a data processor », certifié DPF ; SCC listées | firebase.google.com/support/privacy |
| App Check | Jetons de 7 jours au plus, attestation non conservée ; reCAPTCHA non traité par la page | firebase.google.com/support/privacy |
| TTL Firestore sur Spark | **Non vérifié** : la page de tarifs n'en parle pas ; non nécessaire (la purge est client, décision 7) | — |
| Quota par région (Paris) | **Non vérifié** (la page de tarifs ne distingue pas les régions) ; à relever par l'animateur dans la console, la base étant créée | — |

## Alternatives écartées

- **Base conservée en `eur3`** (option 3 du relevé A1) : écartée, la base ayant été créée en `europe-west9` par l'animateur.
- **Éditeur seul responsable de traitement** (A2 option C) : charge maximale, clubs sans maîtrise.
- **Fédération responsable dès le départ** (A2 option B) : suppose un accord dont rien ne montre l'existence ; reste la cible si elle se manifeste.
- **AIPD complète avant tout code** (A3 option B) : modèle encore mouvant, AIPD périmée ; **pas d'AIPD** (option C) : fragile pour des mineurs avec transfert hors UE.
- **Année de naissance facultative** (A4 option B) : donnée de plus sur un mineur, migration, export, effacement ; **compte élève dès 18 ans seulement** (C) : revient sur la décision 2 ; **prénom seul** (D) : doublons dans des groupes de 10 à 15.
- **Pseudonymisation par identifiant** : un identifiant conservé relie un fichier à une personne ; contourne l'effacement (même raisonnement que l'ADR 0019).
- **Assiduité ou fiche complète en lecture côté parent** (B2 options B et C) : duplication sans transaction, ou exposition des alertes et bilans.
- **Conservation tant que le compte existe** (B3 option B) : pas de limite, faible face à la minimisation.
- **Blaze avec TTL et fonction planifiée** (C1 option B) : contredit la décision 3 (Spark) ; **journal technique pseudonymisé** (C) : contredit l'ADR 0019.
- **Pas d'App Check** (C3 option C) ; **App Check strict d'emblée** (B) : risque de bloquer des appareils légitimes.

## Conséquences

- AGENTS.md (« local d'abord », « aucune donnée ne quitte l'appareil ») et ADR 0001 sont amendés par l'ADR 0024 ; le présent ADR fixe le régime des
  données de mineurs une fois cet amendement effectif.
- **`platform_privacy_test` (`app/test/tool/platform_privacy_test.dart`) à modifier en FB1** (non modifié ici). Il affirme que prénoms et résultats « ne quittent pas
  l'appareil » et impose `android:allowBackup="false"` et `isExcludedFromBackup`. Ce qui devra changer : (a) réécrire le commentaire (les données quittent l'appareil vers
  Firestore, désormais voulu) ; (b) **conserver** les deux assertions : la désactivation de la sauvegarde automatique Android et l'exclusion iCloud restent justifiées
  (le cache Firestore local et le stockage d'appareil ne doivent pas être copiés vers le cloud personnel de l'utilisateur) ; (c) ajouter des assertions sur `firebase.json`
  (`emailPassword` seul, région `europe-west9`) et `firestore.rules` (aucune règle `allow ... if true`, ni date d'expiration), et sur le code (aucun `Firebase.initializeApp`
  sans option de persistance explicite, appel de `clearPersistence` à la déconnexion, App Check initialisé) ; (d) vérifier que le drapeau d'émulateur est refusé en release (B4).
  Le test est déplacé ou renommé seulement si l'ADR 0024 le décide.
- Livrables dans `docs/engineering/conformite/` ; la mise en production avec de vrais élèves dépend du jalon de la décision 3.
- Dépendances de FB0 à FB8 : validation par le DPO (registre, AIPD, notice) ; confirmation `[U]` des durées de la décision 6.
- Le lot 11 (clôture de saison) est repris pour la purge par lots reprenables (décision 7).

## Limites assumées

- La case « 15 ans » est déclarative, non vérifiée ; un club peut mal la remplir.
- La purge de durée n'est pas automatique : elle dépend de l'action d'un directeur ou d'un administrateur (clôture de saison, retrait d'un membre, « Marqueurs abandonnés ») ; un club inactif garde ses données jusqu'à intervention. Le bandeau, le blocage de saisie et la purge forcée par l'administrateur, prévus par la décision 7(a), **n'existent pas** (FB8 partie C) : rien ne signale à un club qu'il est en retard.
- Les durées des comptes adultes sont organisationnelles (décision 6, D2 du 2026-10-24) : l'application ne date pas le dernier rattachement d'un enseignant ou d'un directeur et ne propose jamais d'elle-même leur retrait (« Retirer l'accès » de « Mon club » reste une action du directeur ou de l'administrateur) ; c'est au club de revoir son équipe.
- **Suppression d'un compte (FB8 partie B)** : (1) la garde du dernier directeur est de l'application, pas des règles (course entre deux directeurs : club sans directeur, filet par l'administrateur) ; (2) les invitations **inutilisées** que le compte a créées sont révoquées depuis tout appareil (liste au serveur, ADR 0024 notes FB8b, corrections après relecture) ; les invitations déjà utilisées partent à la clôture ; (3) un `member` dans un club supprimé ou sans nom est retiré lui aussi ; les marqueurs d'opération d'un directeur rétrogradé en enseignant restent jusqu'au filet de 90 jours ; (4) `createdBy` des acquittements garde l'`uid` de l'auteur (D5) ; (5) un compte Auth sans club n'est supprimé que par son titulaire ou en console ; Google purge ses sauvegardes sous 180 jours.
- **Marqueurs** : un marqueur abandonné reste jusqu'à ce qu'un gestionnaire lance « Marqueurs abandonnés » après 90 jours ; supprimer le marqueur d'un import **terminé** permet de réimporter ce fichier, dont l'aperçu proposerait de rétablir les élèves effacés depuis (seule garde : la confirmation du nombre exact, dite à l'écran et au guide).
- Données non effaçables par l'application : fichiers JSON exportés, copies d'écran, feuilles PDF imprimées, sauvegardes Google (jusqu'à 180 jours pour les comptes Auth).
- Auth est traité aux États-Unis (DPF, SCC) ; aucune alternative européenne dans le périmètre Spark.
- Prénom + initiale reste une donnée personnelle ; un groupe de très petite taille rend l'élève identifiable.
- Pas de journal d'accès des administrateurs (Spark, pas de Functions).
- Le commentaire d'évaluation (texte libre facultatif et borné) peut contenir des informations non prévues sur un mineur ; la minimisation repose sur la consigne donnée aux animateurs et sur la borne de longueur.
- Les durées de conservation et la base légale sont des propositions `[Prop]` à valider par la fédération ou un DPO ; rien dans ce lot ne remplace cette validation.
- **Effacement d'un élève et clôture de saison réalisés côté serveur (FB8, partie A, 2026-10-22, [ADR 0024](0024-firebase-source-de-verite-comptes-clubs-roles.md) notes FB8a)** : le droit à l'effacement est honoré **à tout moment** : la fiche passe à `erasing` (aucune donnée nouvelle ne s'y rapporte plus), tout ce qui s'y rapporte est purgé par lots reprenables, la fiche est supprimée **en dernier**, avec un marqueur d'opération **sans donnée personnelle** : aucune trace nominative ne reste. Ce que l'effacement **ne peut pas** atteindre, et que la procédure dit (liste identique dans la procédure et le registre 4 ter) : la **copie locale** restée dans la base drift d'un appareil (FB7c), les **sauvegardes déjà exportées**, les copies d'écran, les sauvegardes de la plateforme, une **présence orpheline** (identifiant d'élève ajouté aux présents d'une saisie par un appareil retardataire après le dernier passage de la purge : sans prénom ni fiche ; la purge est rejouée juste avant la suppression de la fiche, fenêtre réduite, pas fermée) ; une **appartenance orpheline** (créée par un second appareil du directeur après la suppression de la fiche : identifiant d'élève lié à un groupe et à des dates, sans prénom ni fiche ; la règle de création d'appartenance ne distingue pas une fiche supprimée d'une fiche jamais créée, car la restauration d'une sauvegarde écrit l'appartenance avant la fiche : limite assumée) ; les **invitations non utilisées** qui citent l'élève (l'effacement ne les cherche pas ; la règle d'utilisation les refuse dès que la fiche citée est absente ou en cours d'effacement, donc aucun compte n'en tire un lien ni un identifiant ; reste le document d'invitation, avec l'identifiant de l'élève, jusqu'à la **clôture de saison suivante**, qui supprime les invitations utilisées ou échues du club, FB8 partie B) ; un **lien de compte vers une fiche absente** (le directeur et l'administrateur peuvent créer un membre parent ou élève avec l'identifiant d'une fiche supprimée ou en cours d'effacement, ou l'ajouter à ses liens : la règle des membres ne regarde pas l'existence de la fiche ; un appareil de directeur retardataire laisse alors un identifiant d'élève effacé dans un compte, sans prénom, et ce lien n'ouvre aucune donnée tant que la fiche est absente : limite assumée) ; une **édition tardive pendant l'effacement** (la promesse « aucune donnée nouvelle » ne vaut que pour les **créations** : pendant `erasing`, la règle accepte encore une mise à jour de la fiche (prénom) et des passages, blocs acquis et bilans existants ; une édition tardive est supprimée par la purge ou rejouée par l'étape de suppression : limite assumée) ; la **progression locale des séances guidées** d'un autre appareil (elle n'est effacée que sur l'appareil qui mène l'effacement ou la clôture : celle d'une tablette d'enseignant reste, sans prénom, liée par des identifiants de séance ou de groupe); une **fiche recréée** (garanti : une édition, qui est une mise à jour, échoue sur une fiche supprimée, et la création d'une fiche exige la date du serveur ; sous Firestore, l'invitation ne crée jamais de fiche (`ExistingStudentDirectory` vérifie seulement qu'elle existe), donc une fiche supprimée entre la liste des élèves invitables et la publication ne revient pas ; sous drift, la publication d'une fiche locale vers le club à la première invitation reste une création ; non garanti : une inscription rejouée ou volontaire d'un gestionnaire est une création ordinaire, que la règle ne distingue pas, et aucun tombstone nominatif ne permet de l'interdire ; la fiche revient alors avec le seul prénom envoyé, sans passage ni bilan) ; le **compte d'authentification** (Auth) du parent ou de l'élève, qui subsiste, sans club, jusqu'à ce que son titulaire le supprime (« Supprimer mon compte », FB8 partie B) ; le **marqueur d'effacement**, dont l'identifiant est un pseudonyme dérivé (empreinte salée par l'identifiant du club : recalculable seulement avec l'identifiant du club et celui de l'élève), supprimé avec le dernier lot ; une **clôture commencée par un autre gestionnaire**, non détectée (seul le marqueur du compte courant est lu : la seconde clôture converge, elle n'est pas refusée ; test de caractérisation). Une **clôture de saison termine tous les effacements en cours** du club (elle purge et supprime toutes les fiches `erasing`, y compris celles qu'un autre auteur avait commencées) ; l'archive agrégée compte ces élèves comme ils sont, sans les nommer. Délai : l'effacement se mène **à la demande**, par le directeur, en quelques minutes pour un dossier ordinaire ; au-delà de 10 000 écritures par jour sur un appareil (très gros dossier, clôture d'un très grand club), il s'étale sur plusieurs jours et se **reprend** (la fiche reste marquée, aucune donnée nouvelle n'y entre).

