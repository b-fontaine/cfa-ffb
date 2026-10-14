# Recommandations UX / UI

Suite de l'[audit](audit-ux-ui.md) (constats cités entre parenthèses :
T1…, G1…, R1…). Chaque recommandation dit **quoi**, **pourquoi**, **comment**
dans le code existant, et son **effort** (S : une demi-journée, M : un à deux
jours, L : plus). L'ordre d'exécution est proposé dans
[plan-ux-proposition.md](plan-ux-proposition.md).

Toutes les propositions respectent les règles du dépôt : BDD puis TDD, FSD,
jetons du thème uniquement, textes `fr` et `en`, use case Widgetbook par
widget public, jamais la couleur seule.

## 0. Principes directeurs

1. **Trois modes, trois densités.** *Préparer* (tout le contenu, badges de
   provenance, sommaire), *Mener* (l'étape, le schéma, le minuteur, noter :
   rien d'autre), *Montrer* (le schéma seul, plein écran, à l'échelle de la
   pièce). Un même contenu, trois mises en page ; le mode se déduit de la
   route et d'un commutateur « relecture » explicite.
2. **Le schéma d'abord.** Dans toute étape qui en a un, le schéma est le
   premier élément visible ; le texte le complète.
3. **La fiche résultats fédérale comme modèle d'interaction** : une pastille
   par essai, pleine ou creuse, cinq passages pour valider. L'animateur et
   l'élève la connaissent déjà.
4. **Un « maintenant » à chaque ouverture** : la prochaine séance, la séance
   en cours, les alertes, ce qui a bougé depuis la dernière fois.
5. **Le rouge FFB est une signature, pas un état.** Les états
   (sélectionné, en cours, réussi, attention) ont leurs propres jetons.
6. **Sobriété billard** : tapis bleu poudre, billes, losanges des rails,
   craie ; aucun logo fédéral tant que l'autorisation n'est pas écrite.

## 1. Design system

### R1 — Réaffecter les rôles de couleur Material 3 (T1, M3, R3, X2, D4) — effort M

**Quoi.** Faire sortir le rouge FFB du rôle `secondary` et lui donner un rôle
d'accent de marque explicite.

**Comment.**

- `app_color_schemes.dart` : `secondary` / `secondaryContainer` prennent la
  famille du **tapis bleu poudre** (aujourd'hui `tertiary` `#2f6b8a` /
  `#cfe6f3` en clair ; `#9fcfe8` / `#1f5873` en sombre). Les états
  « sélectionné » deviennent bleu-tapis : barre de navigation, puces,
  segments, boutons tonals, piste de progression.
- Nouvelle `ThemeExtension` **`BrandColors`** (`shared/ui/theme`) : `accent`
  (rouge FFB assombri `#b80d1a`, sombre `#ffb3ad`), `onAccent`, `accentContainer`.
  Usages autorisés : titre de l'application, une pastille d'en-tête, la
  ligne d'objectif des courbes (`ProgressChart.targetColor`), le badge
  « Enfants ». Tout usage passe par un composant du design system, jamais un
  écran.
- Le test `contrast_test.dart` couvre la nouvelle extension (≥ 4,5:1).
- Widgetbook : feuille « Rôles de couleur » montrant côte à côte navigation,
  puces, compteur, progression, dans les deux thèmes.
- ADR 0008 « Rôles de couleur : bleu-tapis pour les états, rouge en accent »
  (amende l'ADR 0002, décision 2 ; le numéro 0007 est pris par le lien
  séance planifiée ↔ saisie).

### R2 — Hiérarchie de surfaces (T2) — effort S

Trois niveaux et pas plus : **page** (`surface`), **carte de contenu**
(`surfaceContainerLow`, sans bord), **carte en évidence** (`surfaceContainer`
+ bord `outlineVariant`, réservée à l'étape courante, à l'élève en cours de
saisie, à l'alerte). `SectionCard` reçoit un paramètre `emphasis`
(`low | medium | high`). L'action principale d'une page est **unique** et
pleine (`FilledButton`) ; les autres sont `OutlinedButton` ou `TextButton`.

### R3 — Identité billard sans logo (T3, A4) — effort M

- Retirer `FfbLogo` de l'accueil et des en-têtes (conforme à l'ADR 0002,
  décision 5) jusqu'à autorisation écrite ; conserver le composant et
  `BrandAssets` derrière un drapeau de thème (`BrandAssets.logo == null` par
  défaut). Si l'autorisation arrive, un seul endroit à rallumer.
