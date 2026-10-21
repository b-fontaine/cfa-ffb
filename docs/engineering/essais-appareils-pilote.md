# Essais sur les appareils du club pilote

Prérequis **P2** de [roadmap.md](roadmap.md) (« Avant la première invitation réelle »), qui **bloque la première invitation réelle** et non le déploiement ; il se joue à l'étape D7 de la mise en service, en parallèle du développement. Appareils retenus le 2026-10-21 : ordinateur Chrome ou Edge, Android (Chrome ou application web installée), iPhone ou iPad (Safari **et** application ajoutée à l'écran d'accueil). Les applications natives Android et iOS ne sont **pas** dans le pilote : elles ne seront publiées que lorsque le web sera adopté.

À faire par l'animateur, sur chaque appareil, **sur l'URL déployée** (build `firestore`), avec des **données fictives** : aucun animateur réel n'est concerné et l'URL n'est partagée avec personne. Noter le résultat dans le tableau en bas ; un seul échec bloque la première invitation réelle pour cet appareil.

## Préparation (une fois par appareil)

1. **Avant le déploiement** (étape D4), tant que la version précédente (build qui garde les données en local) est celle qui est en ligne : l'ouvrir sur l'appareil, à l'adresse qui sera celle de l'essai. Après le déploiement, le build `firestore` n'écrit plus en local : les données fictives ne peuvent plus être créées.
2. Saisir quelques données de test : 2 élèves fictifs, 1 groupe, 1 séance planifiée, 3 passages.
3. Ne pas les supprimer : elles servent à l'essai de détection.

## Essais (sur l'URL déployée, build `firestore`, même origine que la préparation)

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

Quand tous les appareils du pilote ont réussi, noter le prérequis P2 comme levé dans `roadmap.md` (« Avant la première invitation réelle ») avec la date et le tableau ci-dessus.
