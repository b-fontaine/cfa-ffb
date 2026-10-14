# Diagrammes d'exercices

Transcription **en YAML** des schémas de table des PDF de `docs/sources/` `[S]` (positions des billes,
trajectoires, quantité de bille, chevalet), pour qu'un agent texte les comprenne et que l'application
génère des visuels animés (table, billes, queue du design system).

- Format, repère et conventions de lecture : [`FORMAT.md`](FORMAT.md) (à lire en premier).
- Un fichier = une page de PDF : `<dossier>/pNN.yaml`, `NN` = numéro de page sur 2 chiffres.
- Règle d'or : ne rien inventer ; tout doute est consigné dans `uncertainties`.

## Dossiers

| Dossier | PDF source |
|---------|-----------|
| `entrainement/` | Fiches d'entraînement |
| `initiation/` | Fiches d'initiation |
| `jeux/` | Fiches de jeux |
| `techniques/` | Fiches techniques |
| `proposition/` | **Aucun PDF** : mise en place `[Prop]` des blocs d'entraînement proposés (`posture`, `bille-fantome`), `rank: Prop` ; voir `FORMAT.md` § 3 |

## Valider et rendre

Depuis `app/` (aucune dépendance en plus de `package:yaml`) :

```bash
cd app
dart run tool/diagrammes.dart ../docs/knowledge/03-exercices/diagrammes/entrainement/p03.yaml
dart run tool/diagrammes.dart --ascii <fichier.yaml…>     # rendu texte 8x4 + légende
dart run tool/diagrammes.dart --summary <fichier.yaml…>   # une ligne par diagramme
dart run tool/diagrammes.dart --ghosts <fichier.yaml…>    # cercles impact des propositions = G calculé
```

- Code de sortie `0` : valide ; `1` : erreur de validation ; `2` : usage ou fichier introuvable.
- Une bille hors table ou deux billes qui se chevauchent (seuils `r_c + r_o` blanche - bille de but, `2 r_o` entre billes de but, à 0,01 case près) ou une bille qui mord sur une bande produisent un **avertissement** (pas une erreur).
- Le rendu ASCII sert de contrôle : le comparer au PDF (`pdftoppm -r 110 -f N -l N -png`).
- Code : `app/tool/diagrammes.dart` et `app/tool/diagrammes/` ; tests : `app/test/tool/diagrammes_test.dart`.

## Index

### Par PDF

| Dossier | PDF `[S]` | Fichiers | Diagrammes | Pages |
|---------|-----------|----------|------------|-------|
| `entrainement/` | Fiches Entrainement CFA blackball.pdf | 34 | 68 | 1 à 34 |
| `initiation/` | Fiches Initiation CFA blackball.pdf | 19 | 21 | 1 à 19 |
| `jeux/` | Fiches Jeux CFA blackball.pdf | 14 | 14 | 1 à 14 |
| `techniques/` | Fiches techniques CFA BàP.pdf | 25 | 88 | 1 à 25 |
| `proposition/` | aucun (`[Prop]`, « Proposition (hors PDF) ») | 2 | 8 | 1 à 2 (rang de la page proposition) |

Total : 94 fichiers (92 pages de PDF `[S]` + 2 pages `[Prop]`). Les pages techniques 1 et 2 (couverture, page blanche) ne portent aucun diagramme.

### Par fiche

Légende : chevalet = `cadre` (sur cadre), `surface` (sur la surface de jeu), `non précisé` (le PDF ne le dit pas), `sans`. Taux = réussites / tentatives. BB = pastille « Billard de bronze ».

#### Entraînement (`entrainement/`)

