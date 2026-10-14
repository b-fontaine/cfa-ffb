# Format des diagrammes d'exercices (lisible par un agent, animable par l'application)

Les PDF de `docs/sources/` `[S]` illustrent chaque exercice par un schéma de table : positions des billes,
trajectoires, quantité de bille (bille pleine, demi-bille…), type de chevalet. Ces schémas ne sont pas
exploitables par un agent texte. Chaque schéma est donc **transcrit en YAML** selon ce format ; le même
fichier sert ensuite à **générer des visuels animés** (composants du design system : table, billes, queue).

Exception : le dossier `proposition/` ne transcrit aucun PDF ; il porte la mise en place `[Prop]` des blocs d'entraînement proposés (voir § 3). Règle d'or : **ne rien inventer**. Une valeur lue approximativement sur le schéma est une transcription
(`[S]`, précision ≈ 0,15 case) ; une valeur incertaine est signalée dans `uncertainties`. Aucune adaptation
non sourcée n'est écrite ici.

## 1. Repère de la table

- Surface de jeu **vue de dessus, en paysage**, comme dans les PDF : l'extrémité de départ (ligne de départ,
  zone « de la cuisine ») est **à gauche**.
- Unité = **une case de la grille pointillée du PDF** : `x ∈ [0, 8]` le long de la table (gauche → droite),
  `y ∈ [0, 4]` en travers (haut → bas). Origine = coin haut-gauche de la **surface de jeu** (bord intérieur
  des bandes). Rapport longueur/largeur = 2:1.
