# Plan : export PDF d'une séance du catalogue et fiche résultats papier (lot 14)

Statut : **livré le 2026-10-17** (conception puis réalisation le même jour ; voir § 12 pour les écarts, les rouges, les mutations et le parcours web). Lot **14** de la
[roadmap](roadmap.md). Décision structurante : [ADR 0021](adr/0021-export-pdf-feuille-animateur-et-fiche-resultats.md)
(`pdf` en API bas niveau, mise en page en domaine pur, schémas dessinés en
vectoriel, aucune donnée nominative par défaut). S'appuie sur l'[ADR 0004](adr/0004-catalogue-fiches-seances.md)
(séances du catalogue), l'[ADR 0011](adr/0011-creneau-exercice-de-rappel.md)
(créneau de rappel), l'[ADR 0012](adr/0012-reglages-du-club.md) (`RulesConfig`),
l'[ADR 0018](adr/0018-hors-ligne-service-worker-precache-versionne.md) (hors
ligne), [architecture](architecture.md), [testing](testing.md),
[quality-gates](quality-gates.md).

Deux documents, un seul mécanisme :

| Document | Contenu | Données d'élèves |
|---|---|---|
| **Feuille de l'animateur** | une séance du catalogue pour un public : déroulé et minutes, consignes, schémas de table, provenance, sources | **aucune** |
| **Fiches résultats** | la fiche du PDF fédéral, 4 grilles par page A4, une série par exercice d'entraînement de la séance | noms **vides par défaut** ; prénoms d'un groupe sur demande |

## 1. Constats sur le code et sur la source fédérale

