# Catalogue des fiches entraînement (13 blocs distincts + 1 doublon, 34 pages)

Source `[S]` : *Fiches Entrainement CFA blackball.pdf*, niveau 1. Chaque bloc indique un **nombre de séances conseillé** et, par exercice, un **taux de réussite pour passer à l'exercice suivant**. Les schémas (positions des billes, zones) ne sont pas décrits dans le texte extrait : s'y reporter dans le PDF.

Légende : « cadre » = chevalet sur cadre ; « surface » = chevalet sur la surface de jeu ; BB = exercice portant la mention **« Billard de bronze »** dans la source.

| # | Bloc | Séances conseillées | Exercices et taux de réussite pour passer au suivant |
|---|------|---------------------|-------------------------------------------------------|
| 1 | **La puissance** | 1 à 2 | E1 : 3 × 3 billes, cadre, **7/9** · E2 : 2 × 5 billes, cadre, **5/10** · E3 : 2 × 5, surface, **5/10** · E4 : 4 × 2, surface, **5/8** (blanche dans la zone grise) |
| 2 | **Quantité de bille pleine** | 2 à 3 | E1 : 8 billes, cadre, **6/8** BB · E2 : 6 billes, surface, **4/6** BB · E3 : 8 billes, surface, **6/8** BB · E4 : 8 billes en poches du milieu, cadre, **6/8** BB |
| 3 | **Quantité demi-bille** | 2 à 3 | E1 : 6 billes, distances différentes, **4/6** BB · E2 : 8, surface, **6/8** BB · E3 : 8, cadre, **6/8** BB · E4 : 8, distances différentes, **4/8** BB |
| 4 | **Quantité trois-quarts** | 1 à 2 | E1 : 2 × chaque jaune puis chaque rouge, cadre, **6/8** BB · E2 : 8, distances différentes, **6/8** BB · E3 : 8, surface, **6/8** BB · E4 : 8, cadre, **6/8** BB |
| 5 | **Quart de bille et finesses** | 1 à 2 | E1 : 8 en quart, surface, **6/8** BB · E2 : 8 en quart, **8/12** BB · E3 : 8 en finesse, **4/8** BB · E4 : 8 en finesse, **4/8** BB |
| 6 | **Les quantités de billes** | 1 à 2 | E1 : 7 billes, **5/7** BB · E2 : 8, **6/8** BB · E3 : 9, **6/9** BB · E4 : 4 × 2, **5/8** BB |
| 7 | **Le rejet naturel** (1re occurrence) | 2 | E1 à E4 : replacer 5 fois la blanche pour jouer la noire, **3/5** chacun |
| 8 | **Rebond sur une bande** | 2 | E1 : jouer une bande avant, **3/5** · E2 : idem, **3/5** · E3 : deux bandes avant de toucher une bille, **2/3** · E4 : idem, **2/3** |
| 9 | **Le rejet naturel** (2e occurrence) | 1 à 2 | E1 à E4 : identique au bloc 7, **3/5** chacun (schémas différents). Anomalie de la source : voir `../00-provenance-et-fiabilite.md` |
| 10 | **Le coulé** | 2 à 3 | E1 : 5 fois faire avancer la blanche au-delà du trait, **3/5** · E2 : replacer 5 fois, **3/5** · E3 : 4 séries de 3 billes (zones 1 à 4), **8/12** · E4 : 2 séries de 5, **6/10** · E5 : **3/5** · E6 : **3/5** · E7 : 6 billes, 3 par zone, **4/6** · E8 : **3/5** |
| 11 | **Le carreau** | 1 à 2 | E1 à E4 : empocher 5 billes en carreau pour replacer la blanche sur la noire, **3/5** chacun |
| 12 | **Le coup en angle droit** | 2 à 3 | E1 à E4 : empocher 5 billes en angle droit (E2 : blanche replacée « par bande » ; E3 par bande ; E4 « par bandes »), **3/5** chacun |
| 13 | **Le rétro** | 3 à 4 | E1 : 5 billes, **3/5** · E2 : 5, cadre, **3/5** · E3 : 6 billes, 3 par zone, **4/6** · E4 : 6, **4/6** · E5 : 5, **3/5** · E6 : 5, cadre, **3/5** · E7 : 6, **4/6** · E8 : 5, **3/5** · E9 : 5, **3/5** · E10 : 6, **4/6** |
| 14 | **Les trajectoires de blanche** | 3 à 4 | E1 : 9 billes en variant la hauteur d'attaque, 3 sur chaque jaune, **6/9** · E2 : 10 billes en alternant haut/bas pour replacer sur la noire, **6/10** · E3 : **6/9** · E4 : **6/10** · E5 : enchaîner 3 replacements différents en zones croissantes, ×3, **6/9** · E6 : 5 replacements sur les noires, ×3, **10/15** |

Total conseillé hors doublon du rejet naturel : **23 à 34 séances** de niveau 1 `[S]` (somme des bornes). La source ne définit pas la durée d'une « séance » : ne pas l'extrapoler.

## Ordre d'enseignement et validation `[U]`

- Les blocs 7 à 9 sont dans l'ordre du PDF. **Ordre d'enseignement retenu : rebond sur bande (bloc 8) avant rejet naturel (bloc 7)** ; voir `teaching_order` dans le YAML.
- Un exercice est **validé** quand le taux de la fiche est atteint sur **plusieurs passages (5 le plus souvent, réglable)**.

## Lecture des taux

- « 7/9 » = 7 billes réussies sur 9 tentatives pour **passer à l'exercice suivant**.
- Les exercices d'une même fiche sont d'une difficulté croissante (cadre → surface, distances variées, zones).
- Le mémento exige **des exercices différents dans une même séance, chacun joué au maximum 2 fois**.

## Version machine

`catalogue-entrainement.yaml` (même dossier) reprend ces données sous forme structurée pour l'application et les agents.