| Bloc | Exercice | Page | Id de diagramme | Taux | Chevalet | BB |
|------|----------|------|-----------------|------|----------|----|
| 1. La puissance | E1 | 1 | `entrainement-p01-e1` | 7/9 | cadre | non |
| 1. La puissance | E2 | 1 | `entrainement-p01-e2` | 5/10 | cadre | non |
| 1. La puissance | E3 | 2 | `entrainement-p02-e3` | 5/10 | surface | non |
| 1. La puissance | E4 | 2 | `entrainement-p02-e4` | 5/8 | surface | non |
| 2. Quantité de bille pleine | E1 | 3 | `entrainement-p03-e1` | 6/8 | cadre | oui |
| 2. Quantité de bille pleine | E2 | 3 | `entrainement-p03-e2` | 4/6 | surface | oui |
| 2. Quantité de bille pleine | E3 | 4 | `entrainement-p04-e3` | 6/8 | surface | oui |
| 2. Quantité de bille pleine | E4 | 4 | `entrainement-p04-e4` | 6/8 | cadre | oui |
| 3. Quantité demi-bille | E1 | 5 | `entrainement-p05-e1` | 4/6 | non précisé | oui |
| 3. Quantité demi-bille | E2 | 5 | `entrainement-p05-e2` | 6/8 | surface | oui |
| 3. Quantité demi-bille | E3 | 6 | `entrainement-p06-e3` | 6/8 | cadre | oui |
| 3. Quantité demi-bille | E4 | 6 | `entrainement-p06-e4` | 4/8 | non précisé | oui |
| 4. Quantité trois-quarts | E1 | 7 | `entrainement-p07-e1` | 6/8 | cadre | oui |
| 4. Quantité trois-quarts | E2 | 7 | `entrainement-p07-e2` | 6/8 | non précisé | oui |
| 4. Quantité trois-quarts | E3 | 8 | `entrainement-p08-e3` | 6/8 | surface | oui |
| 4. Quantité trois-quarts | E4 | 8 | `entrainement-p08-e4` | 6/8 | cadre | oui |
| 5. Quart de bille et finesses | E1 | 9 | `entrainement-p09-e1` | 6/8 | surface | oui |
| 5. Quart de bille et finesses | E2 | 9 | `entrainement-p09-e2` | 8/12 | non précisé | oui |
| 5. Quart de bille et finesses | E3 | 10 | `entrainement-p10-e3` | 4/8 | surface | oui |
| 5. Quart de bille et finesses | E4 | 10 | `entrainement-p10-e4` | 4/8 | surface | oui |
| 6. Les quantités de billes | E1 | 11 | `entrainement-p11-e1` | 5/7 | non précisé | oui |
| 6. Les quantités de billes | E2 | 11 | `entrainement-p11-e2` | 6/8 | non précisé | oui |
| 6. Les quantités de billes | E3 | 12 | `entrainement-p12-e3` | 6/9 | non précisé | oui |
| 6. Les quantités de billes | E4 | 12 | `entrainement-p12-e4` | 5/8 | non précisé | oui |
| 7. Le rejet naturel (1re occurrence) | E1 | 13 | `entrainement-p13-e1` | 3/5 | non précisé | non |
| 7. Le rejet naturel (1re occurrence) | E2 | 13 | `entrainement-p13-e2` | 3/5 | non précisé | non |
| 7. Le rejet naturel (1re occurrence) | E3 | 14 | `entrainement-p14-e3` | 3/5 | non précisé | non |
| 7. Le rejet naturel (1re occurrence) | E4 | 14 | `entrainement-p14-e4` | 3/5 | non précisé | non |
| 8. Rebond sur une bande | E1 | 15 | `entrainement-p15-e1` | 3/5 | non précisé | non |
| 8. Rebond sur une bande | E2 | 15 | `entrainement-p15-e2` | 3/5 | non précisé | non |
| 8. Rebond sur une bande | E3 | 16 | `entrainement-p16-e3` | 2/3 | non précisé | non |
| 8. Rebond sur une bande | E4 | 16 | `entrainement-p16-e4` | 2/3 | non précisé | non |
| 9. Le rejet naturel (2e occurrence) | E1 | 17 | `entrainement-p17-e1` | 3/5 | non précisé | non |
| 9. Le rejet naturel (2e occurrence) | E2 | 17 | `entrainement-p17-e2` | 3/5 | non précisé | non |
| 9. Le rejet naturel (2e occurrence) | E3 | 18 | `entrainement-p18-e3` | 3/5 | non précisé | non |
| 9. Le rejet naturel (2e occurrence) | E4 | 18 | `entrainement-p18-e4` | 3/5 | non précisé | non |
| 10. Le coulé | E1 | 19 | `entrainement-p19-e1` | 3/5 | non précisé | non |
| 10. Le coulé | E2 | 19 | `entrainement-p19-e2` | 3/5 | non précisé | non |
| 10. Le coulé | E3 | 20 | `entrainement-p20-e3` | 8/12 | non précisé | non |
| 10. Le coulé | E4 | 20 | `entrainement-p20-e4` | 6/10 | non précisé | non |
| 10. Le coulé | E5 | 21 | `entrainement-p21-e5` | 3/5 | non précisé | non |
| 10. Le coulé | E6 | 21 | `entrainement-p21-e6` | 3/5 | non précisé | non |
| 10. Le coulé | E7 | 22 | `entrainement-p22-e7` | 4/6 | non précisé | non |
| 10. Le coulé | E8 | 22 | `entrainement-p22-e8` | 3/5 | non précisé | non |
| 11. Le carreau | E1 | 23 | `entrainement-p23-e1` | 3/5 | non précisé | non |
| 11. Le carreau | E2 | 23 | `entrainement-p23-e2` | 3/5 | non précisé | non |
| 11. Le carreau | E3 | 24 | `entrainement-p24-e3` | 3/5 | non précisé | non |
| 11. Le carreau | E4 | 24 | `entrainement-p24-e4` | 3/5 | non précisé | non |
| 12. Le coup en angle droit | E1 | 25 | `entrainement-p25-e1` | 3/5 | non précisé | non |
| 12. Le coup en angle droit | E2 | 25 | `entrainement-p25-e2` | 3/5 | non précisé | non |
| 12. Le coup en angle droit | E3 | 26 | `entrainement-p26-e3` | 3/5 | non précisé | non |
| 12. Le coup en angle droit | E4 | 26 | `entrainement-p26-e4` | 3/5 | non précisé | non |
| 13. Le rétro | E1 | 27 | `entrainement-p27-e1` | 3/5 | non précisé | non |
| 13. Le rétro | E2 | 27 | `entrainement-p27-e2` | 3/5 | cadre | non |
| 13. Le rétro | E3 | 28 | `entrainement-p28-e3` | 4/6 | non précisé | non |
| 13. Le rétro | E4 | 28 | `entrainement-p28-e4` | 4/6 | non précisé | non |
| 13. Le rétro | E5 | 29 | `entrainement-p29-e5` | 3/5 | non précisé | non |
| 13. Le rétro | E6 | 29 | `entrainement-p29-e6` | 3/5 | cadre | non |
| 13. Le rétro | E7 | 30 | `entrainement-p30-e7` | 4/6 | non précisé | non |
| 13. Le rétro | E8 | 30 | `entrainement-p30-e8` | 3/5 | non précisé | non |
| 13. Le rétro | E9 | 31 | `entrainement-p31-e9` | 3/5 | non précisé | non |
| 13. Le rétro | E10 | 31 | `entrainement-p31-e10` | 4/6 | non précisé | non |
| 14. Les trajectoires de blanche | E1 | 32 | `entrainement-p32-e1` | 6/9 | non précisé | non |
| 14. Les trajectoires de blanche | E2 | 32 | `entrainement-p32-e2` | 6/10 | non précisé | non |
| 14. Les trajectoires de blanche | E3 | 33 | `entrainement-p33-e3` | 6/9 | non précisé | non |
| 14. Les trajectoires de blanche | E4 | 33 | `entrainement-p33-e4` | 6/10 | non précisé | non |
| 14. Les trajectoires de blanche | E5 | 34 | `entrainement-p34-e5` | 6/9 | non précisé | non |
| 14. Les trajectoires de blanche | E6 | 34 | `entrainement-p34-e6` | 10/15 | non précisé | non |

