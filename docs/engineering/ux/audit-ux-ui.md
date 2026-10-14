# Audit UX / UI des écrans de l'application

Rédigé le 2026-10-14 sur la branche `worktree-audit-ux-ui`, à partir de la
revue du code (`app/lib/pages`, `app/lib/features/*/presentation/ui`,
`app/lib/shared/ui`), du design system (`design-system.md`, ADR 0002, recherche
`identite-visuelle.md`), de la roadmap et d'un test de l'application en web
(build release, Chrome : 1 280 × 800 puis 390 × 844, thèmes clair et sombre,
deux élèves et une séance saisis). Le test a été fait avant la livraison du
lot 6 (ADR 0007 : séance planifiée datée et par groupe) ; la section 4.2 et
le constat T6 ont été relus sur le code livré. Les lots 7 (positionnement
initial, ADR 0008) et 8 (suggestion ↔ catalogue, ADR 0009) ont été livrés le
même jour, après l'audit : les constats qui les citent (« 0 sur 72 », C3, S1)
décrivent l'état antérieur ; leur reprise visuelle revient aux lots U8 et U9.
Les captures sont hors dépôt ; chaque constat cite l'écran et le fichier.

Documents liés : [recommandations-design.md](recommandations-design.md)
(quoi changer et comment) et [plan-ux-proposition.md](plan-ux-proposition.md)
(où l'insérer dans la roadmap).

## 1. Cadre de l'audit

### 1.1 Qui, où, quand

| Situation | Contraintes | Ce que l'écran doit permettre |
|---|---|---|
| **Avant la séance**, chez soi ou au club, posé | temps disponible, grand écran possible | choisir la séance, relire, planifier, voir où en est le groupe |
| **En salle, séance en cours**, debout, tablette ou téléphone en main, craie sur les doigts, 6 à 12 élèves, bruit | lecture en moins de 2 s, une main, cibles larges, zéro navigation inutile | voir l'étape, montrer un schéma, noter un passage, lancer un minuteur |
| **Montrer aux élèves**, tablette posée ou tenue à bout de bras, élèves à 1 ou 2 m | contraste, taille, aucun texte d'animateur, aucune donnée d'élève | le schéma seul, lisible à distance, position des billes exacte |
| **Après la séance**, rangement ou soir même | fatigue, saisie rapide | saisir ce qui n'a pas été noté, corriger, voir qui a validé quoi |

### 1.2 Ce qu'un élève de niveau 1 attend (côté Blackball)

- **Voir où viser** : point de contact sur la bille de couleur, bille fantôme,
  quantité de bille. Le schéma doit être sans ambiguïté sur la ligne de visée
  et la position exacte des billes (repères, ligne de départ, mouche).
- **Savoir ce qui doit se passer** : angle de départ de la bille de couleur,
  trajectoire vers la poche, comportement de la blanche après le choc.
- **Un retour immédiat et visible** : réussi ou manqué, combien sur combien,
  combien de passages avant la validation. La fiche résultats fédérale, avec
  ses pastilles, est la référence mentale.
- **Une progression visible dans le temps** : ce que j'ai validé, ce qui
  vient, pourquoi on refait cet exercice.

La précision du Blackball se joue au demi-centimètre de point de visée et au
degré de quantité de bille : tout schéma approximatif ou tronqué est un défaut
pédagogique, pas seulement esthétique.

### 1.3 Grille d'évaluation

Heuristiques de Nielsen (visibilité de l'état, correspondance avec le monde
réel, contrôle, cohérence, prévention des erreurs, reconnaissance plutôt que
rappel, flexibilité, esthétique minimaliste, aide à la récupération), WCAG 2.2
AA (contraste, cibles 48 dp, noms accessibles, lecture à 200 %), et trois
critères propres au projet : **lisibilité en salle**, **exactitude du
schéma** et **envie de revenir** (l'application a-t-elle une raison d'être
ouverte avant, pendant et après chaque séance ?).

Sévérité : **S1** bloque ou trompe en situation ; **S2** ralentit ou fait
hésiter ; **S3** finition.

## 2. Forces à préserver

- **Fondations d'accessibilité solides** : titres sémantiques, boutons
  nommés, cibles 48 dp, texte ≥ 12 px, contrastes vérifiés par test, jamais la
  couleur seule (lettre sur la bille, icône et texte sur chaque badge),
  description parlée de chaque illustration, `disableAnimations` respecté.
- **Design system réel et outillé** : jetons explicites, `ThemeExtension`
  pour billes et table, Widgetbook complet, garde-fou « tout widget public a
  un use case ».
- **Les schémas de table** : échelle réelle (48,0 / 50,8 mm), repères
  numérotés, trajectoires animées avec vitesse réglable, lecteur accessible.
  C'est l'atout différenciant de l'application.
- **Provenance honnête** : badge « Proposition » et filtres « à valider »,
  fidèles à la hiérarchie des sources.
- **Navigation adaptative** (barre en bas / rail), retour au guide à la même
  étape après la saisie, compteurs conservés, liens profonds par élève et par
  séance.
- **Saisie au compteur** plutôt qu'au clavier, adaptée au bord de table.

## 3. Constats transversaux

### T1 — Le rouge FFB en `secondary` colore tous les états « sélectionné » en rose (S2, design system)

Material 3 utilise `secondaryContainer` pour : l'indicateur de la barre et du
rail de navigation, les `ChoiceChip` et `FilterChip` sélectionnés, les
`SegmentedButton` sélectionnés, `FilledButton.tonal`, `IconButton.filledTonal`
et la piste du `LinearProgressIndicator`. Avec `secondary = #b80d1a`
(`app_color_schemes.dart`), chaque état sélectionné ou secondaire devient rose
saumon (`#fddad7`) en clair et **rouge sombre `#8c0012` en sombre**.

Conséquences observées :

- compteurs « + » et « − » de la saisie en rose (capture saisie), donc lus
  comme une alerte ;
- boutons « Précédent / Suivant » de la présentation en rose pâle, lus comme
  désactivés ;
- piste de la barre d'étape du guide rouge en thème sombre (capture guide
  sombre), lue comme « en erreur » ;
