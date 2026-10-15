# Plan d'exécution : Réglages (lot 9, F8)

Statut : **livré le 2026-10-15** (domaine et persistance, puis écran `/settings` sous « Plus »). Sources : [roadmap](roadmap.md)
(F8, lot 9), [navigation-plan](navigation-plan.md) (reports U6), ADR 0001
(schéma v6), ADR 0003 (défauts), ADR 0010 (rôles de couleur) et
[ADR 0012](adr/0012-reglages-du-club.md) (décisions structurantes de ce lot).

## Constats sur le code

- `RulesConfig` (`shared/lib/rules_config.dart`) : `@lazySingleton` constant,
  invariants dans le constructeur (`InvariantViolation(invalidRules)`), 14 cas
  d'usage le reçoivent par constructeur ; tous sont des **fabriques** get_it.
- Le routeur utilise un `ShellRoute` et `context.go` : les blocs d'un écran sont
  recréés à chaque navigation. Un réglage modifié est donc vu par tout écran
  ouvert ensuite, à condition que `RulesConfig` soit résolu à la valeur courante.
- `alertThreshold` doit rester `<= persistentAlertThreshold` (5, non exposé) :
  l'écran borne `alertThreshold` à 1..5, la valeur 5 restant atteignable.
- `BackupReminder.staleAfterDays = 30` est une constante statique ; la sauvegarde
  JSON (`BackupCodec.currentVersion = 1`) ne connaît que `data.*` strict.

## Décisions

