# Plan d'exécution : navigation recentrée (lot U6, volet 1)

Statut : **lot U6 livré le 2026-10-15** (volet navigation, puis rappel de
sauvegarde). Source : [ux/plan-ux-proposition.md](ux/plan-ux-proposition.md)
(lot U6, § 4) et [ux/recommandations-design.md](ux/recommandations-design.md) R6
et R12. Pas d'ADR : les cinq destinations restent celles de l'ADR 0004 ; seul le
contenu de deux d'entre elles change.

## Décisions

1. **Cinq destinations** : Aujourd'hui · Élèves · Résultats · Séances · Plus
   (en : Today · Students · Results · Sessions · More). « Plus » remplace
   « Sauvegarde » ; « Accueil » devient « Aujourd'hui » (libellé seul, l'écran
   est celui de U7).
2. **« Séances » à onglets** : Planifiées (`/planner`) · Catalogue
   (`/catalogue`) · Suggestion (`/session`). Les onglets sont rendus par
   `AppShell` au-dessus des seuls trois écrans de premier niveau ; les pages
   ouvertes depuis un onglet (séance du catalogue, fiche d'exercice) ne les
   affichent pas et restent sous la destination « Séances ». Les écrans, leurs
   adresses et leurs liens profonds sont inchangés.
3. **Atterrissage** : la destination « Séances » ouvre toujours le Catalogue
   (comportement existant, parcours et scénarios conservés). Le choix d'un
   atterrissage sur « Planifiées » relève de U8 ; U7 n'y touche pas (« Ouvrir
   dans Planifiées » de l'accueil mène à `/planner` ; depuis U8, « Préparer »
   mène au détail avec retour vers « Aujourd'hui », `?from=today`).
4. **« Plus »** : écran de liste (`/more`) qui mène à Sauvegarde (`/backup`,
   écran existant, avec retour à « Plus »). `/backup` sélectionne « Plus ».
5. **Composant** : `AppTabs` (`shared/ui/app_tabs.dart`), sans dépendance
   métier : boutons de 48 dp minimum, sémantique « sélectionné » dans un groupe
   exclusif, étiquette de groupe.

## Routes ajoutées par U9 (2026-10-16)

- `/students/groups/:groupId` : grille du groupe, **dans** le cadre de
  navigation (destination « Élèves » active) ; ouverte par « Grille du groupe »
  sur chaque carte de groupe de « Élèves » et par une alerte de groupe de
  « Aujourd'hui » ; retour vers `/students`.
- `/students/:studentId/show` : vue « à montrer à l'élève », **hors** du cadre
  (comme la présentation plein écran) : aucune barre ni rail, donc aucun chemin
  vers les autres élèves ; « Terminer » et le retour système reviennent à la
  fiche. Voir l'[ADR 0014](adr/0014-fiche-en-parcours-vue-eleve-et-vue-de-groupe.md).

## Reports (documentés, rien de stubbé)

- ~~**Réglages**~~ : **livré avec le lot 9** (2026-10-15, [plan](reglages-plan.md)) :
  l'entrée « Réglages » de « Plus » mène à `/settings` (retour « Retour à
  Plus ») ; « Plus » contient Sauvegarde et Réglages.
- **À propos et sources** : aucun contenu à y mettre aujourd'hui ; reporté.
- ~~**Bouton « Suggestion par groupe »** du catalogue~~ : **retiré par U8**
  (2026-10-16) ; l'onglet « Suggestion » de « Séances » est l'unique accès, les
  20 scénarios qui passaient par le bouton tapent désormais l'onglet.
- **Origine du détail d'une séance** (U8) : `?from=` prend `planner` (retour à
  « Planifiées »), `today` (retour à « Aujourd'hui ») ou rien (retour au
  catalogue, avec `?group=` restauré). Le choix d'un atterrissage de « Séances »
  sur « Planifiées » reste ouvert.
