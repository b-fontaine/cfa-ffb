# ADR 0014 — Fiche en parcours, vue « à montrer à l'élève » et vue de groupe

- Statut : **accepté (livré, 2026-10-16)**, seconde moitié du lot U9 (écrans). Le lot 10b (note de jeu,
  compteurs persistés, étape de séance persistée) est **reporté**, hors de cette livraison. Conception :
  [../fiche-eleve-plan.md](../fiche-eleve-plan.md) (D1 à D5, D7). S'appuie sur l'[ADR 0013](0013-acquittement-des-alertes.md)
  (acquittement), l'[ADR 0008](0008-positionnement-initial-bloc-acquis.md) (bloc acquis, état distinct), l'[ADR
  0010](0010-roles-de-couleur-bleu-tapis-et-accent.md) (bleu-tapis, jamais de rouge d'état) et la décision Q6 du
  2026-10-14 (vue élève : prénom et parcours seulement).
- Contexte : la fiche d'un élève empilait un compteur « 0 sur 70 », une liste de 15 blocs avec barre et
  pourcentage, les courbes de tous les exercices et des actions de positionnement répétées 15 fois ; le groupe
  n'avait aucune vue d'ensemble. Le domaine (cases, en-tête, vue élève, grille, assiduité et alertes de groupe,
  acquittement) est livré avec la première moitié du lot ; cet ADR fixe ce que les écrans en font.

## Décision

1. **Fiche en parcours** : la fiche se lit de haut en bas — bouton « Montrer à l'élève », audience, **en-tête**
   (techniques terminées, exercices validés, exercice en cours avec ses réussites, prochain, alerte la plus
   grave avec « Vu » ou ligne calme « Alerte vue le … » avec « Rétablir »), notion à rappeler, assiduité,
   **parcours** (une ligne par technique, une case par exercice), **courbes repliées**, puis les actions rares
   (modifier le prénom, bilan de maturité, effacer). `BlockProgressList` disparaît ; `PathList` le remplace.
2. **Quatre états de case, une forme chacun** (`PathCell`, `shared/ui`) : à faire (contour vide), commencé
   (hachuré, avec le nombre de réussites), validé (plein, coche), issu du positionnement (plein clair, drapeau).
   Une alerte active ajoute une icône d'attention (jamais rouge), l'exercice en cours un anneau. Chaque case est
   un bouton de 48 × 48 dp dont le **nom accessible** dit l'état (« exercice : commencé, 2 réussites sur 5,
   alerte en cours, exercice en cours ») ; toucher une case ouvre une **feuille basse** avec la courbe de
   l'exercice (ou « Pas encore pratiqué »). La légende écrit les quatre états et le total d'exercices du
   catalogue (jamais codé en dur).
3. **Pas de « 0 sur 70 »** : « Parcours à commencer » tant qu'aucun passage n'est saisi et rien d'acquis ; dès
   qu'un élève a pratiqué sans rien valider, l'en-tête écrit les faits (« 0 sur 15 techniques terminées »,
   « 0 exercice validé »). La liste des élèves suit la même règle (`StudentSummary.toStart` : « Parcours à
   commencer » ou « n exercices validés », plus de « n sur 70 »). `SheetHeader.toStart` vaut donc « aucun passage et rien d'acquis » (le plan disait
   « rien de validé ni d'acquis », qui annonçait « à commencer » à un élève qui avait déjà échoué trois fois).
4. **Une ligne de technique écrit peu** : titre (badge `[Prop]`), fraction « 3/4 » (le résumé complet « 3 sur 4
   exercices · 1 séance » est lu par la sémantique), et un statut écrit **seulement s'il dit plus que
   « commencé ou non »** (maîtrisé, acquis au positionnement, à revoir, plus de séances que conseillé) : les
   cases et la fraction portent le reste. Les actions de positionnement vivent dans un **menu ⋮** (48 dp) placé
   après les cases, de nom « Positionnement : <technique> », absent d'une technique maîtrisée par passages.
5. **Vue « à montrer à l'élève »** : route `/students/:studentId/show` **hors du cadre de navigation** (comme
   la présentation plein écran) : ni barre ni rail, donc aucun chemin vers les autres élèves. Le contenu est
   celui du modèle `StudentShowcase`, qui n'a **aucun champ** pour une alerte, une note, un bilan, l'assiduité,
   une date ou un autre élève ; une technique « à revoir » se montre « en cours » ; les pastilles ne comptent
   que les réussites ; les cases ne répondent à aucun toucher. « Terminer » et le retour système reviennent à
   la fiche (`PopScope`). Un test interdit à la slice `student_showcase` d'importer les slices sensibles.
   Chaque case porte ses seules réussites (`ShowcaseCell.passed`), ajoutées au modèle pour que le nom
   accessible dise « commencé, 2 réussites sur 5 ».
6. **Vue de groupe** : route `/students/groups/:groupId` **dans** le cadre (destination « Élèves » active),
   ouverte par le bouton « Grille du groupe » de chaque carte de groupe qui a des membres. Elle empile les
   alertes de groupe (« 4 élèves sur 8 ont manqué « X » à leur dernier passage », ton attention), l'assiduité du
   groupe (« 41 présences sur 48 possibles (85 %) », nombre de séances, cinq dernières séances ; « Aucune
   séance saisie pour le moment » plutôt que 0 %), la **carte de chaleur** et son résumé en texte. Les alertes
   de groupe figurent aussi sur « Aujourd'hui » (trois au plus, « + n autres alertes de groupe », une ligne
   ouvre la grille) ; la section est absente sans alerte.
