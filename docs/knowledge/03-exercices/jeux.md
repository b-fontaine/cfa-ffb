# Catalogue des fiches jeux (14 fiches)

Source `[S]` : *Fiches Jeux CFA blackball.pdf*. Les jeux closent la séance et prolongent le thème travaillé. Ils créent de l'émulation sans changer la technique visée.

| # | Notion | Jeu | Format | Règles essentielles |
|---|--------|-----|--------|---------------------|
| 1 | Posture-visée-coup de queue | Série de 6 billes en bord de poche | Défi à 2 | Billes près des poches ; blanche placée librement ; réaliser 6 billes d'affilée ; si échec ou faute : on replace tout, la main passe |
| 2 | Idem (variante) | Billes à un espace de bille des poches | Défi à 2 | Idem, difficulté accrue |
| 3 | Puissance | Placer la blanche dans le camp adverse | Partie à 2 | 5 tirs chacun à tour de rôle ; la blanche peut rebondir sur la petite bande ; invalide si faute ou si elle touche une bille ; premier à 5 ; zone modulable |
| 4 | Puissance | « Pétanque » avec la blanche | 2 joueurs ou 2 équipes de 2 | Tir depuis la ligne ; placer sa bille au plus près de la blanche ; bille empochée/revenue derrière le trait retirée ; blanche fautive : points restants à l'adversaire + 2 ; premier à 8 points ; 4 billes par camp, plusieurs manches |
| 5 | Puissance | « Pétanque » avec la noire | Idem | Propulser la noire grâce à la blanche puis placer ses billes au plus près de la noire ; même décompte ; premier à 8 |
| 6 | Bille pleine | Placer la noire dans une zone | Partie à 2 | 5 tirs ; visée en plein au chevalet sur cadre ; la noire peut rebondir sur la petite bande ; premier à 5 ; faire aussi jouer chevalet sur surface |
| 7 | Demi-bille | 8 billes dans une poche | Partie à 2 | Vider son groupe puis la noire dans une poche ; blanche replacée sur son point d'origine après chaque tir ; billes replacées ; égalité : jouer la noire jusqu'à ce que l'un manque ; conseil : vérifier les billes en demi à chaque fois |
| 8 | Trois-quarts | 8 billes en ligne | Partie à 2 | Vider son groupe puis la noire d'un seul côté du billard ; blanche repositionnée pour viser en trois-quarts ; égalité : rejouer une série entière ; billes à distance d'une mouche le long de la grande bande |
| 9 | Quart de bille | 8 billes en poche du milieu | Partie à 2 | Vider son groupe puis la noire dans une poche du milieu en quart de bille ; invalide si la blanche n'est pas replacée dans la zone |
| 10 | Quantités de bille | 14 billes depuis une seule position de blanche | Défi seul | Empocher toutes les billes dans les poches de son choix, une bille par tir ; blanche replacée à l'origine ; billes non empochées replacées |
| 11 | Idem (variante) | Même défi | Défi seul | Identique |
| 12 | Fin de partie | Empocher la noire après un groupe | Partie à 2 | Règles de la partie classique avec un seul groupe + la noire ; casse au tirage à la bande ; on continue tant qu'on empoche |
| 13 | Rebond sur bande | « Pétanque » avec bande avant impact | 2 ou 2×2 | Blanche placée librement dans la zone de replacement ; billes sur le trait ; chaque coup avec une bande avant impact ; invalide sinon ; premier à 8 |
| 14 | Après les quantités | Partie à difficulté réduite | Partie à 2 | Règles classiques avec seulement 4 billes par groupe + la noire ; casse désignée par le tirage à la bande |

## Remarques

- Lien notion ↔ jeu : utiliser le jeu de la **même notion** que l'entraînement du jour.
- Aucun jeu spécifique n'existe dans la source pour coulé, carreau, angle droit, rétro, rejet naturel : après la fin des quantités de billes, jouer des **parties à difficulté réduite** (n° 14), conformément au mémento.
- Adaptations de difficulté (taille de zone, distances) : `[S]` conseille de modifier la zone ; les autres variantes sont `[Prop]`.

