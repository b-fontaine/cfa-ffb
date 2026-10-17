# Analyse d'impact (AIPD) — brouillon, projet à valider par la fédération ou un DPO

Statut : **brouillon, non validé** (2026-10-17). L'avis du DPO, la décision du responsable et la date de validation sont à renseigner par eux. Une validation est un préalable à tout vrai élève en production (ADR 0025, décision 3).

## 1. Pourquoi une AIPD

Critères probables du G29 / CNIL réunis : personnes vulnérables (mineurs), données collectées à grande échelle potentielle (plusieurs clubs), croisement de plusieurs organismes (clubs, éditeur, Google), transfert hors UE (Auth). Aucune donnée sensible, aucun profilage automatique, aucune décision automatisée. Par prudence, l'AIPD est conduite ; `[le DPO peut conclure qu'elle n'est pas obligatoire pour un petit club : à valider]`.

## 2. Description du traitement

Voir le [registre](registre-des-traitements.md). Résumé : suivi des résultats d'exercices de billard par prénom + initiale, groupes par saison, accès par rôle (élève ou parent, enseignant, directeur, administrateur), synchronisation Firestore `europe-west9`, Auth aux États-Unis, cache hors ligne.

## 3. Nécessité et proportionnalité

| Principe | Appréciation |
|---|---|
| Finalité déterminée | Adapter les séances aux progrès des élèves de la saison |
| Minimisation | Prénom + initiale, public, présences, résultats ; pas d'âge (case « 15 ans » déclarative), pas de santé, pas de photo ; un seul texte libre, le commentaire d'évaluation (facultatif, borné, voir R11). Prénom + initiale = minimisation, **pas pseudonymisation** |
| Exactitude | Saisie par l'enseignant ; correction possible (ADR 0006) |
| Conservation | Saison en cours + suivante ; effacement à la demande ; purge lancée par le directeur (non automatique). `[Durée proposée, à valider par le DPO]` |
| Information | Notice avant l'invitation et à la première connexion |
| Droits | Procédure sous un mois ; export JSON et PDF d'un élève |
| Sous-traitants | Google : conditions de traitement et DPF ; éditeur : accord à signer par le club |
| Transfert | Auth aux États-Unis : DPF et clauses contractuelles types, `[garanties de transfert à valider par le DPO]` ; données de suivi en France |

## 4. Risques

Vraisemblance et gravité : valeurs `[Prop]` de l'éditeur, **à réévaluer par le DPO**.

| # | Risque | Source | Gravité | Vraisemblance | Mesures |
|---|---|---|---|---|---|
| R1 | Accès illégitime à des prénoms de mineurs | Règles trop larges, compte compromis, clé d'API publique | Moyenne | Faible | Refus par défaut ; règles testées par rôle et par club ; App Check ; e-mail vérifié ; code d'invitation à usage unique ; MFA directeur et admin à étudier |
| R2 | Accès excessif des administrateurs | Rôle global lisant tous les clubs | Moyenne | Faible | Un à deux comptes, nommés au registre, `write: false` sur `admins` ; pas de journal d'accès (limite) |
| R3 | Conservation excessive | Purge non automatique, club inactif | Moyenne | Moyenne | Bandeau puis blocage de saisie à l'échéance ; purge forcée par l'administrateur ; notice honnête |
| R4 | Fuite par cache hors ligne web | IndexedDB en clair sur appareil partagé | Moyenne | Moyenne | Vidage à la déconnexion ; avertissement ; persistance seulement dans la session de l'utilisateur |
| R5 | Fuite par fichier exporté | Sauvegarde JSON, PDF | Moyenne | Moyenne | Avertissement ; PDF sans donnée nominative par défaut (ADR 0021) ; hors portée de l'effacement : dit dans la notice |
| R6 | Transfert hors UE (Auth) | Service Auth traité aux États-Unis | Faible | Certaine | Seuls les e-mails d'adultes ; DPF et clauses, `[garanties de transfert à valider par le DPO]` ; aucun e-mail d'élève sous 15 ans |
| R7 | Réidentification | Prénom + initiale dans un petit groupe | Faible | Moyenne | Non-pseudonymisation assumée ; visibilité limitée au groupe ; archive agrégée à seuil de 3 |
| R8 | Résurrection de données effacées | Appareil retardataire, sauvegarde importée | Moyenne | Faible | Règle `exists()` sur la fiche ; import refusé pour une saison close ; avertissement |
| R9 | Fausse déclaration « 15 ans » | Case déclarative | Faible | Moyenne | Responsabilité du club ; parent conserve la lecture |
| R10 | Perte d'accès ou de disponibilité | Quota Spark, panne Google | Faible | Faible | Hors ligne ; sauvegarde JSON ; quotas surveillés |
| R11 | Commentaire d'évaluation contenant des données sensibles ou sur un tiers | `MaturityAssessment.comment`, texte libre sur un mineur | Haute | Moyenne | Facultatif, borné à `maxCommentLength`, consigne aux animateurs (ni santé, ni tiers), accès limité aux rôles animateurs (exclu de la vue parent et élève), effaçable avec la fiche ; la note de jeu (ADR 0023) reste sans texte libre. Gravité et vraisemblance `[Prop]`, à réévaluer par le DPO |
| R12 | Compte parent détourné | Mot de passe faible | Moyenne | Faible | 10 caractères, e-mail vérifié, réinitialisation, App Check |

## 5. Mesures complémentaires prévues (lots FB1 à FB8)

Tests de règles en CI ; App Check (surveillance puis strict) ; MFA à étudier ; purge par lots ; export d'un élève ; clearPersistence ; deux projets Firebase à l'arrivée de vrais élèves ; SDK web servi localement avant FB5 si possible (retire gstatic, une transmission d'IP à Google).

## 6. Risques résiduels

`[À évaluer par le DPO après mesures.]` Éléments connus : Auth hors UE, purge dépendante d'un humain, absence de journal d'accès.

## 7. Avis et validation

| Rôle | Nom | Avis | Date |
|---|---|---|---|
| DPO | `[à renseigner]` | `[à renseigner]` | `[à renseigner]` |
| Responsable de traitement | `[à renseigner]` | `[à renseigner]` | `[à renseigner]` |
| Personnes concernées (consultation éventuelle) | `[à décider par le responsable]` | | |

Consultation préalable de la CNIL si un risque élevé subsiste : `[décision du DPO]`.