#### Blocs proposés `[Prop]` (`proposition/`, hors PDF)

Pas de pastille « Billard de bronze » : mention fédérale, absente des propositions. Taux = taux `[Prop]` du bloc du catalogue.

| Bloc | Exercice | Page | Id de diagramme | Taux | Chevalet |
|------|----------|------|-----------------|------|----------|
| Posture, visée et coup de queue | E1 | 1 | `proposition-p01-e1` | 3/4 | cadre |
| Posture, visée et coup de queue | E2 | 1 | `proposition-p01-e2` | 3/4 | surface |
| Posture, visée et coup de queue | E3 | 1 | `proposition-p01-e3` | 6/8 | surface |
| Posture, visée et coup de queue | E4 | 1 | `proposition-p01-e4` | 4/6 | non précisé (au choix) |
| Viser pour empocher (bille fantôme) | E1 | 2 | `proposition-p02-e1` | 3/4 | cadre |
| Viser pour empocher (bille fantôme) | E2 | 2 | `proposition-p02-e2` | 3/4 | cadre |
| Viser pour empocher (bille fantôme) | E3 | 2 | `proposition-p02-e3` | 4/6 | surface |
| Viser pour empocher (bille fantôme) | E4 | 2 | `proposition-p02-e4` | 4/6 | surface |

#### Initiation (`initiation/`)

