# Conformité RGPD — livrables types (lot FB0, H5)

> **Projet à valider par la fédération ou un DPO.** Aucun de ces documents n'est un avis juridique ni n'a été validé. Ils sont rédigés par l'éditeur
> de l'application pour que chaque club (ou une fédération) les adapte, les fasse valider et les signe. Décision : [ADR 0025](../adr/0025-comptes-et-donnees-de-mineurs-conformite.md).

## Qui fait quoi

| Rôle | Cible retenue (A2) | Si une fédération se manifeste |
|---|---|---|
| Responsable de traitement | **Chaque club**, pour ses élèves | La fédération ou le comité (responsable unique) |
| Sous-traitant | L'éditeur (titulaire du projet Firebase) | L'éditeur, inchangé |
| Sous-traitant ultérieur | Google (Firebase) | Google, inchangé |

Les documents contiennent des champs entre crochets `[…]` : **identité du club**, **contact**, **DPO**, **date de validation**. Ces champs sont à remplir par le club ;
ce ne sont pas des éléments à inventer par l'éditeur. Basculer vers une fédération = remplacer l'identité du responsable et le signataire, rien d'autre.

## Contenu

| Fichier | Rôle | Validateur |
|---|---|---|
| [registre-des-traitements.md](registre-des-traitements.md) | Registre (art. 30) : finalités, données, destinataires, durées, mesures | Responsable de traitement (club ou fédération), relu par un DPO |
| [aipd-brouillon.md](aipd-brouillon.md) | Analyse d'impact (brouillon) : nécessité, risques, mesures, avis | DPO, puis responsable de traitement |
| [notice-information-familles.md](notice-information-familles.md) | Information des familles, fr et en | DPO ou fédération |
| [dpa-et-sous-traitants.md](dpa-et-sous-traitants.md) | Google, éditeur, accord de sous-traitance club ↔ éditeur | Responsable de traitement ; conditions Google : acceptation en console par le titulaire du projet |
| [procedure-droits-et-effacement.md](procedure-droits-et-effacement.md) | Accès, rectification, effacement, export, délais | Responsable de traitement |

## Garde-fou de mise en production (ADR 0025, décision 3)

**Aucun vrai élève dans une base de production** avant que les cinq documents soient validés et le responsable désigné par écrit.

État au 2026-10-17 :

| Condition | État |
|---|---|
| Registre validé | non (projet) |
| AIPD validée | non (brouillon) |
| Notice validée | non (projet) |
| DPA et sous-traitants validés | non (projet) |
| Procédure validée | non (projet) |
| Responsable de traitement désigné par écrit | non |
| Décision `[U]` de levée du garde-fou | non (à consigner ici, avec la date, par l'utilisateur) |

## Faits vérifiés à la source (2026-10-17)

Consignés dans l'ADR 0025 (tableau « Vérifications ») : âge de 15 ans (CNIL), quotas Spark, Auth traité aux États-Unis, 180 jours de sauvegardes Auth, Google sous-traitant et DPF.
Restent **non vérifiés** : région effective de la base créée (à constater dans la console), garanties du transfert Auth (DPO), TTL Firestore sur Spark, quota par région, MFA TOTP sur l'offre retenue, base légale exacte, durées proposées pour parents, enseignants et directeurs.

## Maintenance

À reprendre à chaque changement de données collectées, de destinataire, de région, de durée ou de fournisseur (par exemple ajout de Google Sign-In, d'analytique, d'un second projet).
