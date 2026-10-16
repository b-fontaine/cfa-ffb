# ADR 0015 — Guide en mode « Mener » : route de premier niveau, modes, origine

- Statut : **accepté** (2026-10-16), lot U4. Livré le 2026-10-16, parcours web fait (voir
  [../roadmap.md](../roadmap.md)). Conception : [../guide-mener-plan.md](../guide-mener-plan.md). S'appuie sur l'[ADR
  0004](0004-catalogue-fiches-seances.md) (séance guidée), l'[ADR 0007](0007-lien-seance-planifiee-saisie-catalogue.md)
  (séance planifiée, groupe), l'[ADR 0010](0010-roles-de-couleur-bleu-tapis-et-accent.md) (jamais de rouge d'état) et
  la décision Q4 du 2026-10-14 (le guide lancé sans séance planifiée s'ouvre en « Relecture »).
- Contexte : le guide était une page du cadre de navigation, avec un en-tête de ~45 % de l'écran (titre, public, thème,
  barre d'étape, minuteur, boutons) : le schéma d'un exercice était la septième information et le rail ou la barre de
  navigation restaient visibles en séance. Le retour du guide ignorait d'où il avait été lancé (Aujourd'hui revenait à
  Planifiées, le détail perdait son groupe : report U-9 des lots U8 et U7).

## Décision

1. **Le guide est une route de premier niveau**, comme la présentation (`/catalogue/:sheetId/guide`, hors du
   `ShellRoute`) : ni rail ni barre en séance. L'adresse et les liens profonds ne changent pas. Le cubit vit dans
   `RunSheetSessions`, pas dans la route : changer de parent ne détruit rien, la reprise depuis Aujourd'hui, la
   présentation et la feuille de saisie fonctionnent comme avant. La flèche de l'en-tête **ne termine pas** la séance
   (le minuteur est mis en pause) ; « Terminer » (confirmé, par le menu ou par l'action de la dernière étape) est la
   seule sortie qui libère le cubit et mène au bilan quand une saisie a été ouverte.
2. **Deux modes, état du cubit reflété dans l'adresse** : `RunMode { lead, review }` (domaine pur,
   `features/run_sheet/domain/run_mode.dart`). Défaut `RunMode.defaultFor(planned:)` : séance planifiée → **Mener**,
   sinon → **Relecture** (Q4) ; la séance suggérée impose `mode=lead` (le groupe et les élèves sont déjà choisis,
   `[U4-1]`). Le mode est dans `RunSheetState.mode` et dans l'adresse (`?mode=`) **seulement quand il diffère du défaut**
   de la clé ; `syncFromRoute` n'applique un mode que s'il est présent et `modeChanged` est idempotent (pas de boucle
   avec `context.go`). En **Mener** : badges de provenance masqués, sections « pour aller plus loin » repliées ; en
   **Relecture** : badges affichés, tout déplié, tuile du thème en fin d'étape. Le mode n'est ni mémorisé dans les
   Réglages ni compté dans la progression.
3. **La provenance ne disparaît jamais**. Les données gardent `Provenance.prop` (`RunPlan.isProposal`,
   `proposalCountOf`). En Mener, chaque élément `[Prop]` reste annoncé aux lecteurs d'écran par un nœud sémantique
   « Proposition » sans rendu, le nombre de propositions de l'étape est dit dans la feuille « La séance » (menu ⋮) et la
   Relecture est à un geste du menu. La présentation aux élèves n'a pas de mode (son badge d'illustration est inchangé).
4. **Écran recomposé** (`features/run_sheet/presentation/ui`) : `StepAppBar` (retour, titre de l'étape une seule fois,
   position, menu ⋮ : Sommaire, Mode relecture (case), La séance, Minuteur à zéro, Terminer la séance), `PhaseTimeline`
   (un tap saute à la première étape de la phase, épinglée si la hauteur le permet), ligne « phase · minuteur » avec
   `TimerChip` (temps **restant**, ton neutre → attention sous une minute → dépassé ; vibration légère une fois par
   seuil via `HapticFeedback`, sans dépendance), le **schéma en premier** (borné à la hauteur restante pour tenir sans
   défiler), puis consigne et texte, et une **barre basse** Précédent / Noter les résultats / Suivant (flèches avec
   infobulle sous 600 dp, boutons empilés à texte ≥ 130 %, « Terminer » à la place de « Suivant » à la dernière étape,
   cibles ≥ 48 dp).
5. **Origine et groupe** : `group` garde un seul sens (« le groupe pour lequel on prépare ou on mène ») et traverse
   catalogue → détail → guide → présentation → saisie, et détail → planificateur. Deux paramètres d'origine de même
   énumération, jamais une adresse libre : `SheetOrigin { catalogue, planner, today, suggestion }` ; **`from`** sur le
   guide = origine directe du lancement (Aujourd'hui, Planifiées, Suggestion) ; **`via`** = origine du détail quand le
   guide en vient. La fonction pure `guideBackTarget` (couche `app`, testée sans widget) décide du retour : `from` prime ;
   à défaut une séance planifiée ramène à Planifiées (liens existants) ; sinon le détail avec son `via` et son `group`.
   Toute valeur inconnue retombe sur le détail sans origine. `RunKey` ne change pas : l'origine n'est pas une identité
   de séance (la reprise partage l'état).
6. **Plein écran natif : reporté à U3** (un contrôleur de plein écran se conçoit une fois pour la présentation et le
   guide) ; le mode immersif fonctionnel est déjà obtenu par la route hors cadre. Test en PWA installée : lot 15.

## Conséquences

- Les scénarios qui lisaient le titre, le public ou « Step n of m » dans le contenu lisent désormais l'en-tête
  (`I see the guide at step {n} of {m}`) ou la feuille « La séance » (`I see the session audience {…}`) ; « End
  session » et « Outline » passent par le menu ⋮. Aucun scénario n'est supprimé.
- Lancer un détail avec un groupe puis sans groupe crée deux cubits distincts (comme la séance suggérée) ; le plafond
  `maxRunning = 4` demeure.
- `StepAppBarAction` gagne `checked` et `enabled` (composant partagé, rétrocompatible) ; `StepAppBar` garantit des
  boutons de 48 dp.
- Clés de libellé retirées : `guideTimerLine`, `guideTimerSoon`, `guideTimerOver`, `guideTimerStart`,
  `guideTimerPause` (le minuteur est un `TimerChip`).

## Alternatives écartées

- Mode en simple paramètre d'adresse : il se perdrait à « Reprendre », à la présentation et à chaque « Suivant ».
- Mode en état seul : un lien ne pourrait pas ouvrir « en Relecture » (utile aux scénarios et au lot 16).
- Mémoriser le mode dans les Réglages : la règle par défaut suffit.
- Supprimer les badges `[Prop]` en Mener sans repli sémantique : contraire à la distinction `[S]` / `[Prop]`.