| Fiche | Notion | Page | Id de diagramme | Chevalet |
|-------|--------|------|-----------------|----------|
| 1 | Posture, visée et coup de queue | 1 | `initiation-p01-e1` | cadre |
| 2 | Posture, visée et coup de queue | 2 | `initiation-p02-e1` | surface |
| 3 | Posture, visée et coup de queue | 3 | `initiation-p03-e1` | surface |
| 4 | Posture, visée et coup de queue | 4 | `initiation-p04-e1` | surface |
| 5 | La puissance | 5 | `initiation-p05-e1` | non précisé |
| 6 | Quantité de bille pleine | 6 | `initiation-p06-e1` | non précisé |
| 6 | Quantité de bille pleine | 6 | `initiation-p06-e2` | non précisé |
| 7 | La quantité demi-bille | 7 | `initiation-p07-e1` | non précisé |
| 8 | La quantité trois-quarts de bille | 8 | `initiation-p08-e1` | non précisé |
| 9 | Les quantités quart-de-bille et finesses | 9 | `initiation-p09-e1` | surface |
| 10 | La casse | 10 | `initiation-p10-e1` | non précisé |
| 11 | Le rebond d'une bille sur une bande | 11 | `initiation-p11-sa` | non précisé |
| 11 | Le rebond d'une bille sur une bande | 11 | `initiation-p11-sb` | non précisé |
| 12 | Le rejet naturel | 12 | `initiation-p12-e1` | non précisé |
| 13 | Le coulé en quantité de bille pleine | 13 | `initiation-p13-e1` | non précisé |
| 14 | Le coulé en quantité de bille trois-quarts | 14 | `initiation-p14-e1` | non précisé |
| 15 | Le carreau | 15 | `initiation-p15-e1` | non précisé |
| 16 | Le coup en angle droit | 16 | `initiation-p16-e1` | non précisé |
| 17 | Le rétro en quantité de bille pleine | 17 | `initiation-p17-e1` | non précisé |
| 18 | Le rétro en quantité de bille trois-quarts | 18 | `initiation-p18-e1` | non précisé |
| 19 | Le rétro en quantité demi-bille | 19 | `initiation-p19-e1` | non précisé |

#### Jeux (`jeux/`)

| Jeu | Notion | Page | Id de diagramme | Chevalet |
|-----|--------|------|-----------------|----------|
| 1 | Posture, visée et coup de queue | 1 | `jeux-p01-j1` | non précisé |
| 2 | Posture, visée et coup de queue | 2 | `jeux-p02-j1` | non précisé |
| 3 | La puissance | 3 | `jeux-p03-g1` | non précisé |
| 4 | La puissance | 4 | `jeux-p04-j1` | sans |
| 5 | La puissance | 5 | `jeux-p05-j1` | sans |
| 6 | La quantité de bille pleine | 6 | `jeux-p06-j1` | cadre |
| 7 | La quantité demi-bille | 7 | `jeux-p07-g1` | non précisé |
| 8 | La quantité trois-quarts de bille | 8 | `jeux-p08-g1` | non précisé |
| 9 | La quantité quart de bille | 9 | `jeux-p09-j1` | non précisé |
| 10 | Les quantités de bille | 10 | `jeux-p10-j1` | non précisé |
| 11 | Les quantités de bille | 11 | `jeux-p11-j1` | non précisé |
| 12 | Fiche Jeu | 12 | `jeux-p12-j1` | non précisé |
| 13 | Le rebond d'une bille sur une bande | 13 | `jeux-p13-j1` | non précisé |
| 14 | Fiche Jeu | 14 | `jeux-p14-j1` | non précisé |

#### Techniques (`techniques/`)

Pas de table de billes : photos, schémas de principe et vignettes de vidéos (`kind: technique-photo` ou `technique-schema`). Les ids s’écrivent `techniques-pNN-<suffixe>`.