- Le signe de l'application devient **une bille noire n° 8 avec sa lettre**,
  dessinée par `BilliardBall` : icône d'application, en-tête de l'accueil,
  état vide.
- Icônes de navigation dédiées (police d'icônes du projet, 5 glyphes) :
  table vue de dessus pour « Séances », deux billes pour « Élèves », fiche à
  pastilles pour « Résultats », maison, losange du rail pour « Plus ».
- Un **motif de tapis** discret (`BallColors.cloth` à 6 % d'opacité, grille
  8 × 4 pointillée) en fond de l'en-tête de l'accueil et du mode présentation :
  rappel de la table, sans texture lourde.

### R4 — Composants à ajouter

| Composant (`shared/ui`) | Rôle | Remplace / sert |
|---|---|---|
| `PassDots` | n pastilles tapables (pleine = empochée, creuse = manquée), texte `x/n`, cible ≥ 48 dp par pastille ; mode lecture seule | compteur « Billes empochées » (R3 de l'audit), fiche élève, bilan |
| `PhaseTimeline` | frise proportionnelle des cinq phases avec minutes, phase courante en évidence, tapable | détail (D2), guide (G1) |
| `TimerChip` | minuteur compact : temps restant en `titleLarge`, fond qui passe à `attention` sous 1 min puis `error` au dépassement, bouton unique lecture/pause | carte minuteur (G4) |
| `StepAppBar` | en-tête compact d'une étape : titre de l'étape, « 6/9 », menu ⋮ (sommaire, relecture, terminer) | pile d'en-tête du guide (G1, G2, G3) |
| `StudentChip` | prénom + pastille d'état (réussi / manqué / à faire) | grille de saisie, vue de groupe |
| `NowCard` | carte d'accueil : titre, méta, action principale, action secondaire | accueil (A1) |
| `DiagramStage` | conteneur plein écran d'un schéma : ratio préservé, table sur la plus grande dimension, légende en bandeau, contrôles en bas, zoom par pincement | présentation (M1, M4) |

### R5 — Lisibilité des schémas (M2, M1) — effort M

- `table_diagram.dart` : **placement des annotations hors trajectoire**.
  Pour chaque étiquette (numéro de repère, lettre de bille), choisir parmi
  huit positions autour du point celle qui ne croise aucune flèche ni bille
  (test de recouvrement sur les segments déjà tracés). Test unitaire sur le
  schéma `entrainement/p05` (six repères).
- Taille minimale d'étiquette **16 px sous `PresentationScope`** et halo de
  tapis derrière le texte (`BallColors.cloth` à 85 %) pour qu'une étiquette
  posée sur une ligne reste lisible.
- La queue est dessinée **dans** les bornes du widget (clip ou raccourcie),
  jamais coupée par le rail.
- Repères numérotés : cercle creux **de la taille de la blanche** avec le
  numéro à l'intérieur quand la bille mesure ≥ 28 px, à côté sinon (règle
  déjà appliquée aux lettres).
- `inset` du FORMAT (quantité de bille) : rendre un médaillon
  `BallContactDiagram` dans le coin de la table pendant l'étape ; c'est la
  seule façon de montrer « demi-bille » à côté de la trajectoire.

## 2. Architecture de l'information et navigation

### R6 — Cinq destinations recentrées (T5, B1) — effort M

| Avant | Après | Contenu |
|---|---|---|
| Accueil | **Aujourd'hui** | prochaine séance, séance en cours, alertes, dernière saisie, raccourcis |
| Élèves | **Élèves** | groupes, élèves, vue de groupe (heat-map) |
| Résultats | **Résultats** | séances saisies, saisie rapide |
| Séances | **Séances** | onglets *Planifiées* · *Catalogue* · *Suggestion* |
| Sauvegarde | **Plus** | sauvegarde, réglages (F8), à propos et sources |

Le shell garde cinq destinations (ADR 0004). La planification devient
visible ; la sauvegarde descend d'un niveau mais gagne un **rappel** (bandeau
sur « Aujourd'hui » quand la dernière sauvegarde date de plus de 30 jours ou
que des passages ont été saisis depuis).

### R7 — Mode immersif pour le guide (G5, G1) — effort S

