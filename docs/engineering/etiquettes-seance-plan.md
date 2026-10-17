# Plan : note de jeu par étiquettes prédéfinies (lot 10b, reste)

Statut : **livré** (2026-10-17). Solde le « reste non livré » du lot 10b ([seance-en-cours-plan.md](seance-en-cours-plan.md) § 1).
Décision de l'animateur du 2026-10-17 : **étiquettes prédéfinies, jamais de texte libre**. Décision structurante :
[ADR 0023](adr/0023-etiquettes-de-seance-liste-fermee-schema-v11-sauvegarde-v5.md). Schéma drift : v10 → **v11** ; sauvegarde : v4 → **v5**.

## 1. Pourquoi des étiquettes

Un texte libre sur des mineurs peut nommer un enfant, une santé, un comportement : c'est une donnée personnelle d'une autre nature, hors
de l'effacement par élève et de la sauvegarde. Une **liste fermée** d'étiquettes sur la *séance* (jamais sur un élève) supprime ce risque
par construction : rien d'autre que ces valeurs ne peut entrer en base, dans un fichier de sauvegarde ni à l'écran.

## 2. La liste `[Prop]` (non publiée par la FFB)

Huit étiquettes pédagogiques neutres, non nominatives, choix multiple (ordre d'affichage = ordre de l'énumération `SessionTag`) :

| Code enregistré | fr | en |
|---|---|---|
| `gameAppreciated` | Jeu apprécié | Game enjoyed |
| `instructionsToRephrase` | Consigne à reformuler | Instructions to rephrase |
| `tooLong` | Trop long | Too long |
| `tooShort` | Trop court | Too short |
| `tooHard` | Trop difficile | Too hard |
| `tooEasy` | Trop facile | Too easy |
| `toRedo` | À refaire | To do again |
| `equipmentLacking` | Matériel insuffisant | Not enough equipment |

Écartées volontairement : toute étiquette sur l'attention, le comportement ou l'ambiance du **groupe** (« dissipé », « calme »…),
qui qualifierait en creux des enfants. Le code enregistré est le `name` de l'énumération : ne jamais le renommer sans migration.

## 3. Décisions

| # | Décision | Pourquoi |
|---|---|---|
| E1 | `enum SessionTag` dans `shared/lib` (Dart pur), avec `encodeSessionTags` / `decodeSessionTags` | Partagée par deux entités (`run_progress`, `session_record`) qui ne peuvent pas s'importer (même couche FSD) |
| E2 | `SessionRecord.tags` et `RunProgress.tags` : `Set<SessionTag>`, vide par défaut | Rétrocompatible : aucun appelant existant ne change |
| E3 | Colonne `tags_json` (texte, défaut `'[]'`) sur `session_records` et `run_progress_entries`, migration additive `from10To11` | Même parti que `counts_json` (ADR 0020) ; pas de table fille pour un petit ensemble fermé |
| E4 | Lecture : **tolérante** sur la saisie (code inconnu ignoré, colonne illisible = aucune étiquette, jamais d'exception à l'ouverture) ; **stricte** sur la séance en cours (ligne illisible supprimée, comme les compteurs) | La saisie est durable et ne doit pas bloquer l'application ; l'état en cours est transitoire |
| E5 | Sauvegarde **v5** : `sessionRecords[].tags` obligatoire (liste de codes sans doublon), **refusée** dans les formats 1 à 4 ; lecture des v1 à v4 inchangée (saisies sans étiquette) | Même doctrine que `seasonArchives` (v4) et `alertAcknowledgements` (v3) ; un code inconnu ou un texte libre = `backupInvalid`, rien n'est écrit |
| E6 | Les étiquettes de la **séance en cours** ne vont pas dans la sauvegarde (comme tout `run_progress`, ADR 0020 D3) | État transitoire local |
| E7 | **Saisie** : à l'étape « Bilan » du guide (`RunSheetCubit.tagsChanged`, gardée avec la séance en cours, comptée comme progression) ; **correction** depuis le bilan de la saisie (`SessionReviewEvent.tagsChanged` → `SetSessionTags`, écrit à chaque tap) | Le guide est là où l'animateur juge sa séance ; le bilan est relu et partageable |
| E8 | **Passage à la saisie** à « Terminer » seulement (`RunSheetCubit.endSession` → `RunProgressKeeper.giveTags`), si une saisie est ouverte depuis le guide **et** que des étiquettes sont choisies. « Recommencer » et « Abandonner » ne donnent rien ; sans saisie ouverte, les étiquettes sont oubliées avec la séance (le guide le dit en toutes lettres) ; un ensemble vide ne touche pas aux étiquettes déjà corrigées dans le bilan | Pas d'écriture surprise ; la page attend `endSession` avant d'ouvrir le bilan, qui relit la saisie |
| E9 | Port `SessionRecordRepository.setTags(id, tags)` : n'écrit que la colonne, sans effet sur une saisie absente ou supprimée | Une seule voie d'écriture pour le guide et le bilan ; ne réécrit ni présences ni blocs |

## 4. Effacement (RGPD)

- **Séance en cours** : les étiquettes sont dans la ligne `run_progress_entries` ; l'effacement par lien (groupe, saisie, séance
  planifiée), la clôture, la péremption à 7 jours, « Terminer » et « Abandonner » les effacent avec la ligne (test de parité d'effacement
  étendu : lignes semées avec étiquettes).