- Ligne de départ (trait plein vertical du schéma) : règle `[FFB]` `x = 1.6` (1/5 de la longueur), dessinée
  telle quelle (arbitrage rendu le 2026-10-14) ; le schéma `[S]` la montre vers 1,8 (écart consigné dans
  `uncertainties` ; les mentions « et non 2,0 » ou « FORMAT : 2,0 [Prop] » des `uncertainties` YAML renvoient à l'ancienne convention 2,0 `[Prop]` ; la lecture source ≈ 1,8 reste valable, comparée à 1,6). Les positions des billes restent absolues. Voir
  `../../02-techniques/06-dimensions-du-materiel.md` § 4.
- **Rayons de bille, aux tailles réelles** (une case = 925 / 4 = 231,25 mm ; cotes `[FFB]`, voir
  `../../02-techniques/06-dimensions-du-materiel.md`) : bille de but (rouge, jaune, noire) 50,8 mm, soit
  **rayon `0.1098`** ; **blanche 48,0 mm, rayon `0.1038`**. La blanche est **plus petite** que les billes de but
  (rapport 0,945) `[S]`. Distance entre centres au contact blanche / bille de but : `s = r_c + r_o = 0.2136` ;
  entre deux billes de but : `2 r_o = 0.2197`. Les positions transcrites sont des mesures à 0,01 case près : le
  validateur tolère ce jeu pour deux billes tangentes ou une bille contre une bande.
- Poche : ouverture réelle 76,2 mm (`0.3295` case, 1,5 bille de but) ; l'application la dessine à cette taille.
- Poches (id) : `tl`, `tm`, `tr` (haut gauche / milieu / droite), `bl`, `bm`, `br` (bas). Centres :
  `tl=(0,0)`, `tm=(4,0)`, `tr=(8,0)`, `bl=(0,4)`, `bm=(4,4)`, `br=(8,4)`.
- Couleurs de billes : `red`, `yellow`, `black`, `white` (blanche = bille de choc).

## 2. Un fichier = une page de PDF

Chemin : `docs/knowledge/03-exercices/diagrammes/<fichier>/pNN.yaml` avec `<fichier>` ∈ `entrainement`,
`initiation`, `jeux`, `techniques` (transcriptions de PDF `[S]`) ou `proposition` (hors PDF, `[Prop]`) et `NN` = numéro de page du PDF (2 chiffres). Une page peut porter
plusieurs schémas (ex. 2 exercices) → liste `diagrams`.

```yaml
version: 1
source: {file: "Fiches Entrainement CFA blackball.pdf", page: 3, rank: S}
diagrams:
  - id: entrainement-p03-e1            # <fichier>-pNN-<suffixe>, unique
    kind: exercise                     # exercise | game | initiation | technique-schema | technique-photo
    sheet: "La quantité de bille pleine"   # titre de la fiche, tel qu'écrit dans le PDF
    exercise: 1                        # numéro d'exercice si la page en porte un
    caption: "Empocher huit billes en quantité de bille pleine, avec un chevalet sur cadre."  # texte du PDF
    success_rate: [6, 8]               # [réussites, tentatives] si indiqué
    bridge: frame                      # frame (chevalet sur cadre) | surface (sur la surface de jeu) | none | unknown
    bronze: true                       # pastille « Billard de bronze » présente
    table: {view: top, head_end: left}
    balls:                             # état INITIAL
      - {id: y1, color: yellow, at: [1.4, 1.5], label: "x4"}
      - {id: w,  color: white,  at: [2.9, 3.0], role: cue}
    ghosts:                            # cercles creux / pointillés du schéma
      - {id: g1, at: [1.2, 1.4], role: impact, for: w}      # position de la blanche à l'impact
      - {id: g2, at: [2.9, 3.0], role: cue_start, label: "1"} # emplacement où poser la blanche
    arrows:                            # trajectoires, dans l'ordre d'exécution
      - {id: a1, ball: y1, kind: object, path: [[1.4, 1.5], [0, 0]], to: tl}
      - {id: a2, ball: w,  kind: cue, path: [[2.9, 3.0], [1.2, 1.4]], bounces: []}
    zones:                             # surfaces grisées / mises en évidence
      - {id: z1, shape: rect, from: [0, 0], to: [2, 4], label: "zone grise"}
    sequence:                          # déroulé animable (facultatif si 1 seul coup)
      - {step: 1, cue: w, hit: y1, contact: full, pocket: tl, repeat: 4}
    inset:                             # petit schéma « quantité de bille » en bas à droite
      contact: full                    # full | three_quarter | half | quarter | thin | none
      tip_point: center                # point d'impact du tip sur la blanche
      bridge_height: surface
    annotations: ["x 4 : la même situation est répétée 4 fois"]
    description: >-
      Texte libre en français décrivant ce que montre le schéma pour un agent qui ne le voit pas.
    uncertainties: []                  # tout ce qui n'a pas pu être lu avec certitude
```

### Champs obligatoires par `diagrams[*]`

`id`, `kind`, `caption` (ou `description` pour une photo), `description`, `uncertainties` (liste, éventuellement
vide). Pour `exercise`/`game`/`initiation` avec table : `balls`, `table`.

### Conventions de lecture

| Élément du schéma | Champ |
|---|---|
| Bille pleine colorée | `balls` (état initial) |
| Cercle creux pointillé numéroté | `ghosts` avec `role: cue_start` (où poser la blanche, ordre = `label`) |
| Cercle creux collé à une bille | `ghosts` avec `role: impact` (position de la blanche au contact) |
| Flèche pleine | `arrows` ; `kind: object` (bille cible), `cue` (blanche), `indication` (consigne) |
| Flèche qui rebondit sur une bande | `path` avec un point par rebond **sur la bande** ; `bounces` liste les bandes : `top`, `bottom`, `left`, `right` |
| Nombre à côté d'une bille (1, 2…) | `label` ; si c'est un ordre de tir : `order: n` |
| « x 4 » à côté d'une bille | `label: "x4"` + `repeat: 4` dans `sequence` |
| Zone grisée | `zones` |
| Petite bille blanche + bille rouge en bas à droite | `inset` (quantité de bille ; point bleu = `tip_point`) |
| Chevalet : sur cadre / sur la surface | `bridge: frame` / `surface` (texte de l'énoncé) |
| Pastille « Billard de bronze » | `bronze: true` |

Si le schéma n'est pas une vue de table (photo de posture, de chevalet, de queue, tableau), utiliser
`kind: technique-photo` sans `balls` et décrire précisément : `subject` (ce qui est montré), `elements`
(liste : main, pouce, chevalet, flèche, queue, regard…), `teaching_point` (le point pédagogique que la
photo illustre selon le texte voisin), `adjacent_text_summary`.

## 3. Rangs et provenance

Tout fichier des dossiers `entrainement/`, `initiation/`, `jeux/` et `techniques/` est une **transcription de source `[S]`** : le PDF fait foi (`rank: S`).

Le dossier `proposition/` fait exception : ses pages portent `source: {file: "Proposition (hors PDF)", page: <rang de la page proposition>, rank: Prop}`. Un diagramme y est la **mise en place `[Prop]`** d'un exercice d'un bloc proposé du catalogue (`source: Prop`) : `kind: exercise`, `sheet` = titre du bloc, `exercise` = numéro, `success_rate` = taux `[Prop]` du bloc, jamais de `bronze`. Les positions sont reprises, ou calculées (bille fantôme : `G = O - s·u` avec `s = r_c + r_o = 0.2136`, la bille fantôme étant une blanche ; contrôle : `dart run tool/diagrammes.dart --ghosts`), à partir de schémas `[S]` ; elles sont illustratives, non mesurées, et les annotations de provenance commencent par `[Prop]`. Ne jamais présenter ces schémas comme fédéraux. Le validateur n'accepte que `rank: S` ou `rank: Prop` (champ facultatif). Les valeurs numériques
de position des transcriptions sont des mesures approchées (jamais publiées par la FFB sous cette forme). Les rayons de bille
viennent des cotes `[FFB]` (`06-dimensions-du-materiel.md`) ; la position de la ligne de départ et les couleurs sont
des `[Prop]` documentés.

## 4. Outils

- Validation + rendu ASCII : `cd app && dart run tool/diagrammes.dart [--ascii] [--ghosts] <fichier.yaml…>` (voir README de ce dossier).
- Le contrôle indépendant compare le rendu ASCII au PDF (`pdftoppm -r 110 -f N -l N -png`).
