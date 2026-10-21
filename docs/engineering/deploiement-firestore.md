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

**Canal lancé à la main** (`firebase hosting:channel:deploy`) : le test ne garde que le workflow de PR. Construire le canal avec `scripts/build_web.sh --dart-define=DATA_BACKEND=drift` ; sans drapeau, le build est Firestore et lit le projet réel (décision A1 contredite). Pour tester le build Firestore sur un canal : il lit la production avec des données fictives et le canal est public, **ne pas partager son URL**.

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

Mêmes étapes, mêmes numéros (D1 à D8) que [roadmap.md](roadmap.md), « Procédure de mise en service sur Firestore », qui porte aussi les prérequis P1 à P8 avant la première invitation réelle, la migration des données locales (étapes M1 à M6) et les règles R1 à R3. Le build Firestore est en live dès le déploiement : tout ce qui doit être prêt l'est avant l'étape D5. **Le déploiement est fait par l'animateur** (le propriétaire du projet) et **ne dépend ni des essais d'appareils ni de la validation de conformité**, qui bloquent la première invitation réelle. Tant qu'aucun animateur réel n'existe, l'URL n'est partagée à personne.

- **D1. Avant de pousser sur `main`.** Créer les variables GitHub `GCP_WORKLOAD_IDENTITY_PROVIDER` et `GCP_FIRESTORE_DEPLOY_SERVICE_ACCOUNT` (compte de service, rôles IAM minimaux, fédération d'identité : sections 1 à 4 ci-dessous) et activer la protection de la branche `main` (section 5 de ce document). Sans les variables, tout push sur `main` fait échouer le job `firestore`, donc bloque l'hébergement.
- **D2. Tester le workflow de déploiement des règles** par `workflow_dispatch` (Actions, « Déployer les règles et index Firestore », sur `main`) : le job `deploy` doit être vert.
- **D3. Contrôler la console Authentication avant le premier déploiement** : domaines autorisés (dont l'URL live), protection contre l'énumération d'adresses, modèles d'e-mail (vérification, réinitialisation).
- **D4. Préparer l'origine live avant le premier déploiement.** Tant que la version précédente (données en local) est la version en ligne : (a) les données locales de test du propriétaire sur l'origine live sont **exportées ou le stockage du site est vidé**, sinon le build Firestore affiche le bandeau d'export (FB7c) ; (b) sur chaque appareil du pilote, saisir les données fictives de la préparation de [essais-appareils-pilote.md](essais-appareils-pilote.md), qui serviront à l'étape D7 (après le déploiement, le build Firestore n'écrit plus en local).
- **D5. Déployer.** Soit un **push sur `main`** une fois la CI de déploiement des règles prête (D1 et D2) : le job `firestore` déploie règles et index, puis l'hébergement. Soit, à défaut, `firebase deploy --only hosting` **à la main** après un `scripts/build_web.sh` sans drapeau : cette voie **ne déploie ni les règles ni les index** et **saute les tests** ; à n'utiliser que si règles et index sont déjà à jour (`git log -- firestore.rules firestore.indexes.json` : aucun commit postérieur au dernier déploiement des règles). Un canal lancé à la main se construit avec `scripts/build_web.sh --dart-define=DATA_BACKEND=drift` : sans drapeau, le build est Firestore, lit le projet réel et le canal est public.
- **D6. Vérifier.** Connexion du compte administrateur du projet réel ; avec **ce compte**, écran « Plus » puis **Administration** : créer le **club de test** et le **directeur de test**, inviter un compte de test. Changement de domaine futur : l'origine change, les données locales n'y suivent pas, et le nouveau domaine est à ajouter aux domaines autorisés d'Authentication.
- **D7. Essais des appareils du pilote, en parallèle du développement.** Le protocole [essais-appareils-pilote.md](essais-appareils-pilote.md) se joue sur l'URL déployée, avec les données fictives de l'étape D4. Il ne retarde pas le déploiement ; il est le prérequis P2 de [roadmap.md](roadmap.md) (« Avant la première invitation réelle »).
- **D8. Retour arrière.** Revert du lot de bascule sur `main`, **ou** restauration de la version précédente dans la console Hosting, qui n'est valable **que si aucun push n'a suivi** le lot (sinon la « version précédente » est elle-même un build Firestore : revert). Chaque push relance le job `firestore` (idempotent) ; une panne de la fédération d'identité le bloque, donc bloque l'hébergement : lors d'un revert, si le job échoue, déployer l'hébergement à la main (`firebase deploy --only hosting`, mêmes réserves qu'à l'étape D5).

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

1. Actions > « Déployer les règles et index Firestore » > Run workflow, sur `main`
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

Les règles précédentes restent dans l'historique des versions (Console
Firebase > Firestore > Règles > Historique, bouton de republication) ; pour
revenir par Git, `git revert` du commit de règles puis push sur `main`. Un
index supprimé à la main dans la console n'est pas recréé tant que
`firestore.indexes.json` n'est pas modifié ou le workflow relancé à la main.

## Limites

- Le workflow n'a jamais été exécuté contre le projet réel (aucun accès pris
  dans ce lot) : seul le test de forme et les tests de règles sur l'émulateur
  le couvrent. Le premier passage réel est la section 6 (étape D2).
- Les index supprimés du fichier ne sont **pas** supprimés du projet (voulu :
  pas de `--force`) ; les supprimer reste une action de console.
- Les index se construisent de façon asynchrone : le déploiement rend la main
  avant que tous soient prêts, une requête qui en dépend échoue (`failed-precondition`)
  jusque-là. Les index de l'application sont peu nombreux et peu volumineux.
