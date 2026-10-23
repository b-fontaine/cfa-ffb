# Déploiement des règles et des index Firestore par la CI

Décision de l'utilisateur du 2026-10-18 ([ADR 0024](adr/0024-firebase-source-de-verite-comptes-clubs-roles.md),
note FB5a) : `firestore.rules` et `firestore.indexes.json` sont déployés **par
GitHub Actions**, plus à la main. Ce document dit ce que fait le workflow et ce
que **l'utilisateur doit créer lui-même** (rien n'est créé par le dépôt, ni dans
GitHub ni dans Google Cloud).

## Ce que fait le workflow

Fichiers : [`firebase-firestore-deploy.yml`](../../.github/workflows/firebase-firestore-deploy.yml)
(appelé) et [`firebase-hosting-merge.yml`](../../.github/workflows/firebase-hosting-merge.yml)
(appelant).

```
push sur main ─► firebase-hosting-merge.yml
                   ├─ job firestore  ─► firebase-firestore-deploy.yml
                   │     tests ─► deploy (index, puis règles)
                   └─ job build_and_deploy (hébergement)   needs: firestore
```

1. **Pas de filtre sur le diff** : les règles et les index sont déployés **à
   chaque exécution** (la CLI ne publie que ce qui diffère). Un filtre « le
   push a-t-il touché `firestore.rules` ? » perdrait un déploiement : le
   workflow Hosting garde une seule exécution en attente par groupe de
   concurrence (`cancel-in-progress: false`), donc un push A qui modifie les
   règles, remplacé en attente par un push B qui n'y touche pas, ne serait
   jamais déployé alors que l'application de B suppose ses règles. Le test
   `workflows_test.dart` interdit toute comparaison avec le push précédent.
2. **`tests`** : `dart run tool/check_indexes.dart` (chaque requête composée a
   son index déclaré) et `scripts/rules_test.sh` (règles contre l'émulateur : refus
   par défaut, matrice des rôles, dépôts). Même script que `check.sh --full`.