| Page | Fiche | Suffixes d’id |
|------|-------|---------------|
| 1 | Couverture | — (aucun diagramme) |
| 2 | Page blanche | — (aucun diagramme) |
| 3 | Présentation | `photo1` |
| 4 | Les fiches résultats | `resultats`, `onglets` |
| 5 | Fiche Technique N°1 : Posture, visée et coup de queue | `visee`, `video-visee` |
| 6 | Visée et posture | `photo1`, `photo2`, `photo3`, `photo4` |
| 7 | Visée et posture | `cas1`, `cas2`, `cas3`, `oeil-1`, `oeil-2`, `oeil-3` |
| 8 | Etape 3 : les chevalets | `cadre-1`, `cadre-2`, `angle-1`, `angle-2` |
| 9 | Les chevalets | `a-plat-large`, `a-plat-gros-plan`, `boucle-profil`, `boucle-dessus`, `video-chevalets`, `onglet` |
| 10 | Le coup de queue | `amplitude-1`, `amplitude-2`, `amplitude-3`, `maintenir-1`, `maintenir-2`, `maintenir-3`, `limage-1`, `limage-2`, `limage-3`, `video-queue`, `onglet` |
| 11 | Le coup de queue | `queue-desaxee-gauche`, `queue-desaxee-droite`, `epaule-en-mouvement`, `poignet-rigide` |
| 12 | La puissance | `amplitude-recul`, `amplitude-situation-initiale`, `amplitude-penetration`, `queue-faible-amplitude`, `queue-grande-amplitude`, `video-qr` |
| 13 | Fiche Technique N°3 : Viser pour empocher | `visualiser-trajectoire`, `video-viser-empocher` |
| 14 | La quantité de bille pleine | `point-impact-tip`, `alignement-plein`, `contact-equateur-13`, `contact-equateur-8` |
| 15 | La quantité de bille demi-bille | `demi-bille-vue-visee`, `tangente-rappel`, `demi-bille-deviation-30` |
| 16 | Fiche Technique N°6 : La quantité trois-quarts de bille | `vue-axe-trois-quarts`, `schema-deviation-15` |
| 17 | Fiche Technique N°7 : La quantité quart de bille | `schema-quart-de-bille`, `schema-visee-point-de-contact` |
| 18 | Fiche Technique N°8 : Les finesses | `contact-blanche-rouge`, `schema-finesse`, `video-finesse` |
| 19 | Le rebond d'une bille sur une bande | `angle-faible`, `angle-important`, `coup-a-la-mesure`, `coup-puissant` |
| 20 | Le rejet naturel | `attaque-haute`, `deviation-45`, `video-rejet-naturel` |
| 21 | Le coulé | `face-plein`, `face-trois-quarts`, `bille-pleine`, `bille-proche-du-plein`, `trois-quarts`, `capture-video`, `qr-code` |
| 22 | Le carreau | `roulement-glissement`, `carreau-schema`, `video-qr` |
| 23 | Fiche Technique N°13 : Le coup en angle droit | `angle-90`, `angle-sup-90`, `video-qr` |
| 24 | Fiche Technique N°14 : Le rétro | `phases-retro`, `retro-pleine-bille`, `retro-demi-bille` |
| 25 | Fiche Technique N°14 : Le rétro | `retro-90`, `retro-trois-quarts`, `video-utilite-retro` |

### Correspondance avec `catalogue-entrainement.yaml`

Le catalogue (copie d'asset synchronisée par `scripts/sync_catalogue.sh`) ne contient **pas** les positions : elles se trouvent ici. La jointure se fait par `blocks[].id` + `exercises[].n` ↔ diagramme `exercise`.

| `blocks[].id` du catalogue | Pages YAML (`entrainement/`) | Exercices |
|-----------------------------|-------------------------------|-----------|
| `puissance` | p01 à p02 | E1 à E4 |
| `bille-pleine` | p03 à p04 | E1 à E4 |
| `demi-bille` | p05 à p06 | E1 à E4 |
| `trois-quarts` | p07 à p08 | E1 à E4 |
| `quart-finesses` | p09 à p10 | E1 à E4 |
| `quantites-de-billes` | p11 à p12 | E1 à E4 |
| `rejet-naturel` | p13 à p14 | E1 à E4 |
| `rebond-bande` | p15 à p16 | E1 à E4 |
| `rejet-naturel (doublon)` | p17 à p18 | E1 à E4 |
| `coule` | p19 à p22 | E1 à E8 |
| `carreau` | p23 à p24 | E1 à E4 |
| `angle-droit` | p25 à p26 | E1 à E4 |
| `retro` | p27 à p31 | E1 à E10 |
| `trajectoires-blanche` | p32 à p34 | E1 à E6 |
| `posture` `[Prop]` | `proposition/` p01 | E1 à E4 |
| `bille-fantome` `[Prop]` | `proposition/` p02 | E1 à E4 |

Les deux dernières lignes viennent de `proposition/` (hors PDF, `[Prop]`), les autres de `entrainement/` `[S]`. Le bloc `rejet-naturel` apparaît deux fois dans le PDF (pages 13-14 et 17-18, schémas différents) ; le catalogue ne le garde qu'une fois (`duplicate_in_source: true`).

### Limites connues

- Positions et trajectoires : lecture approchée (≈ 0,15 case) du schéma `[S]` ; jamais publiées par la FFB sous cette forme.
- Rayon de bille (0,1 unité) : `[Prop]` ; ligne de départ : x = 1,6 `[FFB]` (arbitrage du 2026-10-14), alors que la ligne dessinée est lue vers x ≈ 1,75 à 1,85 sur la plupart des pages.
- Le champ `uncertainties` de chaque diagramme est la liste autoritaire des doutes (rôle des billes d'obstacle, ordre des tirs, poches déduites, chevalet non précisé, bille blanche absente du dessin…). La synthèse est dans `../../08-lacunes-et-questions-ouvertes.md`.
