# Essais sur les appareils du club pilote

Prérequis **bloquant** de la bascule (voir [roadmap.md](roadmap.md), « Prérequis bloquants avant la bascule », point 7). Appareils retenus le 2026-10-21 : ordinateur Chrome ou Edge, Android (Chrome ou application web installée), iPhone ou iPad (Safari **et** application ajoutée à l'écran d'accueil). Les applications natives Android et iOS ne sont **pas** dans le pilote : elles ne seront publiées que lorsque le web sera adopté.

À faire par l'animateur, sur chaque appareil, **avant** de fusionner le lot de bascule, sur le **canal de prévisualisation** (autre origine : les données locales réelles n'y sont pas visibles, on y prépare donc des données de test). Noter le résultat dans le tableau en bas ; un seul échec bloque la bascule pour cet appareil.

## Préparation (une fois par appareil)

1. Ouvrir la **version actuelle** (build qui garde les données en local) sur l'origine habituelle de l'appareil, ou sur le canal de prévisualisation de cette version si elle y est déployée.
2. Saisir quelques données de test : 2 élèves fictifs, 1 groupe, 1 séance planifiée, 3 passages.
3. Ne pas les supprimer : elles servent à l'essai de détection.

## Essais (sur le canal de prévisualisation du build `firestore`, même origine que l'étape 1)

| N° | Essai | Résultat attendu |
|----|-------|------------------|
| 1 | Ouvrir l'application sur l'appareil, sans se connecter | Un bandeau annonce des données locales avec leurs compteurs (2 élèves, 3 passages…) |
| 2 | Toucher l'export local | Les compteurs du fichier s'affichent **avant** l'enregistrement, identiques à ceux du bandeau |
| 3 | Enregistrer le fichier | Le fichier est bien téléchargé et **retrouvable** (dossier Téléchargements, app Fichiers sur iPhone) ; il se rouvre |
| 4 | Se connecter avec un compte de test du club, importer le fichier | Le parcours d'import se déroule jusqu'au résumé ; les 2 élèves et 3 passages sont visibles dans le club |
| 5 | Fermer tous les onglets puis rouvrir l'application | Les données du club sont là ; le bandeau n'a pas disparu tant qu'on n'a pas confirmé |
| 6 | Essai avec une base **vide** (autre navigateur du même appareil) | Aucun bandeau ; un export est signalé vide, **jamais** « sauvegarde réussie » |

## Essais propres à l'iPhone et à l'iPad

| N° | Essai | Résultat attendu |
|----|-------|------------------|
| 7 | Faire les essais 1 à 6 d'abord dans **Safari**, puis dans l'**application ajoutée à l'écran d'accueil** | Chaque endroit voit **ses propres** données ; l'application installée n'hérite **pas** des données de Safari (stockage séparé) : un export depuis le mauvais endroit est signalé vide |
| 8 | Dans l'application ajoutée à l'écran d'accueil, enregistrer le fichier (essai 3) | Le téléchargement n'est pas bloqué ni ouvert en simple aperçu sans moyen de l'enregistrer. **Si le fichier ne peut pas être récupéré, c'est un échec bloquant** : noter l'écran exact |
| 9 | Laisser l'application inutilisée plusieurs jours puis la rouvrir | Les données locales sont encore là ; sinon c'est la purge du stockage par Safari : le fichier exporté est alors le seul repli, d'où l'export le plus tôt possible |

## Essais propres à Android

| N° | Essai | Résultat attendu |
|----|-------|------------------|
| 10 | Essais 1 à 6 dans **Chrome**, puis dans l'**application web installée** | Les deux voient les mêmes données si Chrome et l'application installée partagent le stockage ; sinon le noter |
| 11 | Enregistrer le fichier (essai 3) | Retrouvable dans Téléchargements |

## Résultats

| Appareil | Navigateur / mode | Essais réussis | Échecs (écran, message) | Date |
|----------|-------------------|----------------|-------------------------|------|
| | | | | |

Quand tous les appareils du pilote ont réussi, cocher le point 7 de la liste des prérequis dans `roadmap.md` avec la date et le tableau ci-dessus.