- ~~**« Lancer » et le guide**~~ (décision U-9) : **soldé par U4**
  ([ADR 0015](adr/0015-guide-mener-route-modes-origine.md), [plan](guide-mener-plan.md)).
  Le guide est une route de **premier niveau**, hors du `ShellRoute` : plus de
  rail ni de barre en séance (la présentation, la vue élève et le guide sont les
  trois écrans hors cadre). `?from=` (`planner`, `today`, `suggestion`) est
  l'origine directe du lancement, `?via=` l'origine du détail quand le guide en
  vient, `?group=` traverse catalogue → détail → guide → présentation → saisie ;
  la fonction pure `guideBackTarget` décide du retour : « Lancer » et « Reprendre »
  depuis Aujourd'hui reviennent à Aujourd'hui, depuis Planifiées à Planifiées,
  depuis la Suggestion à la Suggestion, depuis le détail au détail (avec son
  origine et son groupe), puis au catalogue avec le groupe choisi. « Planifier
  cette séance » du détail emporte le groupe. Une valeur d'origine inconnue
  retombe sur le détail sans origine. La flèche du guide ne termine pas la
  séance (reprise depuis Aujourd'hui).

## Rappel de sauvegarde (volet 2)

- **Persistance** : la date de dernière sauvegarde n'existait pas. Ajout du
  port `BackupMarkerRepository` (date de l'export + nombre de passages du club
  à cet instant), table drift `backup_exports` (schéma v6, migration
  `from5To6`), contrat commun in-memory et drift. Le marqueur est écrit par
  `BackupBloc` quand le fichier est réellement enregistré (export annulé :
  rien). Donnée locale à l'appareil, hors fichier de sauvegarde ; un import ne
  la modifie pas.
- **Règle** (`BackupReminder.evaluate`, domain pur) : aucun rappel tant qu'aucun
  passage n'est saisi ; sinon, par priorité, sauvegarde de 30 jours révolus ou
  plus, puis passages saisis depuis la dernière sauvegarde (compte actuel moins
  compte à l'export, jamais négatif), puis « jamais sauvegardé ».
- **Passages « depuis »** : comparés par nombre et non par date, car la date
  d'un passage est celle de la séance, pas celle de la saisie. Limite assumée :
  supprimer N passages puis en saisir N après une sauvegarde ne déclenche aucun
  rappel (différence de comptes).
- **Retour depuis Sauvegarde** : le bouton « Retour à Plus » ramène toujours à
  `/more`, y compris quand la sauvegarde est ouverte depuis le bandeau de
  « Aujourd'hui » (choix simple, un paramètre d'origine serait un ajout U7).
- **Interface** : `BackupReminderBanner` (`AppAlert` attention + action
  « Sauvegarder » vers `/backup`), posé sur l'accueil par le routeur via le
  paramètre `banner` de `HomePage` ; U7 a refondu l'accueil et conservé le
  bandeau au-dessus des cartes (scénario « The backup reminder is kept above the
  cards »). Évalué à chaque ouverture de « Aujourd'hui ».
- **Reporté** : rappel natif (notification) en H4, désactivable (Q7). Le seuil
  de 30 jours est réglable depuis le lot 9 (« Réglages », 7 à 90 jours).

## Fichiers par couche

| Couche | Fichiers |
|--------|----------|
| shared | `shared/ui/app_tabs.dart`, ARB fr/en (`navMore`, `navHome`, `sessionsTab*`, `more*`, `backupBackToMore`) |
| pages | `pages/more/presentation/more_page.dart` ; `pages/backup` (retour à « Plus ») |
| app | `app/shell.dart` (`indexOf`, `sessionsTabOf`, onglets), `app/router.dart` (`AppRoutes.more`, route `/more`) |
| tests | `test/bdd/navigation.feature`, `backup_screen.feature`, `test/unit/app/shell_routes_test.dart`, `shared/ui/app_tabs_test.dart`, `pages/more_page_test.dart`, steps `the_navigation_destinations_are`, `the_destination_is_selected`, `the_sessions_tab(s)_*`, `i_do_not_see_the_sessions_tabs` |
| backup_data | `domain/backup_marker*.dart`, `backup_reminder.dart`, `check_backup_reminder.dart`, `record_backup_done.dart` ; `data/drift_` et `in_memory_backup_marker_repository.dart` ; `presentation/bloc/backup_reminder_cubit.dart`, `ui/backup_reminder_banner.dart` |
| persistance | `shared/persistence/tables.dart` (`BackupExports`), `app_database.dart` (v6), `drift_schemas/…/drift_schema_v6.json` |
| tests | `test/bdd/backup_reminder.feature` (7 scénarios), `unit/features/backup_data/domain/backup_reminder_test.dart`, `presentation/backup_reminder_*_test.dart`, `contract/backup_marker_contract.dart`, migration v6 |
| widgetbook | `app_tabs_use_cases.dart`, use case « Plus » |

## Reports réalisés par U7

- **Accueil « Aujourd'hui »** : composition de quatre sections indépendantes
  (en cours, prochaine séance et à noter, à surveiller, 7 derniers jours) ;
  adresses inchangées.
- **Bilan** : nouvelle route `/record/:sessionId/review` (`AppRoutes.review`),
  dans le shell, sélectionne « Résultats ». « Terminer » mène au bilan quand une
  saisie a été ouverte depuis le guide, sinon retour inchangé.
- **« Retour à Plus » depuis la sauvegarde** : inchangé (non demandé).