La route `/catalogue/:id/guide` sort du `ShellRoute` (comme la présentation) :
plus de rail ni de barre en séance. Retour par la flèche de `StepAppBar` et
par « Terminer ». Le même mécanisme masque la barre en présentation.

## 3. Écrans

### R8 — Accueil « Aujourd'hui » (T6, A1, A2, A3) — effort L (le lot 6, livré, fournit la séance planifiée datée et par groupe)

```
+--------------------------------------------------------+
| ● Aujourd'hui                                14 oct.   |
|                                                        |
| [NowCard · en cours]                                   |
|  Quantité demi-bille · séance 1/2 · Groupe enfants     |
|  Étape 6/9 · Entraînement                              |
|  [ Reprendre la séance ]        [ Saisir ]             |
|                                                        |
| [NowCard · prochaine]                                  |
|  Jeudi 16 oct. 18:00 · Groupe adultes                  |
|  Le rétro, séance 2/4 · Le boomerang                   |
|  [ Préparer ]  [ Lancer ]                              |
|                                                        |
| À surveiller                                           |
|  ⚠ Tom · Bille pleine ex. 2 · 3 échecs de suite        |
|  ◔ Groupe enfants · 4 élèves sur 8 ont validé demi-1   |
|                                                        |
| Cette semaine        12 passages · 3 validations       |
| Sauvegarde           il y a 23 jours   [ Exporter ]    |
+--------------------------------------------------------+
```

Règles : jamais plus de deux `NowCard` ; l'état vide (aucune séance planifiée)
propose « Planifier la prochaine séance » et « Voir la suggestion pour un
groupe ». Toutes les données viennent de cas d'usage existants :
`ListSessions` (séances planifiées triées par date, groupe, lien « Résultats
saisis » dérivé, ADR 0007), `RunSheetSessions` (séance commencée),
`StudentReport` (alertes), historique des saisies : la page compose, elle ne
calcule pas. « Prochaine » = première séance planifiée dont la date est ≥
aujourd'hui ; « en cours » = séance planifiée du jour dont le guide a une
étape mémorisée.

### R9 — Séance guidée, mode « Mener » (G1 à G7) — effort L

```
+------------------------------------------------------------------+
| ←  Exercice 1 · Les six parts de gâteau          6/9   ⏱ 18:40  ⋮ |
| ■■■■■■□□□  Accueil · Notion · [Entraînement] · Jeu · Bilan       |
|------------------------------------------------------------------|
|                                  |  Objectif 4/6 · 5 passages     |
|   [ schéma de table, animé ]     |  Mise en place : …             |
|   ▶  ↻   ×0,5 ×1 ×2   [Montrer]  |  Consigne : …                  |
|                                  |  Attendu : …                   |
|   ◐ demi-bille (médaillon)       |  ▸ Erreurs fréquentes          |
|                                  |  ▸ Accroche et défi            |
|------------------------------------------------------------------|
| [ ← Précédent ]      [ Noter les résultats ]      [ Suivant → ]  |
+------------------------------------------------------------------+
```

- `StepAppBar` + `PhaseTimeline` remplacent la pile d'en-tête : 96 dp au lieu
  de ~360. Le titre de la séance, le public et le thème passent dans le
  menu ⋮ et le sommaire (G2).
- **Schéma en premier** dans l'étape, texte ensuite ; en paysage ≥ 720 dp,
  schéma à gauche (il est la chose à regarder en premier et à montrer),
  texte à droite (G6).
- `TimerChip` dans l'en-tête, toujours visible, qui change de fond à 1 min et
  au dépassement, avec vibration légère sur mobile (G4).
- « Terminer » dans le menu ⋮ et confirmé ; « Montrer » sous le schéma (G3).
- Sections « Erreurs fréquentes », « Accroche », « Défi » **repliées** par
  défaut en mode Mener, dépliées en mode Préparer.
- Badges de provenance **masqués en mode Mener** ; un commutateur
  « Relecture » (menu ⋮) les affiche et déplie tout (T4). Le mode Relecture
  est l'état par défaut quand le guide est lancé **depuis le détail sans
  séance planifiée** (c'est le cas d'usage « relire sans élèves » de l'ADR
  0004).
- Compteurs d'initiation et score de jeu : conservés dans la séance saisie
  (roadmap lot 10) ; en attendant, une seule mention « non enregistré » dans
  le bilan, pas à chaque étape (G7).