3. **`deploy`** (après les tests) : refuse tout contexte autre que `main` ;
   vérifie que les deux variables GitHub existent (message d'erreur nommant la
   variable manquante, **avant** toute authentification) ; s'authentifie par
   **fédération d'identité de charge de travail** (aucune clé JSON) ; déploie
   `firestore:indexes` **puis** `firestore:rules` avec la CLI épinglée de
   `package.json` (`--non-interactive`, sans `--force` : aucun index absent du fichier
   n'est supprimé).
4. **L'hébergement attend** : `build_and_deploy` a `needs: firestore`. Les règles
   et les index sont donc publiés **avant** la version de l'application qui les
   suppose ; si leur déploiement échoue, l'hébergement n'est pas déployé.

Pourquoi un workflow **appelé** et non un déclencheur `push` à part : deux
workflows lancés par le même push ne s'attendent pas l'un l'autre, et un
`workflow_run` ne se déclencherait pas quand aucun fichier de règles ne change
(l'hébergement ne partirait jamais). Un groupe `concurrency` partagé
sérialiserait les exécutions, sans dire laquelle passe d'abord.

**Jamais depuis une pull request** : aucun déclencheur `pull_request`, le job
`deploy` refuse tout événement autre que `push` sur `main` (ou lancement manuel
depuis `main`), et seul ce job reçoit `id-token: write`.
`firebase-hosting-pull-request.yml` ne déploie que sur un canal de
prévisualisation. Le test `app/test/tool/workflows_test.dart` (forme des
workflows, sans `actionlint`) garde tout cela.

**Canal lancé à la main** : le test ne garde que le workflow de PR. Il est soumis à la même interdiction que `--only hosting` seul : règles et index à jour d'abord (étape D2, manuelle dans l'état actuel), sinon l'essai d'import échoue. Un canal manuel (`firebase hosting:channel:deploy`, nommé par exemple `pilote`) se construit **en drift** avec `scripts/build_web.sh --dart-define=DATA_BACKEND=drift`, ou **en Firestore** (sans drapeau) avec les réserves suivantes : il lit le projet réel ; les canaux sont publics, le dépôt aussi (l'adresse se déduit), donc **données fictives seulement** ; et le build Firestore ne crée plus de données locales (voir l'étape D4).

**Conséquence à connaître** : le déploiement part **à chaque exécution** (et non
sur le seul diff d'un push). Tant que les variables ci-dessous n'existent pas,
**tout push sur `main`, qu'il touche ou non aux règles, fait échouer le job
`deploy`, donc bloque l'hébergement de ce push**. Faire les sections 1 à 4 ci-dessous (étape D1) avant
de fusionner quoi que ce soit sur `main`.

**Durcissement du job `deploy`** (le seul qui reçoit `id-token: write`) :
permissions réduites à `contents: read` et `id-token: write`, `actions/checkout`
avec `persist-credentials: false`, `npm ci --ignore-scripts` (vérifié avec
`firebase-tools` 15.34.0 : la CLI démarre sans les scripts d'installation de
`re2` et `protobufjs` ; à revérifier à chaque montée de version). Un lancement
manuel (`workflow_dispatch`) entre dans le groupe de concurrence
`firebase-hosting-live` du workflow Hosting, sans annuler l'exécution en cours :
il ne déploie jamais en même temps qu'un push.

## Séquence de mise en service

> **État au jour de la rédaction (2026-10-22).** `origin/main` est au commit 87102d4 (2026-10-17) et tous les commits de H5 sont locaux et non poussés : la version en ligne est donc l'ancienne (schéma drift 11, aucune connexion), `firebase-firestore-deploy.yml` n'existe pas sur la branche par défaut distante (pas de « Run workflow » avant la première fusion) et la « version précédente » de Hosting est ce build du 17 en schéma 11, que le build Firestore (schéma 12) ne permet pas de restaurer (D8). Cet encadré est à retirer après la première fusion de H5 sur `main`.

Mêmes étapes, mêmes numéros (D1 à D8) que [roadmap.md](roadmap.md), « Procédure de mise en service sur Firestore », qui porte aussi les prérequis P1 à P8 avant la première invitation réelle, la migration des données locales (étapes M1 à M6) et les règles R1 à R3. Le build Firestore est en live dès le déploiement : tout ce qui doit être prêt l'est avant l'étape D5. **Le déploiement est fait par le propriétaire du projet** (l'agent ne déploie jamais : il prépare des commits, le revert compris, que le propriétaire fusionne et déploie) et **ne dépend ni des essais d'appareils ni de la validation de conformité**, qui bloquent la première invitation réelle. **Le dépôt est public** : le projet se lit dans `.firebaserc`, l'adresse `animation-billard.web.app` se déduit et chaque PR publie un commentaire public avec l'URL de prévisualisation ; ne pas partager l'URL ne protège donc pas, la protection réelle est l'inscription fermée (invitation obligatoire) et les règles Firestore (accès refusé sans rôle).

- **D1. Avant de fusionner sur `main`.** Créer les variables GitHub `GCP_WORKLOAD_IDENTITY_PROVIDER` et `GCP_FIRESTORE_DEPLOY_SERVICE_ACCOUNT` (compte de service, rôles IAM minimaux, fédération d'identité : sections 1 à 4 ci-dessous) et activer la protection de la branche `main` (section 5 de ce document). Sans les variables, toute fusion sur `main` fait échouer le job `firestore`, donc bloque l'hébergement.
- **D2. Publier règles et index (à la main dans l'état actuel), puis tester le workflow de déploiement après la première fusion.** Dans l'état actuel (voir l'encadré « État au jour de la rédaction »), `firebase-firestore-deploy.yml` n'existe pas sur la branche par défaut distante : GitHub ne propose « Run workflow » (`workflow_dispatch`) que pour un workflow présent sur cette branche, donc **la seule voie avant D5 est manuelle** : `firebase deploy --only firestore:indexes,firestore:rules`, lancé **depuis le commit exact à fusionner** (jamais depuis une copie locale non alignée ; règles et index ne touchent pas à l'hébergement, contrairement à D5). Les règles et index publiés par le propriétaire datent de l'état 008c1da (2026-10-19) ; `firestore.rules` a changé depuis (8850926, FB7a ; 40c1e89, FB8a : collection `operations` et fiche `erasing`) et changera encore avec FB8 (parties B et C) ; cette publication doit précéder tout déploiement du build Firestore, canal manuel compris (D4, D5). Le test par `workflow_dispatch` (Actions, « Déployer les règles et index Firestore », sur `main`, job `deploy` vert) ne vient qu'**après** la première fusion ; le **premier passage réel de la CI** est le job `firestore` de la fusion de D5.
- **D3. Contrôler la console Authentication avant le premier déploiement** : domaines autorisés (dont l'URL live), protection contre l'énumération d'adresses, modèles d'e-mail (vérification, réinitialisation).
- **D4. Préparer les données locales de test avant le déploiement.** (a) Tant que la version précédente (données en local) est la version en ligne, les données locales de test du propriétaire sur l'origine live sont **exportées ou le stockage du site est vidé**, sinon le build Firestore affiche le bandeau d'export (FB7c). **Exception : cela ne s'applique pas aux appareils d'essai de la voie 1**, qui créent volontairement des données fictives sur l'origine pour voir le bandeau ; ne vider que les autres stockages. (b) Les essais d'appareils P2 qui exigent des données locales (export local) ont besoin de données de test **avant** que le build Firestore soit servi à leur origine, car ce build n'en crée plus. Deux voies, au choix du propriétaire : **voie 1, préparer chaque appareil avant D5** : sur l'origine live, avec la version précédente encore en ligne, saisir les données fictives de [essais-appareils-pilote.md](essais-appareils-pilote.md) dans **chaque navigateur et chaque application installée** (stockages séparés) ; ces données sont créées par l'**ancien build** (schéma drift 11, sans connexion), puis le build Firestore ouvre la base locale et la **monte en schéma 12** (R1, limite d) ; un stockage non préparé avant D5 ne pourra plus servir à ces essais (il ne reste que l'essai de la base vide), et la préparation retarde D5 d'autant ; **voie 2, canal manuel `pilote`** : construit **d'abord en drift** (les appareils y créent leurs données fictives), **puis redéployé sur le même canal** avec le build Firestore, **après publication manuelle des règles et index à jour** (étape D2 : même interdiction que pour `--only hosting` seul, sinon l'essai 4, l'import, échoue faute de la collection `imports` dans les règles publiées) : même origine, même stockage, et c'est un vrai essai de la mise à jour du service worker ; la production n'est pas touchée, D5 ne dépend de rien ; réserves : l'origine du canal n'est pas celle de la production (les essais ne prouvent rien sur l'origine live), son domaine est à vérifier dans les domaines autorisés d'Authentication (étape D3), la durée de vie du canal est à régler (`--expires`), et le canal est public (données fictives seulement).
- **D5. Déployer (fusion de la PR sur `main`).** La protection de la branche `main` exige une PR avec la CI verte : pousser les commits de H5 sur une branche distante dédiée (jamais sur `main`), puis ouvrir la PR vers `main` ; le commentaire de prévisualisation de la PR est public (build drift). Attendre la CI, **fusionner la PR**. **Ne fusionner AUCUNE autre PR (Dependabot compris) sur `main` avant la fusion de H5** : `origin/main` porte l'ancien `firebase-hosting-merge.yml` (schéma drift 11, sans job `firestore`) et le dépôt distant porte six branches Dependabot ; toute fusion préalable reconstruirait et publierait l'ancien build en schéma 11, d'où `DowngradeNotSupported` sur tout appareil qui a ouvert le build Firestore (perte de données). Le job `firestore` publie alors règles et index, puis l'hébergement. **Avant** de mettre le build Firestore en ligne, les règles et index publiés doivent être à jour (étape D2) : ceux du propriétaire datent de l'état 008c1da (2026-10-19), et `firestore.rules` a changé depuis (8850926, FB7a ; 40c1e89, FB8a). **Dans l'état actuel (voir l'encadré « État au jour de la rédaction ») la version en ligne est l'ancienne** (tous les commits de H5 sont locaux, non poussés ; schéma drift 11, aucune connexion) et le premier passage réel de la CI de déploiement est le job `firestore` de cette fusion. La fusion de la PR est la **seule voie de déploiement** ; la publication manuelle de l'**hébergement** n'est autorisée qu'**après** la fusion de H5 sur `main`, et ne sert de repli que si le job `firestore` échoue après la fusion (il échoue tant que les variables WIF manquent : la fusion de H5 ne publie alors rien et cette voie manuelle devient le chemin normal). Voie manuelle : d'abord `firebase deploy --only firestore:indexes,firestore:rules`, puis `scripts/build_web.sh` sans drapeau et `firebase deploy --only hosting` (voie qui **saute les tests**), **construits depuis le commit fusionné sur `main`**, jamais avant la fusion, pas depuis une copie locale non alignée. `firebase deploy --only hosting` **seul est interdit** tant que les règles et index publiés ne sont pas à jour (`git log -- firestore.rules firestore.indexes.json` : aucun commit postérieur à la dernière publication ; la voie manuelle ne contourne pas ce contrôle). Un canal manuel (`firebase hosting:channel:deploy`, nommé par exemple `pilote`) se construit **en drift** avec `scripts/build_web.sh --dart-define=DATA_BACKEND=drift`, ou **en Firestore** (sans drapeau) avec les réserves suivantes : il lit le projet réel ; les canaux sont publics, le dépôt aussi (l'adresse se déduit), donc **données fictives seulement** ; et le build Firestore ne crée plus de données locales (voir l'étape D4). Le canal manuel construit avec le build Firestore (`hosting:channel:deploy`) est soumis à la **même interdiction** que `--only hosting` seul : règles et index à jour d'abord (D2 manuel), sinon l'essai 4 (import) échoue.
- **D6. Vérifier.** Connexion du compte administrateur du projet réel ; avec **ce compte**, écran « Plus » puis **Administration** : « Administration » ne propose que `CreateClub` et `InviteDirector` : Administration > Créer un club > Inviter un directeur (code valable 48 h). Le directeur de test s'inscrit par `/join/<code>` avec une seconde adresse vérifiée sur un domaine autorisé (D3) ; il passe ensuite par « Mon club » > Inviter pour un compte enseignant ou directeur (jamais parent) afin de jouer l'import (essai 4). Changement de domaine futur : l'origine change, les données locales n'y suivent pas, et le nouveau domaine est à ajouter aux domaines autorisés d'Authentication.
- **D7. Essais des appareils du pilote, en parallèle du développement.** Le protocole [essais-appareils-pilote.md](essais-appareils-pilote.md) se joue sur l'URL déployée (voie 1 de D4) ou sur le canal `pilote` redéployé en Firestore (voie 2), avec les données fictives de D4. **Le déploiement ne dépend pas des essais** ; certains essais dépendent en revanche de la préparation faite **avant D5** ou du canal manuel. Les essais 4 et 5 supposent **D6 fait** (club, directeur et compte de test existants, sur le live, ou l'équivalent sur le canal avec règles à jour). Ils sont le prérequis P2 de [roadmap.md](roadmap.md) (« Avant la première invitation réelle »).
- **D8. Retour arrière.** Le **revert** du lot de bascule (build drift en **schéma 12**) est la **seule voie de retour arrière sûre**. Ce qui est à revert est le **commit de fusion** du lot de bascule dans `main` (`git revert -m 1 <fusion>` : il annule ce que la branche de bascule a apporté, **pas** FB8a ni les lots déjà présents dans `main` ; il emporte aussi les textes de procédure de la branche, à rétablir ensuite si besoin). Le commit de fusion est à noter ici après l'intégration (les identifiants `e56dad9`, `ffb06fd`, `e411f1e` de la branche ne sont plus ceux de `main`). L'agent le **prépare** (sur une branche, jamais sur `main`) ; le propriétaire **fusionne la PR de revert sur `main`** (CI verte) et la CI redéploie le build `drift`. **La restauration de la version précédente par la console Hosting est DÉCONSEILLÉE** : la « version précédente » est le build du 2026-10-17 en schéma drift 11 sans connexion, alors que le build Firestore ouvre la base locale et la monte en schéma 12 (R1, limite d) ; restaurer le build du 17 donne `DowngradeNotSupported` sur tout appareil qui a ouvert le build Firestore. Elle n'est tolérable que pour un appareil qui n'a jamais ouvert le nouveau build. Chaque fusion relance le job `firestore` (idempotent) ; une panne de la fédération d'identité le bloque, donc bloque l'hébergement : lors d'un revert, si le job échoue, le propriétaire déploie l'hébergement à la main (`firebase deploy --only hosting`, mêmes réserves qu'à l'étape D5 : règles et index à jour, build construit depuis le commit du revert fusionné).

Les sections numérotées 1 à 5 ci-dessous détaillent l'étape D1 et la section 6 l'étape D2.

## Ce que l'utilisateur doit faire (une fois)

Remplacer `PROJECT_ID` par `animation-billard`, `OWNER/REPO` par le dépôt GitHub.
Les rôles ci-dessous sont les minimaux connus de la documentation Firebase, **non
éprouvés contre le projet réel** (voir « Limites ») ; les noms sont des propositions ; seuls les deux noms de **variables**
GitHub (section 4) sont attendus par le workflow.

### 1. Créer le compte de service dédié

Console Google Cloud, projet `animation-billard`, IAM et administration >
Comptes de service > Créer : nom `firestore-deploy` (adresse
`firestore-deploy@PROJECT_ID.iam.gserviceaccount.com`). **Ne créer aucune clé.**

```sh
gcloud iam service-accounts create firestore-deploy \
  --project=PROJECT_ID --display-name="Déploiement des règles et index Firestore (CI)"
```

### 2. Lui donner les rôles minimaux (et seulement ceux-là)

| Rôle | Pourquoi |
|------|----------|
| **Firebase Rules Admin** (`roles/firebaserules.admin`) | Créer et publier un jeu de règles (`firebaserules.rulesets.create`, `firebaserules.releases.*`) |
| **Cloud Datastore Index Admin** (`roles/datastore.indexAdmin`) | Créer et lister les index composites Firestore en mode natif (`datastore.indexes.*`) |
| **Service Usage Consumer** (`roles/serviceusage.serviceUsageConsumer`) | **À vérifier au premier passage, non éprouvé ici** : la CLI Firebase interroge Service Usage pour savoir si les API sont activées ; à n'ajouter que si le premier déploiement réel le réclame |

```sh
for role in roles/firebaserules.admin roles/datastore.indexAdmin roles/serviceusage.serviceUsageConsumer; do
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:firestore-deploy@PROJECT_ID.iam.gserviceaccount.com" --role="$role"
done
```

Ne pas donner « Éditeur », « Propriétaire », ni un rôle Firebase d'administration
générale. Ce compte ne déploie **pas** l'hébergement (qui garde son propre
secret, voir « Hébergement » ci-dessous) et ne lit aucune donnée Firestore.
Après le premier déploiement, un message « permission denied » nomme la
permission manquante : l'ajouter via un rôle plus précis plutôt qu'un rôle large.

### 3. Configurer la fédération d'identité de charge de travail (WIF)

APIs à activer si besoin : « IAM Service Account Credentials API » et « Security
Token Service API ».

```sh
gcloud iam workload-identity-pools create github --project=PROJECT_ID \
  --location=global --display-name="GitHub Actions"

gcloud iam workload-identity-pools providers create-oidc cfa-ffb --project=PROJECT_ID \
  --location=global --workload-identity-pool=github \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository == 'OWNER/REPO' && assertion.ref == 'refs/heads/main'"

gcloud iam service-accounts add-iam-policy-binding \
  firestore-deploy@PROJECT_ID.iam.gserviceaccount.com --project=PROJECT_ID \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/OWNER/REPO"
```

`--attribute-condition` est **essentiel** : sans lui, tout dépôt GitHub pourrait
demander des jetons. Avec lui, seul `OWNER/REPO` sur `refs/heads/main` obtient
une identité (une pull request ou une autre branche n'en obtient pas, en plus de
la garde du workflow). `PROJECT_NUMBER` est le numéro du projet (pas son
identifiant) : `gcloud projects describe PROJECT_ID --format='value(projectNumber)'`.

### 4. Créer les deux variables GitHub

GitHub > dépôt > Settings > Secrets and variables > Actions > onglet **Variables**
> New repository variable (ce ne sont pas des secrets : aucune clé n'existe).

| Nom | Valeur |
|-----|--------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/cfa-ffb` |
| `GCP_FIRESTORE_DEPLOY_SERVICE_ACCOUNT` | `firestore-deploy@PROJECT_ID.iam.gserviceaccount.com` |

Sans elles, le job `deploy` échoue avec un message qui nomme la variable
manquante et renvoie à cette étape.

### 5. Protéger `main`

GitHub > Settings > Branches > Branch protection rule (ou Rulesets) sur `main` :

- « Require a pull request before merging » ;
- « Require status checks to pass before merging », avec les contrôles du
  workflow `CI` : `Qualité (…)`, `Tests + couverture (ubuntu-latest)`,
  `Tests + couverture (macos-latest)`, `Build web`, `Build Android (debug)`,
  `Widgetbook (…)` ; « Require branches to be up to date before merging » ;
- interdire les poussées directes et les poussées forcées sur `main`, y compris
  pour les administrateurs si possible (« Do not allow bypassing the above
  settings »).

Le déploiement part d'un push sur `main` : sans cette protection, une poussée
directe hors CI déploierait des règles non relues. Le workflow ne revérifie pas
l'état de la CI : c'est la protection de branche qui l'impose.

### 6. Vérifier

1. **Après la première fusion de H5 sur `main`** (le workflow doit exister sur la branche par défaut ; avant, la publication est manuelle, étape D2) : Actions > « Déployer les règles et index Firestore » > Run workflow, sur `main`
   (lancement manuel : déploie sans attendre une modification) ; le job
   `deploy` doit être vert, puis Console Firebase > Firestore > Règles et Index
   montrent la publication.
2. Un push sur `main` qui ne touche ni règles ni index : le job `firestore` est
   vert avec « rien à déployer », l'hébergement part.

### Hébergement

Le workflow d'hébergement garde pour l'instant le secret
`FIREBASE_SERVICE_ACCOUNT_ANIMATION_BILLARD` (clé JSON générée par la CLI
Firebase). Le passer aussi à la fédération d'identité est possible (action
`FirebaseExtended/action-hosting-deploy` avec `entryPoint` et identifiants par
défaut) mais hors de ce lot : décision à prendre séparément.

## Retour arrière

Pour l'application (hébergement), voir l'étape D8 : le revert fusionné par PR est la seule voie sûre ; la restauration console de la version précédente est déconseillée (schéma 11 contre 12). Ce qui suit ne concerne que les règles et les index.

Les règles précédentes restent dans l'historique des versions (Console
Firebase > Firestore > Règles > Historique, bouton de republication) ; pour
revenir par Git, `git revert` du commit de règles dans une PR, fusionnée sur `main` (CI verte). Un
index supprimé à la main dans la console n'est pas recréé tant que
`firestore.indexes.json` n'est pas modifié ou le workflow relancé à la main.

## Limites

- Le workflow n'a jamais été exécuté contre le projet réel (aucun accès pris
  dans ce lot) : seul le test de forme et les tests de règles sur l'émulateur
  le couvrent. Le premier passage réel est le job `firestore` de la fusion de D5 ; le lancement manuel de la section 6 ne vient qu'après.
- Les index supprimés du fichier ne sont **pas** supprimés du projet (voulu :
  pas de `--force`) ; les supprimer reste une action de console.
- Les index se construisent de façon asynchrone : le déploiement rend la main
  avant que tous soient prêts, une requête qui en dépend échoue (`failed-precondition`)
  jusque-là. Les index de l'application sont peu nombreux et peu volumineux.