7. **Carte de chaleur et alternative textuelle** (`CellGrid`, `HeatCell`, `shared/ui`) : lignes = techniques,
   colonnes = élèves membres du jour, dernière ligne = assiduité de chaque élève. La colonne des techniques
   reste fixe et les élèves défilent à l'horizontale (smartphone). Une cellule fait 56 dp, écrit toujours sa
   fraction, teinte son fond en quatre paliers de bleu-tapis et ajoute une coche (technique terminée), un
   drapeau (acquise) ou une icône d'attention (alerte) : **la couleur ne porte jamais seule le sens**. Quatre
   alternatives, toutes livrées : (a) nom accessible complet par cellule (« Léa, Demi-bille : 3 sur 4
   exercices, En cours, alerte en cours ») ; (b) résumé par ligne (« Demi-bille : 5 élèves sur 8 ont terminé, 2
   en cours, 1 à commencer ») ; (c) section « Résumé en texte », **repliable et visible** (repliée par défaut),
   qui liste les prénoms par état ; (d) une légende écrite des symboles. Le tableau n'utilise **pas** les rôles
   sémantiques `table` / `row` / `cell` de Flutter : la grille est coupée en une colonne fixe et une zone qui
   défile, ce qui ne forme pas la hiérarchie exigée ; c'est le nom complet de chaque cellule (ligne et colonne)
   qui joue ce rôle. Toucher une cellule ou un prénom ouvre la fiche de l'élève ; la grille ne permet aucune
   écriture.
8. **Acquittement** : le bouton « Vu » et « Rétablir » sont des callbacks fournis par la page, qui compose
   `AcknowledgementBloc` (`MultiBlocListener` avec le positionnement) : retour par `SnackBar` (« Alerte
   marquée comme vue. », « Alerte rétablie. », ou le motif du refus) et rechargement de la fiche dans les deux
   cas. Le rappel de notion n'est pas rechargé (l'acquittement ne le change pas, ADR 0013).
9. **Hauteur et sobriété** : le parcours de 15 techniques et 70 cases fait **≈ 1 770 dp de haut à 390 dp de
   large** (mesuré par un test jetable, catalogue réel). Le plan visait ≈ 1 100 dp ; ce chiffre est
   inatteignable avec des cases de 48 dp : 70 cases à six par ligne occupent déjà ≈ 900 dp, avant les 15
   titres. La réduction vient de la suppression des barres et pourcentages, du statut écrit seulement quand
   il informe, et du menu rangé à la suite des cases. Le repli prévu (techniques terminées repliées) n'est pas
   livré : il aurait masqué les cases « acquis » que les scénarios exigent. **Écart accepté par l'animateur
   (2026-10-16).** La règle « à commencer » (aucun passage et rien d'acquis) est aussi validée.
10. **Vue élève sans badge « Proposition »** (U9-9, tranché le 2026-10-16) : `ShowcaseRow` n'a plus de champ de
    provenance, la vue n'affiche aucun badge « Proposition » et le nom accessible d'une case n'en porte pas.
    La règle « une proposition est toujours signalée » vaut pour les écrans de l'animateur (séances, fiche,
    saisie) ; la vue élève est « à montrer » et ne présente aucune règle fédérale. Ni `AGENTS.md` ni
    `docs/knowledge/00-provenance-et-fiabilite.md` n'imposent le badge dans cette vue (le second dit de ne
    jamais présenter une proposition comme une règle fédérale, ce que la vue ne fait pas).

## Alternatives écartées

- **Onglet « Groupes » dans la navigation** : cinq destinations déjà (ADR de la navigation, lot U6) ; un
  bouton par carte de groupe suffit et garde « Élèves » comme seule porte (U9-8).
- **Masquer la vue élève par un code** : un code à saisir gêne la salle et ne protège pas mieux qu'une route
  sans chemin sortant ; la garantie est le type du modèle (U9-9, décision 10 pour la provenance).
- **Tableau sémantique natif** pour la carte de chaleur : voir décision 7.
- **Statut écrit sur chaque ligne** : 15 pastilles « Non commencé » répétées n'informent pas (la première
  version, avec ces pastilles, une ligne de résumé et un menu sur sa propre ligne, mesurait ≈ 2 640 dp au lieu
  de ≈ 1 770 dp).

## Conséquences

- Les scénarios qui lisaient « n sur 70 exercices validés », « 25 % validé » ou un bouton de positionnement
  visible sont réécrits (fraction « 3/4 », « n exercices validés », menu ⋮) ; les courbes se lisent après un
  toucher sur « Courbes de performance » ou sur une case.
- `ListGroupAlerts` et `GetGroupOverview` lisent les passages de tout le club : acceptable à l'échelle d'un
  club (quelques dizaines d'élèves) ; à revoir si l'on ajoute la synchronisation (ADR 0001).
- Ce qui reste ouvert et reporté est nommé dans la [roadmap](../roadmap.md) (lot 10b) : note de jeu,
  compteurs d'initiation et de jeu persistés, étape de la séance en cours.