- Barre basse à trois actions : Précédent, **Noter** (pleine, au centre, sur
  une étape exercice), Suivant.

### R10 — Présentation plein écran (M1 à M4) — effort M

- `DiagramStage` : la table occupe la plus grande dimension disponible (en
  paysage, la hauteur ; en portrait, la largeur), légende en bandeau sous la
  table (jamais hors écran : la hauteur du bandeau est réservée avant de
  dimensionner la table), contrôles du lecteur dans une barre basse de 56 dp,
  « Fermer » en icône 48 dp en haut à droite, Précédent / Suivant en flèches
  latérales 56 dp (`FilledButton` bleu-tapis, R1).
- Sur téléphone en portrait, bandeau « Tournez l'appareil pour montrer »
  (texte + icône), et zoom par pincement.
- Plein écran navigateur (API `requestFullscreen` sur web, `SystemChrome`
  immersif sur mobile) à l'entrée, restauré à la sortie.
- Texte des étiquettes ≥ 16 px sous `PresentationScope` (R5).

### R11 — Saisie rapide en grille (R1 à R6 de l'audit) — effort L

```
+------------------------------------------------------------------+
| ← Séance du 14 oct. · Groupe enfants                              |
| Exercice  [ Demi-bille · ex. 1 · objectif 4/6         ▾ ]        |
|------------------------------------------------------------------|
| Élève   | Passage 1              | Passage 2              | État |
| Léa     | ●●●○○○  3/6  ✗         | ○○○○○○  —  [Saisir]    | 1/5  |
| Tom     | ●●●●○○  4/6  ✓         | ●●●●●○  5/6  ✓         | 2/5  |
| Inès    | ○○○○○○  —  [Saisir]    |                        | 0/5  |
|------------------------------------------------------------------|
| Tentatives : 6 (fiche) · [ changer pour ce passage ]              |
```

- Une ligne par élève présent, une colonne par passage (2 au plus), état de
  validation à droite (passages réussis sur 5). Les `PassDots` se saisissent
  **en tapant les pastilles** ; « Saisir » enregistre ; le résultat ✓ / ✗
  est immédiat et la ligne entière prend le ton succès ou neutre (R4).
- Le sélecteur d'exercice est un `DropdownMenu` **nommé** (sémantique) dont le
  libellé est le **nom de l'exercice** (« Les six parts de gâteau ») suivi du
  bloc en sous-titre, sans troncature (`expandedInsets` + `maxLines: 2`).
- Sur téléphone (< 600 dp), la grille devient une liste de lignes compactes
  (prénom, pastilles, état) de 72 dp ; dix élèves tiennent sur un écran.
- Le changement de tentatives est une action rare, reléguée sous la grille.
- « Passages de la séance » groupe par élève puis par exercice, avec
  `PassDots` en lecture seule, crayon et corbeille (R5).
- Depuis le guide, la saisie s'ouvre **dans une feuille basse** sur l'exercice
  courant (groupe et présents déjà connus) : noter un passage ne quitte plus
  l'étape (le retour au guide existe déjà ; la feuille évite l'aller-retour).

### R12 — Catalogue comme parcours (C1 à C5) — effort M

- Ligne : **nom évocateur en titre**, « Séance 1/2 · Demi-bille » en
  sous-titre ; un seul badge d'état de relecture (« 3 points à valider »,
  détail au survol et dans le détail) ; la pastille « Source fédérale » est
  retirée de la liste (elle est vraie partout) et reste dans le détail.
- Marqueur de parcours par groupe sélectionné (puce en tête) : ✓ faite,
  ▶ recommandée ensuite, ○ à venir (roadmap lot 8 ; en attendant, sans
  groupe, aucun marqueur).
- Le bandeau « contenu en français » ne s'affiche qu'en `en` (déjà le cas) ;
  la ligne « 14 techniques · 29 séances » devient le sous-titre de l'en-tête.
- Onglets de la destination « Séances » : *Planifiées* (liste datée, « Lancer »
  dominant), *Catalogue*, *Suggestion* (R6).

### R13 — Détail d'une séance, mode « Préparer » (D1 à D4) — effort S