- puce « Groupe enfants » et segment « Enfants » sélectionnés en rose, badge
  « Enfants » lui aussi rose : le rose finit par vouloir dire « enfants »,
  « sélectionné » et « attention » à la fois.

Le rouge FFB est une couleur d'identité, pas une couleur d'état. Voir
recommandation R1.

### T2 — Hiérarchie visuelle plate (S2)

Toutes les surfaces sont des cartes grises `surfaceContainer` à bord
`outlineVariant`, élévation 0, titre `titleMedium`. Sur la fiche élève, la
saisie, le détail d'une séance, l'œil n'a pas de point d'entrée : l'action
principale, l'information du moment et les métadonnées ont le même poids.
Les pages sont des colonnes de cartes de même largeur (720 dp), même sur
desktop où 40 % de l'écran reste vide (capture accueil desktop).

### T3 — Aucune identité billard hors des schémas (S3)

L'interface est un formulaire Material propre : icônes génériques
(`edit_note` pour « Résultats », `event_note` pour « Séances »), aucune
texture, aucune bille, aucun tapis hors des diagrammes. Le seul élément
d'identité est le **logo FFB**, affiché en grand sur l'accueil et en petit sur
chaque page, **alors que l'ADR 0002 (décision 5) tranche « ne pas intégrer le
logo FFB » et que `design-system.md` note que l'autorisation reste à
obtenir**. L'écart entre décision et implémentation est un risque juridique
et d'image (l'application paraît officielle).

### T4 — Le badge « Proposition » est omniprésent en séance (S2)

Dans le guide, à l'étape « exercice » (capture guide desktop), trois badges
« Proposition » sont visibles avant même le contenu de l'étape (thème,
minutes de la phase, accroche ludique), plus « Source fédérale ». Ces marques
sont indispensables en **relecture** (ADR 0004, décision 7) mais parasitent la
lecture en **salle**, où l'animateur ne va rien valider. Un seul mode sert deux
intentions opposées.