1. **Modèle et slice FSD.** Nouvelle entité `entities/settings`
   (`ClubSettings`, 5 entiers ; `ClubSettings.defaults`, `applyTo(RulesConfig)`,
   `fromRules`). Aucune validation propre : `applyTo` laisse le constructeur de
   `RulesConfig` trancher. Port `SettingsRepository` (`load()` → toujours un
   `ClubSettings`, défauts si rien ; `save`, `reset`). Nouvelle feature
   `features/manage_settings` (cas d'usage, bloc, formulaire) ; page
   `pages/settings`. `backup_data` importe `entities/settings` (vers le bas).
2. **Paramètres exposés** (bornes d'écran, sous-ensemble des invariants) :
   `passesRequired` 1..10 (défaut 5) ; `alertThreshold` 1..5 (3) ;
   `recallStaleSessions` 1..12 (4) ; `groupFailureSharePercent` 10..100 par pas de
   10 (50) ; `backupReminderDays` 7..90 (30). `backupReminderDays` est ajouté à
   `RulesConfig` (`@Default(30)`, invariant 1..365) : une seule source de
   validation et de défauts. Rien d'autre n'est exposé.
3. **`RulesConfig` à la valeur courante** (voir ADR 0012, § 3) : approche la
   plus simple, sans changer les 14 cas d'usage.
   - `shared/lib/rules_config.dart` : retirer `@lazySingleton` et `@factoryMethod`,
     ajouter `backupReminderDays` (régénérer freezed).
   - `shared/lib/rules_store.dart` (nouveau, Dart pur) : `RulesStore`
     (`current`, `replace`).
   - `app/di/rules_module.dart` (nouveau) : `@preResolve @singleton
     Future<RulesStore>` lit `SettingsRepository.load()` puis `applyTo(RulesConfig())` ;
     `@injectable RulesConfig rulesConfig(RulesStore)` (fabrique).
   - `app/di/injection.config.dart` régénéré (build_runner), jamais à la main.
   - Test d'architecture : `RulesConfig` n'apparaît dans aucune classe
     `@singleton` / `@lazySingleton` ; commentaire sur `RulesConfig` : « ne pas
     conserver à travers un changement de réglage ».
4. **Schéma drift v7.** Table `AppSettings` (`app_settings` : `id` entier PK
   fixé à 1, `passes_required`, `alert_threshold`, `recall_stale_sessions`,
   `group_failure_share_percent`, `backup_reminder_days` entiers NOT NULL,
   `updated_at` ISO 8601). Pas de `seq`, UUID ni suppression logique (donnée de
   configuration, comme `backup_exports`). `from6To7` : `m.createTable(schema.appSettings)`,
   additive. `currentSchemaVersion = 7`, puis `dart run drift_dev make-migrations`
   (instantané `drift_schema_v7.json`, `app_database.steps.dart`, helpers de
   test ; **supprimer le stub** `test/drift/app_database/migration_test.dart`).
   `DriftSettingsRepository` (env `prod`) et `InMemorySettingsRepository`
   (env `test`).
5. **Sauvegarde.** `BackupSnapshot.settings` (`ClubSettings?`, défaut `null`) ;
   `BackupEncoder` écrit `data.settings` ; `BackupDecoder` le lit (clé
   facultative, 5 entiers exigés si présente, validation par `applyTo`) ;
   `BackupCodec.currentVersion = 2`, `supportedVersions = {1, 2}` ;
   `ExportBackup` charge les réglages ; `ImportBackup` appelle
   `SettingsRepository.save` dans la `UnitOfWork` puis, **après** succès de la
   transaction, `RulesStore.replace` (aucune valeur courante changée si l'import
   échoue). `ImportSummary`/aperçu : indicateur « réglages inclus ». Fichier
   sans réglages : réglages inchangés (installation neuve : défauts).
6. **Interaction avec `BackupReminder`.** `evaluate(…, staleAfterDays)` ;
   `CheckBackupReminder` reçoit `RulesConfig` et passe `backupReminderDays`.
   La bannière affiche toujours les jours réels (`StaleBackup(days)`).
   Changer le délai prend effet à la prochaine ouverture d'« Aujourd'hui ».
7. **Écran** `/settings`, sous « Plus » (`AppShell.indexOf` : `/settings` → 4 ;
   `MorePage.onOpenSettings` ; retour « Retour à Plus » comme Sauvegarde).
   `ScrollPage`, un `SectionCard` par thème (Validation des exercices ; Alertes
   et rappels ; Sauvegarde), `CounterField` (cibles ≥ 48 dp, info-bulles) avec un
   paramètre `step` ajouté pour la part d'échec (pas de 10). Une phrase fixe
   sous le titre : « Modifier un réglage ne change pas les passages déjà saisis :
   il change ce qui est validé et les alertes. » Boutons « Enregistrer »
   (activé si modifié) et « Rétablir les valeurs par défaut »
   (`showConfirmDialog`). Couleurs : états en bleu-tapis (`secondary`), aucun
   rouge comme état ; « Enregistrer » bouton plein standard. États du bloc :
   `loading`, `editing(draft, saved)` (modifié = draft ≠ saved), `saving`,
   `saved` (message d'état persistant, pas de snackbar seul), `failed(code)`
   (message de `failure_message.dart`, `invalidRules` → texte dédié, brouillon
   conservé, rien d'écrit). Sémantique : chaque compteur est un groupe étiqueté
   avec valeur et plage ; message d'état en région `liveRegion`.
8. **Défaut par rapport au fait.** `ResetSettings` supprime la ligne et remet
   `RulesStore` aux défauts ; les passages ne sont pas touchés.

## Fichiers à créer / modifier par couche

| Couche | Créer | Modifier |
|--------|-------|----------|
| shared | `lib/rules_store.dart` ; `persistence/` table `AppSettings` dans `tables.dart` | `lib/rules_config.dart` (+ `.freezed.dart` régénéré), `persistence/app_database.dart` (v7, `from6To7`, `tables`), `ui/counter_field.dart` (`step`), `ui/failure_message.dart`, ARB fr/en |
| entities | `settings/domain/club_settings.dart`, `settings_repository.dart` ; `settings/data/drift_settings_repository.dart`, `in_memory_settings_repository.dart` | aucune autre entité |
| features | `manage_settings/domain/` (`load_settings`, `save_settings`, `reset_settings`) ; `manage_settings/presentation/bloc/` (`settings_bloc`, `_event`, `_state`) et `ui/settings_form.dart` | `backup_data/domain/` : `backup_reminder.dart`, `check_backup_reminder.dart`, `backup_snapshot.dart`, `backup_encoder.dart`, `backup_decoder.dart`, `backup_codec.dart`, `export_backup.dart`, `import_backup.dart`, `import_summary.dart` ; `backup_data/presentation` (aperçu « réglages inclus ») |
| pages | `pages/settings/presentation/settings_page.dart` | `pages/more/presentation/more_page.dart` (entrée « Réglages ») |
| app | `app/di/rules_module.dart` | `app/router.dart` (`AppRoutes.settings`, route, retour), `app/shell.dart` (`indexOf`), `app/di/injection.config.dart` (régénéré) |
| docs | `adr/0012-…` (fait) | `adr/README.md` (fait), `roadmap.md` (lot 9, F8), `architecture.md`, `design-system.md`, `navigation-plan.md` (report levé), ADR 0001 (schéma v7, sauvegarde v2), ADR 0003 (renvoi) |
| widgetbook | use case de l'écran Réglages, `CounterField` avec pas | |
| tests | voir ci-dessous | `test/unit/features/backup_data/domain/backup_reminder_test.dart` (paramètre), `test/unit/shared/lib/rules_config_test.dart` (`backupReminderDays`), `test/unit/shared/persistence/migration_test.dart`, `test/contract/backup_contract.dart` |

## Lots d'implémentation (ordre)

1. **Domaine et persistance** (BDD rouge : `settings.feature` scénarios 1 à 3
   et `backup_reminder.feature` scénario « délai réglé », vus rouges avant tout
   code) : `RulesConfig.backupReminderDays` ; `ClubSettings` ; port, in-memory,
   drift, table, schéma v7, migration, contrat commun ; `RulesStore` et
   `rules_module.dart` ; `BackupReminder`/`CheckBackupReminder` paramétrés ;
   régénérations (build_runner, make-migrations). Vert : unitaires + contrat +
   migration.
2. **Sauvegarde v2** : snapshot, encodeur, décodeur, codec, export/import,
   résumé ; scénarios de `data_backup.feature`. Vert : aller-retour, fichier v1,
   refus sans écriture, atomicité.
3. **Cas d'usage et bloc** : `LoadSettings`, `SaveSettings` (valide, écrit,
   puis remplace la valeur courante), `ResetSettings`, `SettingsBloc`.
4. **Écran et navigation** : formulaire, page, route, entrée sous « Plus »,
   `step` de `CounterField`, ARB fr/en + `flutter gen-l10n`, Widgetbook,
   scénarios de navigation et de l'écran ; docs ; `scripts/check.sh --full`.

## Scénarios BDD à écrire d'abord

`test/bdd/settings.feature` (nouveau) :

1. Les valeurs par défaut sont affichées sur une installation neuve
   (5 exercices réussis, alerte à 3, rappel après 4 séances, part d'échec 50 %,
   rappel de sauvegarde 30 jours).
2. Modifier le nombre de passages requis puis enregistrer le persiste (après
   réouverture de l'écran).
3. Un exercice à 3 passages réussis devient validé quand le nombre requis passe
   de 5 à 3, sans modifier les passages saisis.
4. Relever le seuil d'alerte retire l'alerte d'un élève à 3 échecs consécutifs.
5. Les compteurs ne dépassent pas leurs bornes (le bouton « plus » est
   désactivé au maximum, « moins » au minimum).
6. Une configuration refusée par le domaine affiche un message et n'écrit rien
   (en pratique : `persistentAlertThreshold` abaissé à 3 en test, règle réelle
   de `RulesConfig` ; aucune bascule hors bornes n'a été ajoutée).
7. « Rétablir les valeurs par défaut » demande confirmation ; annuler ne change
   rien.
8. Confirmer rétablit les défauts et conserve les passages saisis.
9. L'écran dit en une phrase que les passages saisis ne sont pas modifiés.
10. Quitter avec des modifications non enregistrées les abandonne (le
    brouillon n'est pas appliqué).

`test/bdd/navigation.feature` (ajout, scénario U6 reporté) :

11. « Plus » contient Sauvegarde et Réglages ; Réglages ouvre l'écran et garde
    « Plus » sélectionné.
12. Depuis Réglages, « Retour à Plus » ramène à « Plus ».

`test/bdd/backup_reminder.feature` (ajout) :

13. Le rappel de sauvegarde suit le délai réglé (délai 7 jours, dernière
    sauvegarde il y a 8 jours : rappel « ancienne » ; délai 30 : aucun).

`test/bdd/data_backup.feature` (ajout) :

14. La sauvegarde exportée contient les réglages.
15. Importer une sauvegarde restaure les réglages.
16. Importer un fichier sans réglages (format 1) conserve les données et laisse
    les réglages inchangés.
17. Un fichier dont un réglage est hors bornes est refusé sans aucune écriture
    (données et réglages intacts).

Unitaires/contrat associés : `ClubSettings.applyTo` (valide, chaque borne,
`persistentAlertThreshold`), `SaveSettings` (invalide : aucune écriture, valeur
courante inchangée), contrat `SettingsRepository` in-memory et drift
(`load` défauts, `save`, remplacement, `reset`), migration v6 → v7 (base v6
migrée sans réglage, lecture = défauts), test d'architecture « RulesConfig
jamais dans un singleton », `BackupCodec` v1 et v2.

## Risques

- **Valeur figée dans un objet à longue durée de vie** : un bloc ou cas d'usage
  conservé à travers la sauvegarde d'un réglage verrait l'ancienne valeur.
  Atténué par `ShellRoute` + `go`, le test d'architecture, et le scénario 3
  (réouverture d'un écran dérivé) ; à revérifier si un écran passe en `push`.
- **Import et valeur courante** : `RulesStore.replace` doit suivre le succès de
  la transaction, sinon une transaction annulée laisserait la mémoire changée.
- **Import d'un fichier sans réglages** : la consigne parle d'« importer avec
  les défauts » ; choix retenu (réglages inchangés) pour ne pas écraser les
  réglages de l'animateur par un vieux fichier. À confirmer `[U]`.
- **Fichier v2 sur ancienne application** : refusé (`backupVersionUnsupported`),
  voulu, mais l'animateur doit mettre l'application à jour.
- **Validation dispersée** : toute nouvelle borne doit aller dans `RulesConfig`,
  jamais dans l'écran ; les bornes d'écran sont un sous-ensemble testé contre
  le constructeur (un test balaie chaque borne min/max de l'écran).
- **Rétroactivité** : baisser `passesRequired` valide d'un coup des exercices ;
  relever le rétablit à « en cours ». Aucune donnée perdue, mais l'élève peut
  voir son suivi changer : d'où la phrase et le « Rétablir ».
- **Régénérations** : freezed (`RulesConfig`, snapshot), injectable, drift
  (instantané v7, stub de test à supprimer), gen-l10n ; ne jamais éditer à la
  main (pièges en mémoire).
- **Brouillon abandonné sans confirmation** (scénario 10) : choix de simplicité ;
  une confirmation de sortie reste possible si le terrain le demande.
- Aucun nouvel ajout de texte côté connaissances : `docs/knowledge` non touché.