- `PhaseTimeline` sous la bascule de public, tapable (remplace « Aller à »).
- Carte d'exercice en deux colonnes dès 720 dp (schéma à gauche).
- Supprimer la phrase « lecture seule » ; l'absence de champ suffit, et le
  menu ⋮ propose « Signaler une proposition » qui ouvre un courriel ou copie
  l'identifiant de la séance (en attendant le workflow du lot 16).

### R14 — Fiche élève orientée progression (E1 à E4) — effort M

```
+--------------------------------------------------------+
| ← Élèves          Léa  · Enfants · présente 7/8        |
|                                                        |
|  En cours : Demi-bille · ex. 1    ●●○○○  2 passages/5  |
|  Prochain : Demi-bille · ex. 2                          |
|  ⚠ Bille pleine · ex. 3 · 3 échecs de suite  [ Vu ]    |
|                                                        |
|  Parcours                                               |
|  Posture ■■■■  Puissance ■■■■  Fantôme ■■■□  Pleine ■■□□|
|  Demi ■□□□  ¾ □□□□  ¼ □□□□  Finesse □□□□ …              |
|                                                        |
|  ▸ Courbes par exercice (4)                             |
|  ▸ Bilan de maturité · Modifier · Effacer               |
+--------------------------------------------------------+
```

- En-tête : exercice en cours avec ses pastilles, prochain, alerte avec
  acquittement (roadmap lot 10).
- **Parcours** : une ligne par technique dans l'ordre d'enseignement, une
  case par exercice (pleine = validé, hachurée = en cours, vide = à faire),
  tapable vers la courbe. Remplace la liste de 15 cartes.
- « 0 sur 72 » devient « 0 validé · 72 au programme » et disparaît dès que le
  positionnement initial (lot 7) marque des blocs acquis.
- Courbes repliées, actions rares en bas.

### R15 — Vue de groupe (E5) — effort M (roadmap lot 10)

Dans « Élèves », une grille technique × élève (cases pleines / hachurées /
vides, comme R14) et l'assiduité du groupe. C'est la vue qui fait ouvrir
l'application **entre** deux séances pour préparer la suivante.

### R16 — Suggestion reliée (S1 à S3) — effort M (roadmap lot 8)

La suggestion affiche la **séance du catalogue correspondante** (titre,
schémas) et deux actions : « Planifier » (crée la séance planifiée datée pour
ce groupe) et « Lancer ». « Pas de rappel » pour les enfants est accompagné de
« une seule notion par séance enfants » (F7).

## 4. Envie de revenir

Ce qui fait ouvrir l'application, dans l'ordre d'impact :

1. **« Aujourd'hui »** (R8) : il y a toujours quelque chose à voir ou à faire.
2. **La grille de saisie** (R11) : noter devient plus rapide que le papier,
   donc on note pendant la séance, donc les fiches vivent.
3. **Le parcours visible** (R14, R15) : l'animateur montre à l'élève où il en
   est sur la tablette à la fin de l'exercice ; l'élève demande à voir ses
   pastilles. Prévoir une **vue « à montrer à l'élève »** (sans alertes ni
   notes d'animateur, prénom et parcours seulement), ouverte depuis la fiche.
4. **Le bilan de fin de séance** : à « Terminer », un écran récapitule
   passages saisis, validations du jour, qui est à surveiller, et propose la
   prochaine séance du catalogue (roadmap lot 8) ; un bouton « Planifier »
   la crée. La boucle se ferme sans quitter l'écran.
5. **Rappels sobres** (H4, plateformes natives) : la veille d'une séance
   planifiée, « Préparer la séance de demain » ; trente jours sans sauvegarde,
   « Exporter ». Pas de notification de rétention artificielle : le public
   comprend des mineurs et le projet se veut outil, pas réseau.

Hors périmètre volontaire : classements entre élèves, badges virtuels,
séries de connexion. La motivation vient de la validation réelle des
exercices (bronze) et de la progression lisible, pas d'une couche de jeu.

## 5. Récapitulatif par effort

| Effort | Recommandations |
|---|---|
| S | R2, R7, R13 |
| M | R1, R3, R5, R6, R10, R12, R14, R15, R16 |
| L | R8, R9, R11 |

Dépendances fonctionnelles (roadmap) : R8 s'appuie sur le lot 6, livré
(séance planifiée datée et liée, ADR 0007) ; R12 (marqueur de parcours) et
R16 dépendent du lot 8 ; R14 (cases « acquis ») du lot 7 ; R14
(acquittement) et R15 du lot 10.
