# Lacunes et questions ouvertes

## Ce que la base **ne contient pas**

- Durées des séances (1 h 30 / 2 h) : contrainte projet, aucune source.
- Distinction enfants/adultes autre que la casse.
- Règles officielles du Blackball (à ingérer depuis la FFB ou la WPA).
- Contenu de l'épreuve du billard de bronze.
- Positions exactes des billes : les schémas sont transcrits dans `03-exercices/diagrammes/` mais en lecture **approchée** (≈ 0,15 case), jamais publiée par la FFB sous cette forme.
- Rayon de bille (0,1 unité) et ligne de départ (x = 2,0) : `[Prop]` ; la ligne dessinée est lue vers x ≈ 1,75 à 1,85. **Écart à corriger** : `FORMAT.md` et le code utilisent un rayon unique pour toutes les billes, alors que la blanche est plus petite (48,0 contre 50,8 mm `[FFB]`, rapport 0,945 ; voir `02-techniques/06-dimensions-du-materiel.md`). La règle `[FFB]` place la ligne à 1/5 de la longueur (x = 1,6 sur 8 cases).
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

## Questions encore ouvertes

1. Faut-il valider les positions approchées des diagrammes par un animateur (comparaison au PDF) avant de les afficher dans l'application ?
2. Quelle valeur de « séance » pour les nombres conseillés (1 séance = 90 min enfant / 120 min adulte) ?
3. Combien d'élèves par groupe et de groupes par saison (dimensionnement du suivi) ?
4. Besoin de synchronisation multi-appareils (téléphone + ordinateur) ? Si oui, Firebase devient pertinent.

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