### T5 — Architecture de l'information : « séance » a quatre sens et la planification est cachée (S2)

- La destination « Séances » ouvre le catalogue ; la **planification** n'est
  accessible que par le bouton de l'accueil (index 0 du shell) ; la
  **suggestion** est un bouton du catalogue ; les **séances saisies** sont
  sous « Résultats ». Quatre objets nommés « séance » dans quatre endroits.
- « Sauvegarde » occupe une destination principale pour une action mensuelle,
  alors que « Planification » (hebdomadaire) n'en a pas.
- Le rail reste visible pendant la séance guidée : cinq cibles de sortie à
  côté du contenu de l'étape.

### T6 — L'application n'a pas de « maintenant » (S1, envie de revenir)

Rien ne dit, à l'ouverture : quelle est la prochaine séance, y a-t-il une
séance commencée à reprendre, qui a une alerte, qu'est-ce qui a été validé
cette semaine. L'accueil est statique (logo, deux durées, un bouton) et
identique à chaque lancement. Les données existent pourtant depuis l'ADR
0007 (séances planifiées datées et par groupe, lien « Résultats saisis »,
séance guidée mémorisée) : aucun écran ne les compose. Un animateur n'a
aucune raison d'ouvrir l'application entre deux séances, et pendant la séance
il doit retrouver son chemin par le planificateur.

### T7 — Tout commence à « 0 sur 72 » (S2, motivation)

Liste des élèves, fiche élève : « 0 sur 72 exercices validés » pour chacun,
« Exercice suivant : Posture, visée et coup de queue · exercice 1 ». Pour des
élèves non débutants ou en cours de saison, l'application ment par omission
tant que le positionnement initial (roadmap lot 7) n'existe pas, et le
chiffre 72 écrase la progression réelle (5 passages réussis valident un
exercice : 360 passages réussis pour « finir »).

## 4. Constats par écran

### 4.1 Accueil (`pages/home`)

| # | Constat | Sév. |
|---|---|---|
| A1 | Écran de bienvenue sans contenu vivant : logo 96 dp, titre, carte « Deux publics » (information statique déjà connue), un seul bouton « Planifier une séance ». Aucune reprise de séance en cours, aucun raccourci « Saisir », aucune alerte élève. | S1 |
| A2 | Sur desktop, colonne de 720 dp centrée, 60 % de la page vide ; sur mobile, 45 % vide sous le bouton. | S3 |
| A3 | Le bouton mène au planificateur, hors des destinations du shell : l'onglet « Accueil » reste actif sur `/planner`, ce qui brouille la carte mentale. | S2 |
| A4 | Logo FFB en grand sans autorisation documentée (voir T3). | S2 |

### 4.2 Planification (`pages/session_planner`, `plan_session_form`, `session_list`)

