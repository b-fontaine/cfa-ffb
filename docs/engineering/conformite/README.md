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

## Mises à jour liées aux lots (aucune n'est validée)

| Date | Lot | Documents touchés |
|---|---|---|
| 2026-10-19 | FB6, espace élève et parent | [registre](registre-des-traitements.md) (traitement 1 bis : ce que voit un parent ou un élève, ce qui n'est jamais lu, retrait du lien, hors ligne, journaux) ; [notice](notice-information-familles.md) (section « Ce que montre l'espace famille », fr et en, **texte de projet**) ; contrôle `scripts/check_family_register.dart` (chaque lecture de `family_reads.json` nommée au registre, [quality-gates](../quality-gates.md)) |

À signaler au DPO pour FB6 : (1) depuis le lot de bascule (2026-10-21) le build par défaut lit Firestore pour **tous** les rôles dès son déploiement (aucun aiguillage par rôle, ADR 0024 notes FB6) ; la garde A3 (aucune invitation réelle avant validation de la conformité, ADR 0025) est ce qui empêche toute lecture réelle de mineurs avant ; (1 bis) structure « affiché / reçu sans être affiché » : l'appareil **reçoit et met en cache sans l'afficher** la **fiche entière** de l'élève (public, historique daté des changements de public, groupes courants, date de création ; seul le prénom est affiché), **tous** les passages de la fiche liée (échecs compris, avec date, séance et groupe : la présence s'en déduit), les **acquis** (date et source `placement`), `settings/main` en entier, le document de chaque groupe (identifiants de compte des enseignants, données d'un tiers), toutes les séances de ces groupes, passées comprises, le **propre `member`** (nom affiché, rôle, groupes, fiches, code d'invitation utilisé) et, à la connexion, `clubs/{club}` (nom, saison courante), l'existence de `admins/{uid}` et la requête de groupe sur `members` ; les **alertes** ne sont jamais stockées côté serveur : elles sont **calculées sur l'appareil** à partir des passages et de `settings/main`, même sans les « Vu », et masquées à l'affichage seulement ; seuls les « Vu » ne sont jamais lus (liste exacte : `scripts/rules_test/family_reads.json`, **contrôlée** contre le registre par `scripts/check_family_register.dart`) ; (2) le **titre d'une séance** est un texte libre de l'animateur visible de toute la famille du groupe ; (3) le sélecteur d'enfant n'affiche que le prénom et son initiale (pas d'initiale du nom) ; (4) quand le club retire un lien, l'écran passe en direct à « Accès retiré » (écoute du `member`) ; côté serveur les nouvelles lectures sont refusées, une écoute déjà ouverte n'est refusée qu'à la prochaine modification d'une séance ou du document de ce groupe (un renommage suffit), ou du document écouté ; le cache de l'appareil est vidé à la déconnexion.

## Faits vérifiés à la source (2026-10-17)

Consignés dans l'ADR 0025 (tableau « Vérifications ») : âge de 15 ans (CNIL), quotas Spark, Auth traité aux États-Unis, 180 jours de sauvegardes Auth, Google sous-traitant et DPF.
Restent **non vérifiés** : région effective de la base créée (à constater dans la console), garanties du transfert Auth (DPO), TTL Firestore sur Spark, quota par région, MFA TOTP sur l'offre retenue, base légale exacte, durées proposées pour parents, enseignants et directeurs.

## Maintenance

À reprendre à chaque changement de données collectées, de destinataire, de région, de durée ou de fournisseur (par exemple ajout de Google Sign-In, d'analytique, d'un second projet).
