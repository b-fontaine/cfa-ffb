# ADR 0005 : illustrations du joueur, de la cible sur la blanche et du dosage

- Statut : **accepté et implémenté** (2026-10-13). Remplace en partie les décisions 6 et les « limites assumées » de l'ADR 0004 pour trois types d'illustration. Plan : `../tailles-et-illustrations-plan.md` (§ 3).
- Contexte de livraison : application V1 non livrée, aucune compatibilité de données à préserver.

## Contexte

L'utilisateur a relu les illustrations de séance et fait quatre retours : la blanche est plus petite que les autres billes (traité par le module de dimensions, lots A et B du plan), et trois schémas ne sont pas clairs.

- **Se placer** : la vue de dessus schématique (`stance_top`) est illisible ; il demande un personnage.
- **Où viser** : la vue de côté (`cue_side`) ne montre pas le point d'impact ; il demande la blanche avec une cible et le point d'impact du procédé.
- **Doser la puissance** : l'échelle à cinq crans (`power_scale`) n'est pas claire ; il demande un rapport entre l'amplitude et la vitesse.

## Décision

1. **`player_figure` remplace `stance_top`** : un joueur droitier schématique, de profil, de dessus ou les deux, avec six repères numérotés et légendés (pieds, jambes et bassin, tête, avant-bras, main de chevalet, queue) tirés de la fiche technique n° 1 `[S]`. Les proportions sont `[Prop]` (plateau à 0,48 H, queue à 0,83 H, talon relevé de 10°). La géométrie est pure (`shared/lib/player_figure_layout.dart`) et testée par les invariants de la fiche (pied droit sous la main arrière, avant-bras vertical, queue par le centre de la blanche).
2. **`cue_ball_target` remplace `cue_side`** : la blanche vue de face avec une cible (anneaux à mi-rayon et au bord, croix nommée) et le procédé dessiné **à l'échelle de la blanche** (8,5 mm sur 48,0 mm, soit 0,177 du rayon), avec un plancher de lisibilité pour la projection. Un profil facultatif montre la hauteur de la queue. `CueSideView` n'est plus rendu par une séance ; il reste pour la vue de côté avec contact (décision D5 du plan, ouverte).
3. **`power_ratio` remplace `power_scale`** : un plan amplitude × vitesse à trois zones (doux, moyen, puissant) dont les limites sont le produit des deux grandeurs. Il n'y a plus de cran ni de niveau numéroté. Seuls les deux extrêmes viennent de la fiche n° 2 `[S]` ; la grille intermédiaire est `[Prop]`.
4. Les trois anciens types sont **refusés** par le parseur et par l'outil de validation (hors de la liste fermée) ; les 29 séances sont migrées. Règles V25 à V27 (`FORMAT.md` § 7).

## Alternatives rejetées

- **Garder la vue de dessus sans silhouette** (ADR 0004, « Silhouette humaine pour la posture » rejetée pour éviter tout risque de représentation d'enfant) : l'utilisateur la juge illisible. La décision d'origine est **renversée** avec un garde-fou : pictogramme neutre, sans visage, sans sexe ni âge, une seule couleur de figure, un seul gabarit pour les enfants et les adultes.
- **Figure réaliste, ou différenciée enfant / adulte** : plus d'effort de dessin et plus de risque ; le pictogramme suffit à placer les repères.
- **Deux curseurs continus** pour le dosage : la séance s'écrit en mots (courte, moyenne, longue ; lente, moyenne, rapide) ; trois niveaux par axe suffisent pour les deux exemples de la fiche.
- **Point bleu agrandi sans échelle** pour le procédé : l'échelle réelle (0,177 R) est lisible et enseigne que le procédé est petit devant la blanche.

## Conséquences

- Positives : trois illustrations lisibles en projection (textes de 14 ou plus, traits d'au moins 3 px, pastilles de 28 px), géométrie pure testée, description parlée localisée (fr, en), cas Widgetbook pour chaque variante.
- Coûts : trois composants, de nouvelles clés de localisation (fr et en), migration du contenu de cinq séances pour le dosage et la posture et de dix-sept pour la cible.
- Limites assumées : le joueur est un droitier (un gaucher se lit en miroir, dit dans la séance « gauchers ») ; les billes y sont agrandies et la vue n'est pas à l'échelle ; la lisibilité du personnage est à valider visuellement par l'animateur dans Widgetbook.