| # | Constat | Sév. |
|---|---|---|
| P1 | Le formulaire (titre, séance du catalogue, groupe, public, date : cinq champs, ~400 dp depuis l'ADR 0007) est toujours ouvert en tête, même quand on ne vient que lire ses séances ; la liste arrive sous un écran de formulaire sur téléphone. | S2 |
| P2 | ~~Une séance planifiée n'a ni date ni groupe (F6).~~ Livré (ADR 0007) : date obligatoire, groupe facultatif, liste triée par date, lien « Résultats saisis ». Reste : la liste ne distingue pas visuellement la **prochaine** séance ni celles déjà passées, et rien ne remonte à l'accueil (T6). | S2 |
| P3 | Le titre est libre et prérempli par le titre de la séance du catalogue : deux champs pour une information ; une « séance libre » sans catalogue n'a aucun contenu à lancer. | S3 |
| P4 | Dans la liste, jusqu'à **quatre actions textuelles par ligne** (« Séance du catalogue : … », « Lancer », « Noter les résultats » ou « Résultats saisis », corbeille) de même poids, dans un `Wrap` qui passe sur deux lignes à 390 dp ; « Lancer » devrait dominer avant la séance, « Résultats saisis » après. | S2 |

### 4.3 Catalogue (`pages/sheet_catalogue`, `sheet_catalogue_view`)

| # | Constat | Sév. |
|---|---|---|
| C1 | La hiérarchie des lignes est inversée : « Séance 1/2 » en titre, le nom évocateur (« Le partage du gâteau ») en sous-titre gris. C'est le nom qu'on retient et qu'on dit aux élèves. | S2 |
| C2 | Jusqu'à cinq badges par ligne (« Source fédérale », « Proposition », « Exercices à valider », « Règle de lien du jeu à valider », « Théorie à valider »). Sur 29 lignes, presque toutes portent « Règle de lien du jeu à valider » et « Théorie à valider » : l'information discriminante (18 séances réellement à valider) se noie. Sur mobile, chaque ligne fait 190 dp : 2 séances par écran. | S2 |
| C3 | Aucune trace de ce que le groupe a déjà fait ni de la prochaine séance recommandée : le catalogue est un sommaire, pas un parcours (roadmap lot 8). | S2 |
| C4 | « Suggestion par groupe » est un bouton secondaire en haut du catalogue, sans lien visuel avec la liste ; une fois sur `/session`, l'onglet actif reste « Séances » mais on a quitté le catalogue. | S3 |
| C5 | Le bandeau « contenu en français » (en anglais seulement) et « 14 techniques · 29 séances · lecture seule » occupent la zone la plus visible pour dire ce qui ne change jamais. | S3 |

### 4.4 Détail d'une séance (`pages/sheet_detail`, `sheet_detail_view`)

| # | Constat | Sév. |
|---|---|---|
| D1 | Bonne structure (actions en tête, bascule de public, sommaire « Aller à », phases minutées). La phrase « Contenu en lecture seule : rien n'est modifiable ici » prend une ligne pour un fait sans action. | S3 |
| D2 | Les phases sont des titres suivis de cartes ; l'animateur ne voit pas d'un coup d'œil le **déroulé minuté** (10 / 20 / 35 / 20 / 5) sous forme de frise ou de barre proportionnelle. | S2 |
| D3 | Le schéma d'un exercice est sous le texte en une colonne, même à 1 280 px : la lecture « mise en place → schéma → consigne » exige de faire défiler. | S2 |
| D4 | La bascule de public « Enfants · 90 min » sélectionnée est rose (T1), le badge « Proposition » sur les minutes totales est répété sur chaque phase. | S3 |

### 4.5 Séance guidée (`pages/sheet_guide`, `run_sheet_view`, `run_step_views`) — écran critique en salle

| # | Constat | Sév. |
|---|---|---|
| G1 | **F3 confirmé** : avant le contenu de l'étape, l'écran empile retour, trois boutons d'action, carte minuteur, titre de la séance, public, carte « Thème » repliable, compteur d'étape, barre de progression, titre de phase. À 1 280 × 800 le schéma de l'exercice commence à 615 px (77 % de la hauteur) ; à 390 × 844, le schéma est à plus d'un écran de distance. En salle, l'animateur doit faire défiler pour voir la mise en place. | S1 |
| G2 | Le titre de la séance et le public sont répétés trois fois sur le même écran (bouton retour, titre `headlineSmall`, sous-titre). | S3 |
| G3 | « Terminer la séance » est à 8 dp de « Montrer », avec la même taille ; une confirmation existe, mais la proximité invite au faux geste. | S2 |
| G4 | Le minuteur (information la plus utile pendant une phase) est un texte `bodyLarge` dans une carte ; il ne se voit pas à 1 m. Aucun signal autre que texte à l'échéance (pas de couleur de fond, pas de vibration, pas de son). | S2 |
| G5 | Le rail de navigation reste visible : la séance n'est pas un mode immersif. | S2 |
| G6 | Sur une étape « exercice », l'ordre est objectif → passages → chevalet → bronze → mise en place → consigne → **schéma** → attendu → erreurs → accroche → défi → bouton « Noter ». Le schéma, qui résume la mise en place et la consigne, arrive en septième position. | S2 |
| G7 | Les initiations (compteur « 3 sur 5 ») et le score du jeu sont locaux et « non enregistrés dans le suivi » : la mention est répétée à chaque étape, le bilan la répète encore. L'animateur a fait l'effort de compter pour rien. | S2 |
| G8 | Bon : barre « Précédent / Suivant » épinglée et large, deux colonnes dès 720 dp, reprise d'une séance commencée. | : |

### 4.6 Présentation (`pages/sheet_presentation`, `run_presentation_view`)

| # | Constat | Sév. |
|---|---|---|
| M1 | **F1 confirmé et plus large** : à 1 280 × 800 les commandes du lecteur sont coupées à mi-hauteur, la légende et le badge sont hors écran ; le bas de la queue est coupé par le bord de la table. Sur 390 × 844, la table fait 310 px de large : une bille mesure 8 px, les repères « 1 » à « 6 » sont illisibles à 1 m. | S1 |
| M2 | Sur le schéma « Les six parts de gâteau », les étiquettes « 3 » et « 5 » sont recouvertes par la flèche en tirets de la blanche ; « B 1 » et « R » collent aux billes. Les annotations ne sont pas décalées hors des trajectoires (`table_diagram.dart`). | S1 |
| M3 | Les boutons « Précédent / Suivant » sont `FilledButton.tonal` donc roses (T1) ; « Fermer » bleu plein est l'élément le plus visible de l'écran alors que c'est l'action la moins fréquente. | S2 |
| M4 | La table est dessinée à ratio 9:5 dans une colonne : en paysage sur tablette, elle n'utilise pas la hauteur ; aucun plein écran réel (barre d'adresse, marges `ResponsiveBody`). | S2 |
| M5 | Bon : flèches clavier, balayage, position « Illustration 6 sur 8 », texte agrandi ×1,5. | : |