| Élément | Constat | Conséquence |
|---|---|---|
| Dépendances | ni `pdf` ni `printing` dans `app/pubspec.yaml` ; `file_picker` sert déjà à la sauvegarde (`BackupFiles`, `FilePickerBackupFiles` : téléchargement web, boîte d'enregistrement ailleurs) | un seul ajout (`pdf`), l'enregistrement se réutilise |
| Impression navigateur | build web actuel, `@media print` émulé : 1 page A4, écran rasterisé et tronqué, 0 caractère extractible (mesure de l'ADR 0021) | la feuille ne peut pas venir du navigateur : il faut produire un PDF |
| Domaine pur | `domain` et `shared/lib` n'acceptent que `dart:core/async/collection/convert/math`, `freezed_annotation`, `injectable`, `meta` (`tool/architecture`) | pas de `dart:typed_data` ni `dart:ui` dans le domaine : les ports rendent des `List<int>` ; la conversion en `Uint8List` est dans `data` |
| Déroulé | `ResolveRunPlan` (feature `run_sheet`) résout étapes, minutes (`sheetTiming`, `RulesConfig.shapes`), taux du catalogue, schémas et bloc du rappel de résultats | **une feature ne peut pas en importer une autre** (FSD) : voir § 4, la correspondance se fait dans la couche `app` |
| Schémas | `ExerciseDiagram.table` (`DiagramTable`, domaine) : billes, repères, flèches, zones, annotations, tirs ; `TableDiagramSpec` et le painter sont dans `shared/ui/table_diagram` (Flutter) | le dessin imprimé part de `DiagramTable`, pas du painter |
| Illustrations de séance | 12 variantes (`Illustration` : `diagramRef`, `table`, `contact`, `contactStrip`, `ghostAim`, `cueBallTarget`, `playerFigure`, `ballSize`, `contactHeight`, `powerRatio`, `angle`, `pdfRef`) ; `caption` et `alt` toujours non vides (invariant de `SessionSheet`) | V1 : schémas de table dessinés, les autres imprimés en légende + texte alternatif (U14-9) |
| Fiche fédérale | A4 595 × 842 pt ; **4 blocs** (2 × 2) ; pas horizontal 268,25 pt (x = 14,4 puis 282,65), pas vertical 381,8 pt (y = 62,6 puis 444,4) ; par bloc : « Nom : », 5 colonnes « ESSAI n » (x = 89,4 ; 122,1 ; 154,6 ; 187,1 ; 219,7, pas ≈ 32,5), ligne « Nb de billes empochées /…. » (y = 90,6), « Séance : », « Exercice : » (y = 130,6 et 145,1), « Notion », « Technique : » (y = 173,9 et 188,3), grille de 5 colonnes sur un axe **0 à 16** (≈ 14,3 pt par unité), légendes « essai 1 » à « essai 5 » sous la grille, titre « Fiche Résultats » (x = 42,6, y = 19,4), onglet vertical « BLACKBALL / FICHE RESULTATS » à droite, bas de page | le gabarit est figé par des constantes mesurées (`pdftotext -bbox`), testées ; 16 = `SuccessRate.maxAttempts` |
| Polices | Exo 2 variable (regular, italique), OFL, déjà précachée ; **sans** `θ`, `✓`, `→` ; `θ` apparaît dans `13-finesse-1` et `10-trois-quarts-1` | normalisation `θ` → « thêta » + garde sur tout le catalogue |
| `PassDots` | pastilles tapables (48 dp), `total` pastilles, score « x/n » | inadapté au papier ; la notion partagée est « un passage = n empochées sur total » (U14-1) |
| Séance en cours | `RunProgress` sans identifiant d'élève (ADR 0020) | rien à lire pour la feuille de l'animateur |

## 2. Décisions

**Décidées par l'ADR 0021** (rappel) : `pdf` bas niveau seul, scène d'impression
en domaine pur à deux rendus (PDF, aperçu), schémas en vectoriel, Exo 2,
Enregistrer (`file_picker`) et Imprimer (web, iframe), aucun nom par défaut,
provenance en texte, aucune migration.

**Décidées ici sans question à l'animateur** (conséquences techniques) :

1. **Unités et repère** : points (1/72 po), origine en haut à gauche, `y` vers
   le bas ; le rendu PDF retourne l'axe. A4 portrait 595 × 842 pt.
2. **Texte** : `PrintText` porte **une ligne déjà coupée** ; la coupure est faite
   par le domaine avec `TextMeasure.width(texte, taille, style)`. Le rendu PDF
   fournit la mesure par `PdfTtfFont.stringMetrics` (même police que l'écriture,
   donc aucune différence entre coupure et dessin). Les tests fournissent une
   mesure à chasse fixe.
3. **Texte imprimable** : `printable(String, thetaWord:)` remplace `θ` par le mot de la langue (« thêta »),
   normalise les espaces insécables et `…`, et **signale** (exception
   `InvariantViolation`) tout caractère absent de la police et de la table de
   remplacement : on préfère un export refusé avec un message à un carré vide.
4. **Pagination** : par blocs insécables (titre + premier paragraphe, un exercice
   entier si possible) ; jamais de titre en bas de page ; un schéma n'est jamais
   coupé ; un exercice plus haut qu'une page se coupe entre ses sections.
5. **Minutes** : lues dans `SheetTiming` / `RunStep.minutes` (jamais recalculées
   par l'export) ; l'heure de début de chaque étape est le cumul des minutes
   précédentes (« 0–5 », « 5–25 »…) ; somme affichée = 90 ou 120 par
   construction.
6. **Nom de fichier** : `seance-<id>-<enfants|adultes>.pdf`,
   `fiches-resultats-<id>-<exercice>.pdf` ; jamais de nom d'élève ni de groupe.
7. **Erreurs** : séance inconnue → `NotFound` (message existant) ; caractère non
   imprimable → `InvariantViolation` (message « Contenu non imprimable : … »,
   détail dans les journaux) ; enregistrement annulé → résultat neutre « annulé »,
   rien n'est écrit ; échec d'écriture → `Failure` existant.
8. **Pas de nouvelle route** : les entrées sont dans le menu ⋮ du détail d'une
   séance et, ensuite, du guide (lot suivant, hors périmètre) ; les options
   s'ouvrent dans une feuille basse, l'aperçu dans une page plein cadre hors
   shell (comme le guide, ADR 0015).

## 3. Questions à l'animateur `[U]` (défaut proposé = ce que le plan suppose)

| # | Question | Défaut |
|---|---|---|
| U14-1 | La fiche résultats est-elle **identique** à celle du PDF fédéral (grille à pointer, axe 0 à 16, colonnes d'essais) ? La roadmap parlait de `PassDots` ; sur papier, des pastilles ne remplacent pas la grille. | **Identique** ; colonnes = `passesRequired` (5 par défaut, donc identique ; 6 si réglé à 6, comme l'exemple du mémento) ; pas de pastilles |
| U14-2 | Public de la feuille de l'animateur | public affiché sur le détail, modifiable dans la feuille d'options |
| U14-3 | Prénoms d'un groupe sur la fiche résultats | **non** (noms vides) ; case « Prénoms du groupe » + avertissement ; prénoms seuls |
| U14-4 | Pré-remplir « Séance », « Exercice », « Notion », « Technique » et le dénominateur « /n » de « Nb de billes empochées » | **oui** (n = tentatives du taux de la fiche d'exercice si connu, sinon « /…. » vierge) |
| U14-5 | Nombre de grilles | un exercice par série ; effectif du groupe arrondi au multiple de 4 ; sans groupe : 8 (2 pages) ; maximum 40 |
| U14-6 | Format et encre | A4 portrait, noir et blanc, marges de 15 mm sur la feuille de l'animateur (la fiche fédérale garde ses marges) |
| U14-7 | Enregistrer seulement, ou aussi Imprimer sur le web | **les deux** ; Imprimer masqué hors web |
| U14-8 | Aperçu à l'écran avant l'export | **oui** (même scène que le PDF, mesure de texte du PDF ; léger écart de rendu du texte) |
| U14-9 | Illustrations qui ne sont pas des schémas de table | légende + texte alternatif en V1 ; dessin plus tard si besoin |
| U14-10 | Reproduire l'onglet vertical « BLACKBALL / FICHE RÉSULTATS » et citer la source en pied | **oui** (gris, sans logo, décision UX Q2) |
| U14-11 | Langue du texte de séance | français (catalogue non traduit) ; libellés fixes (feuille de l'animateur **et** fiches résultats) en fr ou en selon l'interface ; `θ` s'écrit « thêta » ou « theta » (`PrintLabels.thetaWord`) |
| U14-12 | Contenu des exercices imprimés | titre, mise en place, consigne, attendu, taux de réussite (`SuccessRate`), passages, **erreurs fréquentes**, accroche et défi ludique `[Prop]` ; **pas** de texte de théorie complet (titre, points clés seulement) |

## 4. Architecture (FSD + Clean)

```
app/lib/features/export_sheet/
├── domain/
│   ├── print_scene.dart           PrintDocument, PrintPage, PrintItem (sealed) : PrintText, PrintLine,
│   │                              PrintPolyline (tirets), PrintRect, PrintCircle, PrintPolygon ; PrintStyle
│   ├── text_measure.dart          port TextMeasure (largeur d'un texte, taille, style)
│   ├── printable_text.dart        printable(), table de remplacement, détection des glyphes absents
│   ├── print_labels.dart          PrintLabels : libellés fixes (fournis par la présentation depuis l'ARB)
│   ├── sheet_print_input.dart     SheetPrintInput + SheetPrintStep : entrée pure (aucun élève)
│   ├── layout_animator_sheet.dart mise en page de la feuille (pagination, déroulé, schémas)
│   ├── diagram_scene.dart         DiagramTable -> éléments d'une boîte (table 8 x 4 cases, poches, billes…)
│   ├── results_template.dart      constantes du gabarit fédéral
│   ├── layout_results_sheets.dart mise en page des fiches résultats (ResultsSheetInput : exercices, noms)
│   ├── print_renderer.dart        port PrintRenderer (open() -> mesure + render(PrintDocument) -> List<int>)
│   ├── pdf_files.dart             port PdfFiles (save, print, isPrintSupported)
│   ├── export_animator_sheet.dart cas d'usage (mise en page + rendu + sortie)
│   └── export_results_sheets.dart cas d'usage (idem ; lit les prénoms d'un groupe seulement si demandé)
├── data/
│   ├── pdf_print_renderer.dart    interprète la scène avec `pdf` bas niveau (Exo 2 par rootBundle)
│   ├── file_picker_pdf_files.dart enregistrer (file_picker) ; imprimer : implémentation web par js_interop
│   └── (variantes en mémoire pour les tests : test/support)
└── presentation/
    ├── bloc/export_sheet_cubit.dart   états : choix, préparation, aperçu prêt, enregistré, annulé, échec
    └── ui/                            ExportOptionsSheet (feuille basse), PrintPreviewView (CustomPaint de
                                       la scène, une page à la fois), PrintScenePainter
```

- **Correspondance déroulé -> entrée pure dans la couche `app`**
  (`app/sheet_export.dart`, comme `record_screens.dart`) : une fonction pure
  `sheetPrintInputFrom(RunPlan, Audience, …)` met en forme le `RunPlan` produit
  par `ResolveRunPlan` (étapes, minutes, fiche, taux, schémas) en
  `SheetPrintInput`. Alternative écartée : remonter le séquencement des étapes
  dans `entities/session_sheet` (refactor de `run_sheet`, hors périmètre,
  risque pour le guide).
- **Page** : `SheetDetailPage` reçoit `onExport(Audience)` et
  `onExportResults(Audience)` (comme `onLaunch`) ; le routeur les câble.
- **Prénoms** : `ExportResultsSheets` lit `GroupRepository` et
  `StudentRepository` (entités) **seulement** si l'option est active ; sans
  l'option, aucun dépôt d'élèves n'est appelé (scénario BDD avec dépôt espion).
- **`pdf` n'est importé que dans `data/pdf_print_renderer.dart`** ; règle
  d'architecture : `package:pdf/widgets.dart`, `package:printing/` et
  `package:pdf/src/` interdits dans `lib/` (le test de garde des glyphes
  utilise `src/` dans `test/` seulement).
- **Pas de couche `shared`** : la scène est propre à la feature ; si une
  seconde feature (guide, impression d'un bilan) en a besoin, elle remontera
  dans `shared/lib` par une décision séparée.

### Scène d'impression (domaine)

- `PrintText(x, y, text, size, style, align?, rotation?)` : `style` ∈ `regular`,
  `italic`, `bold` (gras simulé), `boldItalic` ; `rotation` ∈ {0, 90} (onglet
  vertical).
- `PrintPolyline(points, width, dash?)` : tirets `[3, 2]` (blanche), points `[0.5, 2]`
  (indication), plein (bille touchée), même convention qu'à l'écran.
- `PrintCircle(center, radius, fill?, stroke?)`, `PrintRect`, `PrintPolygon`
  (pointes de flèche), `PrintLine`.
- Niveaux de gris seulement : `PrintShade` ∈ {noir, gris foncé, gris clair,
  blanc} (`PdfColor` du rendu) ; **jamais la couleur seule** : chaque bille porte
  sa lettre (B, R, J, N) et son repère « x4 » éventuel.
- `PrintDocument(title, language, pages)` ; chaque page déclare sa taille.

### Schémas imprimés

`diagram_scene(DiagramTable, Rect box)` : table 8 × 4 cases à l'échelle
(`BlackballDimensions`), poches (6), ligne de départ à x = 1,6, billes (lettre
dans le cercle, rayon proportionnel à la table), repères creux (`cueStart`,
`impact`), flèches (trait selon `DiagramArrowKind`, pointe en polygone), zones
(rectangle pointillé), annotations (texte placé sans chevauchement par la
**même** table de positions que `label_placement.dart` : voir § 9, risque 2).
Largeur de la boîte = largeur utile de la colonne ; hauteur = moitié. Les tirs
successifs sont tous dessinés (état initial + trajectoires), numérotés comme à
l'écran en lecture sans animation.

## 5. Contenu des documents

### Feuille de l'animateur (A4 portrait, ordre de lecture = ordre de la séance)

1. **En-tête** : titre de la séance, technique et partie, public et durée
   (« Enfants, 90 min »), notion principale, niveau « Technique 1 », nom de
   l'application et date d'impression (jour seul, sans heure).
2. **Déroulé** (tableau) : phase, élément, début–fin, minutes, marque de
   provenance ; total = 90 ou 120 ; note « minutes `[Prop]`, calculées par
   l'application ».
3. **Une section par étape**, avec marque de provenance :
   - accueil / rappel : points à rappeler, question, réponse attendue ;
   - théorie : titre, points clés (U14-12) ;
   - initiation : mise en place, but, attendu, comptage, schéma ;
   - exercices : titre, mise en place, consigne, attendu, taux (« 5 sur 10 »),
     passages (« 1 passage »), erreurs fréquentes, accroche et défi `[Prop]`, schéma ;
   - **créneau de rappel** : « Exercice de rappel : choisi pendant la séance
     d'après le suivi des élèves » (aucun nom, aucun exercice nominatif) ;
   - jeu : titre, joueurs, règles, comptage, fin, variante ludique `[Prop]`,
     adaptation signalée `[Prop]`, schéma de mise en place ;
   - bilan : questions du bilan.
4. **Sources** : fichier, page, rang (`[S]` d'abord) ; **Points à vérifier**
   (`uncertainties`) en petit si présents.
5. **Pied de page** : « `[Prop]` : proposition non sourcée, à valider. »,
   numéro de page « n / N », titre abrégé.

### Fiches résultats (A4, reproduction du PDF fédéral)

Une série par exercice d'entraînement affiché pour le public (et le créneau de
rappel n'est pas imprimé : exercice inconnu). Chaque bloc : « Nom : »
(vide ou prénom), colonnes « ESSAI 1 » à « ESSAI n », « Nb de billes empochées »
avec « /n » (U14-4), « Séance : » (titre court), « Exercice : » (numéro et
titre), « Notion » (notion), « Technique : » (technique), grille et axe 0 à 16,
légendes « essai k ». Titre « Fiche Résultats » en haut de chaque page, onglet
vertical à droite, bas de page : source `[S]`. Les blocs vides de la dernière
page restent vides (gabarit complet, comme le PDF fédéral).

## 6. Scénarios BDD (écrits d'abord, vus en rouge)

`app/test/bdd/export_sheet.feature` (mots-clés Gherkin en anglais, libellés en
français ; domaine via get_it et dépôts en mémoire, rendu par un renderer de test
qui mesure à chasse fixe ; l'aperçu par widget) :

1. **Feuille enfants** : « Exporter la feuille de l'animateur d'une séance, public
   enfants » -> l'aperçu montre le titre, « Enfants, 90 min », et le total du
   déroulé vaut 90.
2. **Feuille adultes** : 120 min, rappel présent.
3. **Provenance** : une proposition `[Prop]` du catalogue apparaît marquée
   `[Prop]` et la légende est en pied de page ; les minutes sont signalées
   `[Prop]`.
4. **Aucun nom** : avec des élèves et un groupe dans le club, la feuille ne
   contient aucun prénom ni nom de groupe, et aucun dépôt d'élèves n'est lu.
5. **Créneau de rappel** : la deuxième séance d'une technique montre « choisi
   pendant la séance », jamais un exercice nominatif.
6. **Schéma** : un exercice avec schéma imprime sa table (6 poches, billes
   lettrées) ; une illustration sans schéma de table imprime sa légende et son
   texte alternatif.
7. **Enregistrer** : le fichier porte le nom `seance-<id>-enfants.pdf` ; annuler la
   boîte n'écrit rien et affiche « Enregistrement annulé ».
8. **Séance inconnue** : message de page introuvable, aucun fichier.
9. **Imprimer** : visible quand la plate-forme sait imprimer, absent sinon.
10. **Hors ligne (domaine)** : l'export ne dépend d'aucun accès réseau (tous les
    dépôts et le renderer sont locaux) ; la vérification réelle est le parcours
    § 10.

`app/test/bdd/export_results.feature` :

1. **Quatre grilles par page** ; neuf élèves -> trois pages ; sans groupe -> 8
   grilles, deux pages.
2. **Gabarit fédéral** : 5 colonnes d'essais, axe de 0 à 16 (17 graduations),
   « essai 1 » à « essai 5 » ; réglage `passesRequired` à 6 -> 6 colonnes.
3. **Pré-remplissage** : « Séance », « Exercice », « Notion », « Technique » et
   « /10 » pour un exercice au taux 5 sur 10 ; « /…. » sans taux.
4. **Noms vides par défaut** ; avec « Prénoms du groupe » : les prénoms des
   élèves **actuels** du groupe, dans l'ordre alphabétique, en tête de grille ;
   l'avertissement de fichier nominatif est affiché avant l'export.
5. **Pas de lecture sans option** : dépôt espion, zéro appel quand l'option est
   décochée.
6. **Un exercice par série** : deux exercices -> deux séries, la deuxième
   commence sur une nouvelle page.
7. **Source citée** : « Fiche Résultats CFA Blackball, Direction Technique
   Nationale » en pied de page ; aucun logo.

## 7. Tests unitaires (TDD, rouge puis vert) et tests après coup

**TDD (rouge constaté avant le code)**, `test/unit/features/export_sheet/` :

- `printable_text_test` : `θ` -> « thêta », `…`, accents conservés, caractère
  inconnu refusé ; **garde sur tout le catalogue** : chaque caractère des textes
  imprimables des 28 séances et des 70 exercices est dans la table des glyphes
  d'Exo 2 (chargée par `dart:io`) ou dans la table de remplacement.
- `layout_animator_sheet_test` : coupure de ligne aux bornes (mot plus long que la
  ligne, ligne exacte), pas de titre orphelin, un schéma jamais coupé,
  pagination d'un exercice plus haut qu'une page, minutes cumulées (« 0–5 »),
  somme 90 et 120 aux bornes, marque `[Prop]` sur chaque élément proposé, absence
  de toute chaîne nominative pour une entrée construite avec des élèves en
  contexte, créneau de rappel sans exercice.
- `diagram_scene_test` : positions des billes (x, y en cases × échelle), 6 poches,
  ligne de départ, trait par nature de flèche, lettre dans chaque bille, schéma
  vide, **parité** avec la géométrie d'écran sur les points caractéristiques
  (centre des poches, ligne de départ, première bille) tirés de
  `BlackballDimensions`.
- `results_template_test` : chaque constante du § 1 (pas, colonnes, axe) ;
  `layout_results_sheets_test` : 4 par page, ceil(n/4) pages, colonnes =
  `passesRequired` bornées 3 à 8, dénominateur, prénoms triés, aucune lecture de
  dépôt sans option.
- `export_animator_sheet_test` et `export_results_sheets_test` : enchaînement mise
  en page -> renderer -> sortie avec doublures du renderer et de `PdfFiles` ;
  annulation, échec d'écriture, séance inconnue.
- `tool/architecture` : un fichier de `lib/` qui importe `package:pdf/widgets.dart`
  ou `package:printing/` est signalé (test rouge d'abord).

**Après coup, validés par mutation** (le code existe avant le test, donc on
prouve que le test échoue quand on casse le code) :

- `pdf_print_renderer_test` (fumée) : en-tête `%PDF-`, nombre de pages = nombre de
  pages de la scène, `/FontFile2` présent (police embarquée), aucune chaîne
  `http` ni action `/URI`, document non compressé pour la lecture (`compress:
  false` en test), taille bornée ; mutations : ordre des pages, police non
  chargée, axe y non inversé (un cercle de référence se retrouve dans le flux).
- `print_scene_painter_test` : une scène connue peint le bon nombre
  d'éléments (`PictureRecorder` + comptage) ; mutation : un type d'élément oublié.
- `file_picker_pdf_files_test` : type MIME et nom de fichier transmis ; mutation :
  extension changée.
- Mutation du gabarit : décaler une constante de `results_template` fait échouer
  le test de gabarit ; supprimer l'arrondi à 4 fait échouer « neuf élèves ».

**Widget / Widgetbook** : `ExportOptionsSheet` (public, exercices, groupe, case
prénoms avec avertissement), `PrintPreviewView` (page n sur N, boutons
Précédent/Suivant, Enregistrer, Imprimer) : un use case Widgetbook chacun
(`check_widgetbook`) ; états : préparation, échec, annulé.

## 8. i18n et accessibilité

- Clés fr + en identiques (`check_l10n`) : libellés du menu, de la feuille
  d'options, de l'aperçu, de l'avertissement nominatif, des messages d'état, et
  `PrintLabels` du document (titres de sections, « Déroulé », « Minutes »,
  « Provenance », « Sources », « Nom : », « ESSAI », légende `[Prop]`…). Environ
  60 clés. *Décision initiale, révisée après la revue d'architecture du lot 14 :*
  les libellés de la fiche fédérale (`ResultsLabels`) suivent **aussi** la langue
  de l'interface, comme ceux de la feuille de l'animateur (ADR 0021) ; le français
  reproduit la fiche fédérale, l'anglais en est la traduction (`app_en.arb`).
  Le domaine ne garde que les dimensions de la grille.
- Aperçu : un `Semantics` par page (« Aperçu, page 1 sur 3 ») ; la scène n'est pas
  exposée ligne à ligne (le contenu est déjà lisible sur le détail de la séance) ;
  boutons ≥ 48 dp ; états doublés d'un texte (jamais la couleur seule).
- PDF **non balisé** (limite de `pdf`, ADR 0021) : dit dans l'aide de la feuille
  d'options en une phrase.

## 9. Impacts et risques

**Impacts** : `pubspec.yaml` (+ `pdf`), `pubspec.lock` (+ `archive`, `barcode`,
`bidi`, `image`, `path_parsing`, `qr`), `lib/app/di/injection.config.dart`
(régénéré, jamais à la main), `l10n` fr/en + `generated` (régénéré),
`tool/architecture/architecture_rules.dart` + test, routeur (`onExport`,
`onExportResults`, page d'aperçu hors shell), `app/sheet_export.dart` (nouveau),
`sheet_detail_page.dart` (menu), Widgetbook (2 use cases), `architecture.md`
(arborescence, entrée export), `testing.md` (rendu PDF, mutations),
`quality-gates.md` (règle d'import), roadmap (lot 14 livré), `adr/README.md`.
**Inchangés** : schéma drift (v10), sauvegarde (v4), service worker et précache
(aucun asset ajouté ; +≈ 0,08 Mo de code), `docs/sources`, `docs/knowledge`.

**Risques** :

1. **Mesure du texte différente entre l'aperçu et le PDF** : la coupure est faite avec
   les métriques du PDF, l'aperçu dessine avec Flutter ; écart de largeur
   possible de quelques points, jamais de coupure différente. Accepté (U14-8).
2. **Duplication de la géométrie des schémas** (painter d'écran et scène
   imprimée) : test de parité sur les points caractéristiques ; placement des
   étiquettes réutilisé en copiant la table `LabelSlot` (pure) plutôt qu'en
   important `shared/ui` (le domaine ne peut importer que `shared/lib`) ; si la
   table diverge, le test de parité casse. Suite possible : remonter la scène
   dans `shared/lib` et faire consommer la même par le painter (refactor
   séparé).
3. **Gras simulé** peu lisible : jugé à l'impression réelle ; repli : titres en
   taille plus grande plutôt qu'en gras.
4. **Boîte d'impression du navigateur** non pilotable : seul le PDF est vérifié
   automatiquement ; l'impression directe est vérifiée à la main (Chromium) ;
   iPhone Safari et PWA Android non vérifiés.
5. **Taille d'un export** : 3 à 5 pages de texte et vecteurs, quelques dizaines
   de Ko attendus (essai : 5,6 Ko pour une page de texte avec deux polices) ;
   garde : borne de 400 Ko dans le test de fumée.
6. **Séance très longue** (théorie dense) : jusqu'à 6 pages ; mesure sur les 28
   séances (nombre de pages) consignée dans le plan à la livraison ; au-delà de 6,
   revoir U14-12.
7. **Contenu `uncertainties`** : peut paraître déroutant à l'animateur ; imprimé
   en petit, sous « Points à vérifier », désactivable (option de la feuille).
8. **PDF nominatif** hors du périmètre d'effacement : avertissement, opt-in,
   défaut non (U14-3).

## 10. Étapes (chaque étape se termine vert avant la suivante)

| # | Étape | Couches | Preuve |
|---|---|---|---|
| 0 | ADR 0021 accepté sur les défauts ; `pdf` ajouté ; règle d'import dans `tool/architecture` (rouge puis vert) | pubspec, tool | `check_architecture` |
| 1 | Les deux `.feature` + steps ; **rouge constaté** | tests | `flutter test test/bdd` en échec pour la bonne raison |
| 2 | `printable_text`, scène, `TextMeasure`, garde catalogue (TDD) | domain | tests unitaires rouges puis verts |
| 3 | Gabarit fédéral et `layout_results_sheets` (TDD) | domain | idem |
| 4 | `diagram_scene` (TDD) | domain | idem + parité |
| 5 | `layout_animator_sheet` (TDD) | domain | idem |
| 6 | `PdfPrintRenderer` (après coup) + mutations ; `PdfFiles` (file_picker, web print) | data | tests de fumée, mutations |
| 7 | Cas d'usage, `app/sheet_export.dart`, menu du détail, options, aperçu, l10n, Widgetbook | app, presentation | BDD vert |
| 8 | `scripts/check.sh --full` ; `scripts/build_web.sh` (précache, `verify`) | tout | sorties vertes |
| 9 | Parcours web : export en ligne puis **serveur arrêté** (contexte hors ligne) ; PDF téléchargé relu par `pdftotext` (texte, ordre, absence de carré vide) et `pdftoppm` (schémas, gabarit superposé à `docs/sources/Fiches résultats…`) ; impression directe à la main | manuel | captures hors dépôt, notes dans la mémoire |
| 10 | Relecture par `architecte-fsd` et `testeur-bdd` dans un contexte séparé ; docs du § 9 à jour ; roadmap : lot 14 livré | docs | relectures consignées |

## 11. Hors périmètre (à rouvrir par un lot ou un ADR)

- Impression système sur mobile natif (`printing` : AirPrint, Android) : ADR à part.
- Dessin des illustrations qui ne sont pas des schémas de table (rastérisation
  ou dessin direct) : si U14-9 est contredit.
- Pré-remplir la fiche avec les passages déjà saisis ; saisir depuis le papier
  (photo, OCR) : hors lot.
- Export de la fiche élève ou du bilan de séance en PDF (données nominatives :
  ADR dédié).
- PDF balisé (accessibilité) : demande un autre moteur.
- Export depuis le guide « Mener » en cours de séance (entrée supplémentaire,
  même cas d'usage).

## 12. Livraison (2026-10-17)

### Écarts à la conception

Consignés dans l'[ADR 0021](adr/0021-export-pdf-feuille-animateur-et-fiche-resultats.md#écarts-à-la-livraison-2026-10-17).
En plus : le port `PdfFiles` est dans `features/export_sheet/domain` (posé d’abord dans `shared/lib`, déplacé après revue) ; le bouton
est sur le détail **et** dans le menu du guide ; **sur le web `file_picker`
déclenche un téléchargement et rend `null`**, exactement comme pour une annulation :
`FilePickerPdfFiles(savesByDownload: true)` tient alors le fichier pour enregistré
(constaté au parcours web : le message disait « Enregistrement annulé. » alors que le
fichier était téléchargé).

### Fichiers

- **Domaine** (`app/lib/features/export_sheet/domain/`) : `print_scene`, `text_measure`, `printable_text`,
  `text_wrap`, `diagram_scene`, `results_template`, `results_sheets_input`,
  `layout_results_sheets`, `sheet_print_input`, `print_labels`, `layout_animator_sheet`,
  `print_renderer`, `exported_document`, `export_source`, `export_animator_sheet`,
  `export_results_sheets`, `list_export_groups`.
- **Données** : `data/pdf_print_renderer.dart` (seul importeur de `pdf`).
- **Présentation** : `presentation/bloc/export_sheet_cubit.dart`, `ui/export_view`,
  `ui/print_preview_view`, `ui/print_scene_painter`, page `pages/export_sheet`.
- **Port et plateformes** : `features/export_sheet/domain/pdf_files.dart`, `app/platform/{file_picker_pdf_files,
  pdf_files_factory,pdf_files_native,pdf_files_web}.dart`, `app/di/pdf_files_module.dart`.
- **Jonction** : `app/sheet_export.dart`, route `AppRoutes.export`, boutons du détail et du guide
  (`SheetDetailPage.onExport`, `SheetGuidePage.onExport`, `RunSheetView.onExport`),
  `ResolveRunPlan(withRecallExercise: false)`.
- **Autres** : `InvariantCode.unprintableContent` (message `failUnprintableContent`), 81 clés ARB (fr = en),
  règle d'import dans `tool/architecture/architecture_rules.dart`, deux use cases et une page dans
  Widgetbook (`export_sheet_use_cases.dart`), `pubspec.yaml` (+ `pdf`), `pubspec.lock` (+ 7 paquets).
- **Tests** : deux `.feature` (21 scénarios), 20 steps, doubles `FakePdfFiles`, `FakePrintRenderer`,
  `FixedTextMeasure`, `FakeExportSource` ; tests unitaires sous `test/unit/features/export_sheet/`, `test/unit/app/`
  (`sheet_export_test`, `catalogue_export_test`, `platform/file_picker_pdf_files_test`), `test/unit/pages/export_sheet_page_test`.

### Rouges constatés (dits honnêtement)

- **Étape 0** : règle d'import (`architecture_rules_test`) : 4 cas rouges sur 5 avant le code (le cas « accepté dans
  `data` » passait d'emblée, par construction).
- **Étape 1, BDD** : 21 scénarios écrits avant le code, première exécution **20 rouges, 1 vert**. Les rouges le
  sont pour la bonne raison (`Found 0 widgets with text "Print / export as PDF"`). Le vert est le scénario
  « séance inconnue » : l'adresse d'export n'existait pas, le routeur affichait déjà « Page introuvable » ; il
  reste comme garde (il ne distingue pas l'absence de route de l'absence de séance, les deux pages sont les mêmes).
  Les steps qui lisent l'aperçu ont d'abord été écrits en accès dynamique par une clé (le code n'existait pas) puis
  typés une fois `PrintPreviewView` écrit.
- **TDD du domaine**, rouge constaté (fichier de code absent, donc erreur de compilation) puis vert : `printable_text`,
  `text_wrap`, `results_template`, `layout_results_sheets`, `diagram_scene`, `layout_animator_sheet`,
  `export_animator_sheet`, `export_results_sheets`, `list_export_groups`, `ResolveRunPlan(withRecallExercise:
  false)` (argument inconnu), `export_sheet_cubit` (14 comportements, dont « le dernier choix gagne »).
- Trois tests écrits trop faibles et durcis après mutation (voir ci-dessous) ; deux rouges de **conception**
  corrigés en cours de route : la case « Nb de billes empochées » s'arrêtait à 279,1 au lieu de 248,4 (mesure du
  PDF fédéral mal lue : 279,1 est le bord gauche du bloc voisin) ; les poches des schémas débordaient sur le texte.
- **Tests écrits après le code** (donc validés par mutation) : `pdf_print_renderer_test`,
  `print_scene_painter_test`, `file_picker_pdf_files_test`, tests d'interface (`export_view`, `print_preview_view`,
  `export_sheet_page`), `sheet_export_test` (jonction), `catalogue_export_test`.

### Mutations (appliquées à la main, une à la fois, suite du fichier relancée ; script jetable hors dépôt)

| Fichier muté | Mutants | Tués | Survivants et suite |
|---|---:|---:|---|
| `pdf_print_renderer.dart` | 15 | 15 | 1 survivant (alignement à droite) : test ajouté, tué |
| `file_picker_pdf_files.dart` | 10 | 10 | — (dont téléchargement web compté enregistré) |
| `export_sheet_cubit.dart` | 14 | 14 | — |
| `layout_animator_sheet.dart` | 21 | 21 | 2 survivants (titre orphelin, libellé gras) : le test d'orphelin ne regardait pas `step-minutes` ; balayage de remplissages ajouté, tués |
| `layout_results_sheets.dart` | 22 | 20 | 1 équivalent supprimé du code (l'arrondi à 4 des grilles n'était pas observable), 1 mutant mal formé (sans effet) ; `printable` non appliqué aux noms, séries, titre : tests ajoutés, tués |
| `diagram_scene.dart` | 20 | 20 | 2 survivants (étiquettes hors table, étiquette de flèche au départ) : tests ajoutés, tués |
| `text_wrap.dart` / `printable_text.dart` | 14 | 14 | 1 survivant (style ignoré) : test avec une mesure par style, tué |
| `export_results_sheets.dart` | 7 | 7 | 1 survivant (prénom non rogné) : test ajouté, tué |
| `print_scene_painter.dart` | 13 | 13 | 2 corrigés (fausse mutation, tolérance) puis tués |
| `export_view.dart`, `print_preview_view.dart`, `export_sheet_page.dart` | 25 | 25 | — |
| `sheet_export.dart` (jonction) | 21 | 21 | 1 survivant (provenance du jeu) : test « provenance de chaque étape » ajouté, tué |
| pages / vue du guide (`onExport`) | 5 | 5 | — |

### Résultat

- `scripts/check.sh --full` **vert** (format, analyse stricte, architecture, l10n 956 clés, tests BDD et unitaires,
  couverture lignes **98,4 %**, Widgetbook 141 widgets / 213 use cases). Aucun TODO, `skip`, `solo` ni stub ajouté.
- `scripts/build_web.sh` vert : 129 fichiers précachés (**les mêmes**, aucun asset ajouté), `main.dart.js`
  5 236 122 o (5 045 702 o avant le lot : +190 Ko pour tout le lot, dont `pdf` ≈ 77 Ko mesurés isolément).
- Catalogue entier (`catalogue_export_test`) : 28 séances × 2 publics × 2 langues, aucun caractère refusé ;
  **pages de la feuille de l'animateur** : 4 pages × 5 documents, 5 × 29, 6 × 20, 7 × 2 (sur 56) ; plus gros fichier 45 Ko.
  Deux documents à 7 pages dépassent la borne de 6 du risque 6 : à reconsidérer avec U14-12 (moins de texte) si l'animateur
  les trouve longs. `θ` devient « thêta » dans `finesse-1` et `trois-quarts-1` (points à vérifier).

### Parcours web (Chromium piloté par Playwright, build de production servi par `http.server`, captures hors dépôt)

1. Détail de `demi-bille-1` → « Imprimer / exporter en PDF » → page d'export, aperçu ; **Enregistrer** : fichier
   `seance-demi-bille-1-enfants.pdf` téléchargé, **4 pages A4, 29,5 Ko**, `pdffonts` : Exo2-Regular et Exo2-Italic
   **embarquées** ; `pdftotext -layout` relit le titre, le déroulé minuté (total 90), les consignes, les marques
   `[S]` / `[Prop]`, les sources ; aucun caractère de remplacement ; rendu `pdftoppm` relu à l'œil (schémas, étiquettes,
   pagination).
2. **Fiches résultats** : 4 pages (8 grilles × 2 exercices), titre « Fiches résultats : Quantité demi-bille », valeurs
   préremplies, « /6 » (taux « 4 sur 6 »), noms vides. Géométrie comparée au PDF fédéral par `pdftocairo -svg` : colonnes de
   la grille 85,8 / 118,3 / 150,8 / 183,3 / 215,8 / 248,3 contre 85,8 / 118,3 / 150,8 / 183,2 / 215,9 / 248,4 (≤ 0,5 pt) ;
   bandes de l'axe à moins de 1 pt (la fiche fédérale n'est pas parfaitement régulière : 14,4 puis 13,7).
3. **Prénoms** (profil neuf, trois élèves enfants) : groupe choisi, interrupteur, avertissement affiché, PDF de
   **2 pages** (4 prénoms, 1 page par exercice) avec « Éloïse », « Léa », « Zoé » **dans l'ordre alphabétique sans tenir
   compte des accents**. Constat de données : un groupe dont les membres commencent dans une saison **future** n'a aucun
   membre du jour : les grilles restent vierges sans message (cas du profil de test précédent).
4. **Hors ligne** : service worker actif (129 entrées en cache), **serveur arrêté**, rechargement de la page d'export
   (`?audience=adults`), enregistrement des **deux** documents : « PDF enregistré. », feuille de 4 pages « Adultes, 120 min,
   Total : 120 min », fiches de 4 pages, polices embarquées. Seule requête hors origine observée : le script Firebase
   (`gstatic.com/firebasejs`), **déjà là avant le lot** (initialisation non bloquante, ADR 0018), sans lien avec l'export.
5. **Téléphone** (390 × 844) : options, interrupteur et aperçu s'empilent sans défilement horizontal.
6. **Guide** : menu ⋮ → « Imprimer / exporter en PDF » ouvre la page d'export ; le retour ramène au guide.
7. Console : aucune erreur ni avertissement du lot.

### Limites et constats

- **Impression directe** (`window.print()` d'une iframe sur le PDF) : **non vérifiée** (la boîte d'impression ne se pilote pas) ; le
  bouton « Imprimer » est visible sur le web et masqué ailleurs. Safari iPhone et PWA installée sur Android : non vérifiés.
- PDF **non balisé** ; le texte est extractible dans l'ordre de lecture (vérifié par `pdftotext`).
- **Défaut hors du lot, à corriger** : `FilePickerBackupFiles.save` (sauvegarde JSON) a le même `location != null` ; sur le web
  `file_picker` rend `null` après le téléchargement, donc l'export de sauvegarde affiche « Export annulé. » et **n'enregistre
  pas la sauvegarde faite** (`RecordBackupDone`, rappel de sauvegarde). Constaté par lecture du paquet (`file_picker_web 4.1.0`,
  `saveFile` rend `null`) et par le PDF ; non vérifié sur la page de sauvegarde. Non corrigé ici (autre lot).
- Le médaillon de quantité de bille et la numérotation des tirs d'un schéma ne sont pas imprimés ; les illustrations qui ne sont
  pas des tables (silhouette, contact, dosage, angle) le sont en légende et texte alternatif (U14-9).
- Une séance dont le texte contiendrait un caractère absent d'Exo 2 serait **refusée** à l'export (message), pas imprimée avec un
  carré ; la garde du catalogue le vérifie aujourd'hui.
- Relecture par `architecte-fsd` et `testeur-bdd` dans un contexte séparé : **non faite** (l'exécuteur n'a pas d'outil
  de sous-agent) ; à lancer avant de conclure le lot (étape 10 du § 10).