## Schémas des jeux (transcriptions YAML)

Chaque fiche jeu est transcrite dans `diagrammes/jeux/pNN.yaml` (`NN` = numéro de page = numéro de jeu) `[S]`. Format : `diagrammes/FORMAT.md` ; index : `diagrammes/README.md`. Coordonnées approchées en cases de la grille (`x` 0 à 8 vers la droite, `y` 0 à 4 vers le bas, départ à gauche). Les règles du jeu sont dans les annotations du YAML ; le tableau ci-dessus les résume.

- **Jeu 1** — Schéma : `diagrammes/jeux/p01.yaml` (`jeux-p01-j1`). Placement : 6 rouges en bord de poches ; blanche non dessinée.
- **Jeu 2** — Schéma : `diagrammes/jeux/p02.yaml` (`jeux-p02-j1`). Placement : 6 rouges en bord de poches ; blanche non dessinée.
- **Jeu 3** — Schéma : `diagrammes/jeux/p03.yaml` (`jeux-p03-g1`). Placement : 4 rouges, 4 jaunes ; blanche à poser en (1,1 ; 2,1) (non dessinée) ; 2 zones grisées.
- **Jeu 4** — Schéma : `diagrammes/jeux/p04.yaml` (`jeux-p04-j1`). Placement : 4 rouges, 4 jaunes ; blanche (1,8 ; 2,1).
- **Jeu 5** — Schéma : `diagrammes/jeux/p05.yaml` (`jeux-p05-j1`). Placement : 4 rouges, 4 jaunes, la noire ; blanche (1,0 ; 2,0).
- **Jeu 6** — Schéma : `diagrammes/jeux/p06.yaml` (`jeux-p06-j1`). Placement : 4 rouges, 4 jaunes, la noire ; blanche (1,1 ; 2,1) ; 2 zones grisées ; répétition ×5.
- **Jeu 7** — Schéma : `diagrammes/jeux/p07.yaml` (`jeux-p07-g1`). Placement : rouge (1,8 ; 1,1), jaune (1,8 ; 3,1) ; blanche à poser en (2,7 ; 2,1) (non dessinée) ; poches visées : haut gauche (tl), bas gauche (bl).
- **Jeu 8** — Schéma : `diagrammes/jeux/p08.yaml` (`jeux-p08-g1`). Placement : 7 rouges, 7 jaunes, la noire alignées vers y ≈ 2,1 ; blanche à poser sur 2 emplacements de départ (non dessinée) ; poches visées : bas gauche (bl), haut gauche (tl).
- **Jeu 9** — Schéma : `diagrammes/jeux/p09.yaml` (`jeux-p09-j1`). Placement : rouge (4,0 ; 0,8), jaune (4,0 ; 3,2) ; blanche (1,8 ; 2,0) ; poches visées : milieu haut (tm), milieu bas (bm) ; blanche par la bande de droite ; 1 zone grisée.
- **Jeu 10** — Schéma : `diagrammes/jeux/p10.yaml` (`jeux-p10-j1`). Placement : 7 rouges, 7 jaunes ; blanche à poser en (4,0 ; 2,0) (non dessinée).
- **Jeu 11** — Schéma : `diagrammes/jeux/p11.yaml` (`jeux-p11-j1`). Placement : 7 rouges, 7 jaunes ; blanche (4,0 ; 2,0).
- **Jeu 12** — Schéma : `diagrammes/jeux/p12.yaml` (`jeux-p12-j1`). Placement : 7 rouges, la noire ; blanche (1,8 ; 2,0).
- **Jeu 13** — Schéma : `diagrammes/jeux/p13.yaml` (`jeux-p13-j1`). Placement : 4 rouges, 4 jaunes, la noire ; blanche à poser en (1,2 ; 1,4) (non dessinée).
- **Jeu 14** — Schéma : `diagrammes/jeux/p14.yaml` (`jeux-p14-j1`). Placement : 4 rouges, 4 jaunes, la noire ; blanche (1,8 ; 2,0).
