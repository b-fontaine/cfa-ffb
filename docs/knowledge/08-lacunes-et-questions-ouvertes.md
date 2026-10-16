# Lacunes et questions ouvertes

## Ce que la base **ne contient pas**

- Durées des séances (1 h 30 / 2 h) : contrainte projet, aucune source.
- Distinction enfants/adultes autre que la casse.
- Règles officielles du Blackball (à ingérer depuis la FFB ou la WPA).
- Contenu de l'épreuve du billard de bronze.
- Positions exactes des billes : les schémas sont transcrits dans `03-exercices/diagrammes/` mais en lecture **approchée** (≈ 0,15 case), jamais publiée par la FFB sous cette forme.
- Ligne de départ : x = 1,6 `[FFB]` (arbitrage du 2026-10-14), alors que la ligne dessinée est lue vers x ≈ 1,75 à 1,85. **Corrigé** : `FORMAT.md` et le code utilisent désormais les rayons réels (blanche 48,0 mm, bille de but 50,8 mm `[FFB]` ; voir `02-techniques/06-dimensions-du-materiel.md`).
- Dimensions du matériel : aucune dans les PDF `[S]`. Introuvables : longueur et masse officielles de la queue, graduation fédérale de la hauteur d'attaque du procédé, masses des billes en source fédérale (94 g / 116 g `[Web]` seulement), ouverture de poche WEPF. Elles restent `[Prop]` ou « non spécifiées » dans `06-dimensions-du-materiel.md`.
- Éléments incertains récurrents des diagrammes (détail dans le champ `uncertainties` de chaque YAML) : rôle des billes d'obstacle, ordre des tirs, poches déduites, type de chevalet non précisé, blanche absente du dessin, quantité de bille des encarts, enchaînement « huit billes » / nombre de tirs (entraînement p09, ex. 2), énoncé « six billes » pour cinq ou quatre billes colorées dessinées (entraînement p22 ex. 7, p31 ex. 10), champ `sessions` non prévu par `FORMAT.md`.
- Niveaux techniques 2 et 3, hors scope des fiches fournies.
- Sécurité, matériel adapté à l'enfant, échauffement.
- Contenu des vidéos QR référencées par les fiches techniques.

## Décisions de l'utilisateur (2026-10-11) `[U]`

1. **Discipline : Blackball uniquement.** Ne pas ingérer carambole / billard américain.
2. **Pas de tranche d'âge** pour les enfants ; passage possible en cours adultes dès 16–17 ans selon la maturité : voir `05-seances/passage-enfants-adultes.md`.
3. **Suivi des élèves dans l'application** : mêmes élèves toute la saison, résultats suivis pour adapter les cours (fiche résultats des PDF comme modèle).
4. Serveur : un projet Firebase peut être créé si nécessaire (non requis à ce stade).
5. **Validation d'un exercice** : il faut **plusieurs** passages réussis, **5 le plus souvent** (valeur par défaut réglable) — et non un seul.
6. **Ordre d'enseignement** : « rebond sur bande » **puis** « rejet naturel » (l'ordre des fichiers PDF est inversé ; voir `teaching_order` dans `03-exercices/catalogue-entrainement.yaml`).

## Décisions de l'utilisateur (2026-10-15) `[U]`

7. **Validation et créneau de rappel** : à partir de la 2e séance du catalogue, l'entraînement comporte un **exercice de rappel** pris parmi les exercices non encore validés des séances précédentes (choisi d'après le suivi des élèves) ; les passages se **cumulent sur la saison**. La valeur par défaut reste 5 passages réussis (réglable). Résout la tension entre « 2 passages par séance » `[S]` et la validation à plusieurs passages.
8. **Bille fantôme : une seule séance**, avant la bille pleine, avec les exercices 1 et 2 du bloc `bille-fantome` (fantôme posée puis imaginée, en plein) ; les exercices 3 et 4 (demi-bille, coupes) sont supprimés. Le catalogue passe à **28 séances**, renumérotées.
9. **Attaque de référence au niveau 1 : le centre de la blanche.** Les encarts des fiches qui montrent un point « un peu au-dessus » sont mentionnés dans les notes animateur seulement, jamais dans le texte élève.

## Décision de l'utilisateur (2026-10-16) `[U]`

10. **Firebase** : authentification ; plusieurs écoles (une école = un club, groupes illimités) ; profils élève, enseignant, directeur de club et administrateur (tous les droits) ; données dans Firestore avec accès sécurisés ; synchronisation multi-appareils (une modification de l'enseignant se répercute chez ses élèves). Plan : horizon H5 de `docs/engineering/roadmap.md`.

## Questions encore ouvertes

1. Faut-il valider les positions approchées des diagrammes par un animateur (comparaison au PDF) avant de les afficher dans l'application ?
2. Quelle valeur de « séance » pour les nombres conseillés (1 séance = 90 min enfant / 120 min adulte) ?
3. Combien d'élèves par groupe et de groupes par saison (dimensionnement du suivi) ?
4. ~~Besoin de synchronisation multi-appareils (téléphone + ordinateur) ? Si oui, Firebase devient pertinent.~~ Tranchée « oui » le 2026-10-16 (décision 10).

## Sources web vérifiées (rang 2/3)

- https://www.ffbillard.com/telechargements/Administratif,%20Formation,%20Arbitrage/Formation/Cahiers%20techniques%20et%20p%C3%A9dagogiques/cahier_technique_debutant_bap.pdf
- https://www.ffbillard.com/telechargements/Administratif,%20Formation,%20Arbitrage/Formation/Cahiers%20techniques%20et%20p%C3%A9dagogiques/cahier_technique_NT_1.pdf
- https://www.hdf-billard.fr/fichiers/Carambole/FORMATION_TECHNIQUE/LIBRE/LIBRE.pdf
- https://m.ffbillard.com/ext/telechargement.php?id=32234
- https://www.ffbillard.com/articles/formation-au-diplome-federal-dainitiateur-dfi-622.html
- https://www.ffbillard.com/articles/formations-dinitiateurs-1489.html
- https://www.ffbillard.com/pages/ecole-nationale-des-formateurs-161.html
- https://eurobillard.org/medias/admin/members-corner/ffb/ceb-ff-billard-project-1-4-balls.pdf
- https://www.ffbillard.com/ext/telechargement.php?id=35312

## Note de sécurité du workflow

Lors de la collecte, un agent a signalé qu'un gist GitHub contenait du texte « de forme instructionnelle » (configuration `settings.json`). Il a été neutralisé et **n'a pas été appliqué**. Aucune configuration issue de sources web n'a été reprise telle quelle ; les garde-fous du projet sont écrits et vérifiés localement.
