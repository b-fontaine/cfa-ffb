# Sous-traitants et accords de traitement — projet à valider par la fédération ou un DPO

Statut : **projet, non validé** (2026-10-17). Sources Google : firebase.google.com/support/privacy et firebase.google.com/pricing, lues le 2026-10-17. Les clauses elles-mêmes ne sont pas reproduites ici : elles sont à lire et à accepter dans la console par le titulaire du projet.

## Chaîne de traitement

| Acteur | Rôle | Fondement |
|---|---|---|
| Club (ou fédération) | Responsable de traitement | RGPD art. 24 |
| Éditeur (titulaire du projet Firebase) | Sous-traitant du club | Accord ci-dessous (art. 28) |
| Google (Firebase) | Sous-traitant ultérieur | Data Processing and Security Terms (Google, « generally a data processor ») |

## Services Google utilisés

| Service | Données | Localisation | Statut |
|---|---|---|---|
| **Cloud Firestore** | Données de suivi (prénom + initiale, groupes, présences, résultats), membres, invitations | **`europe-west9` (Paris)**, base irréversible, **créée par l'animateur le 2026-10-17** (déclaré) | Région effective à constater dans la console `[à confirmer]` ; quota Paris non vérifié (à relever dans la console) |
| **Firebase Authentication** (e-mail et mot de passe seul) | Adresse e-mail, mot de passe haché, identifiant, IP et agent utilisateur | **États-Unis seulement** : « run only from US data centers » ; IP conservées quelques semaines ; suppression des systèmes et sauvegardes sous 180 jours | Vérifié à la source |
| **App Check** | Jetons d'attestation (7 jours au plus), attestation non conservée ; Play Integrity (Android), App Attest (iOS) | Non précisée | Vérifié à la source ; localisation `[à valider]` |
| **reCAPTCHA** (fournisseur web d'App Check) | Adresse IP et signaux du navigateur | Non précisée | Non traité par la page Firebase : `[conditions reCAPTCHA à lire et valider]` |
| **SDK web chargé depuis gstatic.com** | Adresse IP à chaque chargement (serveur Google) ; app inutilisable hors ligne à la première visite | Non précisée | Supprimé avant FB5 si le plugin accepte un SDK local (ADR 0024, B7) |
| **Firebase Hosting** (application web) | Journaux d'accès (IP) | Non précisée | Déjà utilisé ; `[à valider]` |

Services **non utilisés** et à ne pas ajouter sans mise à jour du registre : Google Analytics, Crashlytics, Cloud Messaging, Google Sign-In (retiré de `firebase.json`), connexion anonyme (retirée), Phone Auth.

## Transferts hors UE

Google LLC est certifié au cadre de protection des données UE-États-Unis (DPF) ; Google publie aussi des clauses contractuelles types (« Firebase: Standard Contractual Clauses »). Seul Auth transfère des données (adresses e-mail d'adultes). Analyse d'impact du transfert : `[à faire par le DPO ou le club]`.

## Actions du titulaire du projet (à faire avec la console, par l'utilisateur)

1. Accepter les Data Processing and Security Terms de Firebase et conserver la preuve datée.
2. Constater la région effective `europe-west9` de la base déjà créée, et vérifier que l'analytique et le partage de données avec Google sont désactivés.
3. Lister les administrateurs du projet et du service (un à deux comptes d'application, accès console limité).
4. Activer App Check en surveillance puis strict (ADR 0025, décision 8).

## Accord de sous-traitance club ↔ éditeur (art. 28) — modèle

Mentions minimales à signer `[par le responsable de traitement et l'éditeur]` :

- **Objet et durée** : fourniture de l'application de suivi pédagogique, pour la durée de l'usage par le club.
- **Instructions** : l'éditeur ne traite les données que sur instruction documentée du club ; pas de réutilisation (statistiques, entraînement de modèles, publicité).
- **Confidentialité** : les administrateurs de l'éditeur (un à deux comptes) sont tenus à la confidentialité ; accès aux prénoms de mineurs seulement pour l'assistance ou la purge demandée.
- **Sécurité** : mesures de la fiche du registre ; règles Firestore testées ; App Check.
- **Sous-traitants ultérieurs** : Google uniquement ; information préalable du club avant tout ajout ; mêmes obligations contractuelles.
- **Assistance** : aide pour droits des personnes (voir la procédure), AIPD, violations (notification au club sans délai).
- **Fin du contrat** : export du club (sauvegarde v5), puis effacement des données du club ; sauvegardes Google sous 180 jours pour Auth.
- **Audit** : le club peut demander les preuves de conformité.
- **Si une fédération devient responsable** : l'accord est repris à l'identique avec la fédération comme responsable ; les clubs deviennent utilisateurs.

Signatures et dates : `[à renseigner]`. Validation juridique : `[fédération ou DPO]`.