- **Saisie** : les étiquettes sont **non nominatives par construction**. Effacer un élève retire sa présence, **pas** les étiquettes de la
  séance (test : `erase_student_test`, groupe « session tags »). Supprimer la saisie (suppression logique) garde la colonne comme les
  autres champs de la saisie ; l'effacement physique éventuel d'une saisie relève de l'ADR 0001, inchangé.
- Limite dite honnêtement : une étiquette sur une séance d'un groupe d'un seul élève (« Trop difficile ») dit quelque chose de la séance
  de cet élève sans le nommer ; c'est le même niveau d'information que la date et la séance du catalogue déjà conservées.

## 5. Interface

- `SessionTagPicker` (`shared/ui`) : voir [design-system.md](design-system.md) ; clé `session-tags` ; coche + bleu-tapis, 48 dp,
  aucun champ de texte.
- Guide, étape « Bilan » : titre « Notes de séance », phrase d'aide, sélecteur, puis une ligne qui dit si les étiquettes seront
  **conservées** (saisie ouverte) ou **perdues** (aucune saisie ouverte).
- Bilan de la saisie : carte « Notes de séance » sous les passages (même sans passage saisi).
- i18n : 12 clés identiques en fr et en (`sessionTags*`, `sessionTag*`).

## 6. Scénarios et tests

- BDD `session_tags.feature` (7 scénarios : liste fermée sans champ de texte, choix multiple, relance, message sans saisie, « Terminer »
  avec saisie vers le bilan, « Terminer » sans saisie, correction depuis le bilan + rechargement) ; `data_backup.feature` (3 scénarios :
  aller-retour, fichier du format 4, étiquette inconnue refusée).
- Unitaires : `SessionTag` et JSON, `RunProgress`, contrats des dépôts (mémoire et drift), lecture tolérante / stricte, migration v11
  (instantané et mise à niveau depuis v10), codec v5 (écriture, v4, clé refusée, clé manquante, code inconnu, texte libre, doublon,
  non-liste), `SetSessionTags`, bloc du bilan, cubit du guide (écriture, reprise, `endSession`, `restart`, échec d'écriture), vue du
  guide, vue du bilan, `SessionTagPicker` (fr / en, 48 dp, 320 dp à 200 %).

## 7. Réalisation et écarts

**Rouges constatés avant le code** (échecs d'assertion ou de compilation, dits comme tels) : minuteur (2 tests : fond et icône) ;
`session_tags.feature` 7 / 7 en échec d'assertion (zone absente) ; `SessionTag`, contrats mémoire / drift, `RunProgress`, codec v5
(12 en échec), `SetSessionTags`, cubit, vue, sélecteur : échec de compilation (symbole absent) ou d'assertion.

**Pas de rouge préalable** (validés par mutation, voir ci-dessous) : les tests de migration v11 (écrits après `make-migrations`, qui
génère le schéma de test) et les trois scénarios de sauvegarde de `data_backup.feature` (écrits quand le codec était déjà fait sous
rouge unitaire).

**Mutations** (19 mutants appliqués à la main, tous tués) : migration sans l'une ou l'autre colonne ; encodeur sans `tags` (tué aussi
par le BDD seul) ; écriture et lecture drift sans étiquettes ; doublons acceptés ; étiquette inconnue acceptée (tué par le BDD seul) ;
clé refusée en v4 acceptée ; lecture stricte de la séance en cours rendue tolérante ; `endSession` qui ne donne rien ; comparaison
d'état sans étiquettes ; reprise et écriture sans étiquettes ; page qui appelle `finish` au lieu de `endSession` ; sélecteur du bilan
vide ; bloc qui n'écrit pas ; indice « conservées / perdues » inversé ; `setTags` qui efface les présences ; minuteur dépassé remis en
rouge. **Mutant équivalent** : `setTags` sans le filtre « non supprimée » (une saisie supprimée est invisible, donc l'écriture
n'est pas observable ; le filtre est gardé par prudence).

**Écarts** : (1) les anciens tests qui « rétrogradent » un fichier de sauvegarde (formats 1 à 4) retirent maintenant aussi les
étiquettes (`test/support/backup_formats.dart`) ; (2) deux tests de migration (v3 → v4, v9 → v10) lisaient par le dépôt courant : ils
passent par du SQL brut (piège connu) ; (3) le test « le format reste v4 » de 10b devient « 5, par les étiquettes, pas par les séances
en cours » ; (4) le bloc du bilan n'a pas de transformateur séquentiel (aucune dépendance ajoutée) : deux taps simultanés font gagner
le dernier terminé, chaque événement portant l'ensemble complet.

**Parcours web** (build release, Playwright, 390 × 844 et 1280 × 800, captures hors dépôt) : étape « Bilan » (liste, choix, coche,
persistance au rechargement), ouverture d'une saisie depuis le guide, indice « conservées », « Terminer » → bilan avec les étiquettes,
correction dans le bilan et persistance au rechargement ; minuteur dépassé rendu avec l'horloge simulée (fond sombre, sablier,
`+00:05`, non rouge) à 1280 et 390 de large.

## 8. Limites

- Aucune synchronisation entre appareils (Firebase, horizon H5) : les étiquettes suivent la sauvegarde v5 uniquement.
- Une ancienne version de l'application refuse un fichier v5 (clé inconnue) : à exporter une sauvegarde avant de mettre à jour si deux
  appareils coexistent.
- Les étiquettes ne sont pas encore exploitées (aucune statistique, aucune recommandation) : elles sont conservées et relisibles.
- La liste est `[Prop]` : à valider par l'animateur ; en changer une valeur après coup demande une migration.