### 4.7 Saisie des résultats (`pages/record_setup`, `pages/record_session`, `pass_entry_card`, `attempt_history`)

| # | Constat | Sév. |
|---|---|---|
| R1 | **F4 confirmé** : le sélecteur d'exercice (`DropdownMenu`) n'a pas de nom accessible (snapshot : `button` sans libellé) et son libellé visible est tronqué sur mobile (« Posture, visée et coup de queue · n° 1 ( »). | S1 |
| R2 | La saisie est un formulaire par élève : deux compteurs, un bouton, un retour texte, soit ~300 dp par élève. Pour 10 élèves, 3 000 dp à parcourir pour un seul exercice ; l'animateur perd la vue d'ensemble « qui a déjà passé ». | S1 |
| R3 | Le compteur « Billes empochées » ne ressemble pas à la fiche fédérale (une case par essai) : taper 6 fois sur « + » pour 6 sur 6 est plus long que cocher des pastilles, et « Tentatives » est rarement changé. | S2 |
| R4 | Le retour « Passage enregistré : 3 sur 4, objectif atteint » est du texte courant ; la validation et l'alerte sont des badges sous le bouton. Rien ne marque visuellement « réussi » au niveau de la carte. | S2 |
| R5 | « Passages de la séance » liste `Léa · Posture… · exercice 1 : 3 sur 4` avec crayon et corbeille ; sans score, sans élève groupé : relire une séance de 20 passages est pénible. | S3 |
| R6 | L'ouverture de séance redemande groupe, présents, date à chaque fois hors guide ; la date par défaut est bonne mais le libellé « Changer la date » est un lien texte à droite, séparé de la valeur. | S3 |

### 4.8 Élèves et fiche élève (`pages/students`, `club_list`, `student_sheet_view`, `block_progress_list`, `exercise_curve_card`)

| # | Constat | Sév. |
|---|---|---|
| E1 | Liste : prénom, badge public, « 0 sur 72 exercices validés » (T7). Aucune indication de la dernière présence, ni de l'alerte sous forme visible quand il n'y en a pas (bien), mais rien non plus pour l'exercice en cours. | S2 |
| E2 | Fiche : deux boutons d'action, badge, « 0 sur 72 », puis cinq cartes de même poids (Exercice suivant, Notion à rappeler, Assiduité, Progression par bloc, Courbes). La **progression par bloc** (15 blocs × 4 lignes) fait ~1 500 dp ; les courbes suivent. Rien n'est repliable. | S2 |
| E3 | Les courbes sont fidèles à la fiche fédérale (bon) mais arrivent après 2 000 dp de défilement ; aucune vue « saison » (pastilles des 5 passages par exercice) n'est offerte, alors que c'est ce que l'élève veut voir. | S2 |
| E4 | « Modifier le prénom » et « Bilan de maturité » en tête de fiche : actions rares, position premium. « Effacer » en bas, bien. | S3 |
| E5 | Aucune vue de groupe (qui a validé quoi, heat-map bloc × élève, assiduité du groupe), pourtant prévue par l'ADR 0003 et la roadmap (lot 10). | S2 |

### 4.9 Suggestion par groupe (`pages/suggested_session`, `session_plan_view`)

| # | Constat | Sév. |
|---|---|---|
| S1 | Le résultat est une liste de cartes textuelles (durée, notion, phases, exercices, rappel) sans schéma ni lien vers la séance du catalogue correspondante (roadmap lot 8) ; l'animateur doit refaire le lien à la main. | S2 |
| S2 | « Pas de rappel » pour les enfants sans explication (F7). | S3 |
| S3 | Le bouton « Saisir les résultats » ouvre une saisie vide : la suggestion ne devient jamais une séance planifiée ni guidée. | S2 |

### 4.10 Sauvegarde, formulaire élève, bilan de maturité

| # | Constat | Sév. |
|---|---|---|
| B1 | Sauvegarde : deux boutons et un paragraphe pour une destination principale ; aucune date de dernière sauvegarde, aucun rappel. | S2 |
| B2 | Formulaire élève : clair, minimal (prénom, public), bonne mention des données de mineurs. | : |
| B3 | Bilan de maturité : trois notes 1 à 4 et un texte ; l'aide à la décision est textuelle. Acceptable, usage rare. | : |

### 4.11 Accessibilité et thèmes

| # | Constat | Sév. |
|---|---|---|
| X1 | Tous les titres sont exposés au niveau 2 (aucun niveau 1 par page) : la hiérarchie parlée est plate. | S3 |
| X2 | Thème sombre : la piste de progression et les conteneurs secondaires passent au rouge sombre (T1) ; le tapis sombre `#2d6a8a` reste lisible. | S2 |
| X3 | Les boutons icône du minuteur (lecture, remise à zéro) ont un tooltip mais aucune étiquette visible : à 1 m, une icône de 24 px ne se lit pas. | S3 |
| X4 | Bon : noms accessibles complets sur les compteurs (« Une bille empochée de plus pour Léa »), régions vivantes sur le compteur d'initiation et l'alerte du minuteur. | : |

## 5. Synthèse

| Sévérité | Constats |
|---|---|
| **S1** | T6 (pas de « maintenant »), A1, G1, M1, M2, R1, R2 |
| **S2** | T1, T2, T4, T5, T7, A3, A4, P1, P2, P4, C1, C2, C3, D2, D3, G3, G4, G5, G6, G7, M3, M4, R3, R4, E1, E2, E3, E5, S1, S3, B1, X2 |
| **S3** | T3, A2, P3, C4, C5, D1, D4, G2, R5, R6, E4, S2, X1, X3 |

Trois causes expliquent la majorité des constats :

1. **Un seul mode d'affichage** pour trois situations (préparer, mener,
   montrer) : la densité d'information de la relecture se retrouve en salle
   et en présentation (G1, G5, G6, M1, M4, T4).
2. **Des objets reliés mais jamais composés** : l'ADR 0007 relie séance
   planifiée, saisie et séance du catalogue, mais aucun écran n'en tire une
   vue « maintenant » ; la suggestion reste isolée du catalogue (T6, A1, P2,
   C3, S1, S3).
3. **Un jeu de jetons où le rouge d'identité joue le rôle d'état** (T1, et
   par ricochet M3, R3, X2, D4).

Les recommandations qui en découlent sont dans
[recommandations-design.md](recommandations-design.md).
