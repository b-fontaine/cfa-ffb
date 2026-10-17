# ADR 0020 — Séance en cours persistée : état local par appareil, sans identifiant d'élève, hors sauvegarde ; schéma v10, sauvegarde inchangée (v4)

- Statut : **accepté et livré** (2026-10-17) sur les défauts proposés (points `[U]` U10b-1 à U10b-5 du plan à confirmer par l'animateur), lot 10b. Conception : [../seance-en-cours-plan.md](../seance-en-cours-plan.md). Solde la décision U-5 de
  [../aujourdhui-plan.md](../aujourdhui-plan.md). S'appuie sur l'[ADR 0001](0001-persistance-locale-drift.md) (effacement et conservation), l'[ADR
  0015](0015-guide-mener-route-modes-origine.md) (le cubit du guide vit dans `RunSheetSessions`) et l'[ADR
  0019](0019-cloture-de-saison-archive-agregee-et-effacement-en-lot.md) (liste unique des dépôts nominatifs à effacer).
- Contexte : étape, compteurs d'initiation, grille « acquis », score du jeu et minuteur ne vivent qu'en mémoire (`RunSheetCubit`). Un
  rechargement web ou une fermeture en pleine séance les perd. La **note de jeu en texte libre reste exclue** (décision de
  l'animateur du 2026-10-16) : un texte libre sur des mineurs demande son propre ADR.

## Décision

1. **Table `run_progress_entries`** (classe `RunProgressEntries`, schéma **v10** ; le plan la nommait `run_progress`), une ligne par séance guidée (`RunKey`), suppression **physique**, sans colonnes d'audit.
2. **Aucun identifiant d'élève** dans la table. La saisie ouverte depuis le guide n'est retenue que par son `recordId` ; groupe, date
   et absents sont relus de la saisie à la reprise. Les liens `groupId` et `recordId` servent à l'effacement.
3. **Hors sauvegarde : le format reste v4.** L'état est transitoire (péremption 7 jours `[Prop]`) et propre à l'appareil ; un fichier
   exporté échappe à l'effacement et ressusciterait à l'import l'état lié à un élève effacé. L'import ne touche pas à la table et les
   liens sont revalidés à la reprise.
4. **Effacement par lien** : `EraseStudent.eraseRecords` (donc aussi la clôture de saison) efface les lignes dont le groupe a compté
   l'élève, dont la séance planifiée est celle d'un de ces groupes (le guide lancé d'une séance planifiée ne porte que son
   identifiant, pas son groupe) ou dont la saisie le comptait présent, calculées avant l'effacement des présences et des
   appartenances. Fin de séance, abandon, éviction et péremption effacent aussi.
5. **Écriture à chaque changement utile**, minuteur par points de contrôle (10 s, pause, changement de phase), écritures sérialisées,
   échec non bloquant. **Minuteur restauré en pause**, sans rattrapage de l'horloge. Reprise par `resumeOffered` existant ; l'étape de
   l'adresse l'emporte.
6. **Couche `entities/run_progress`** (port + dépôts drift et mémoire) pour que `manage_students` et `run_sheet` n'aient pas à
   s'importer.

## Alternatives écartées

- **`localStorage` / fichier** : second mécanisme de stockage hors du contrat de dépôt, non effaçable par l'unité de travail.
- **Stocker `RunRecordChoice` tel quel** : copie des `StudentId` absents, un dépôt nominatif de plus à effacer.
- **Sauvegarde v5 avec `data.runProgress`** : voir 3 ; refus des anciennes versions pour une donnée sans valeur de restauration.
- **Rattraper l'horloge murale pour le minuteur** : « dépassé de 45 min » après une nuit, minuteur qui court sans surveillance.
- **Note de jeu en texte libre dans ce lot** : exclue ; ADR dédié (finalité, durée, effacement, sauvegarde).

## Conséquences

- Migration `from9To10` (création d'une table), test de migration, contrat de dépôt commun, parité d'effacement étendue.
- Changer d'appareil ou restaurer une sauvegarde ne reprend pas une séance en cours (à confirmer par l'animateur, U10b-4).
- Effacer un élève fait perdre l'état en cours des séances de son groupe (U10b-3).
- Firebase (lots FB) : cet état reste local et n'est pas synchronisé.

## Limites assumées (constatées à la réalisation)

- L'effacement atteint aussi les liens **supprimés logiquement** : groupes dont l'élève a été membre (périodes closes comprises),
  séances planifiées de ces groupes et saisies où il était présent restent en base jusqu'à leur purge, et leurs lignes sont
  retrouvées par `GroupRepository.idsEverContaining`, `SessionRepository.idsOfGroups` et
  `SessionRecordRepository.idsEverPresent`.
- Les guides gardés **en mémoire** sont libérés au moment de l'effacement : `RunProgressRepository.erased` publie les liens
  effacés, `RunSheetSessions` ferme les guides concernés et `RunSheetCubit.erase` n'accepte plus d'écriture puis oublie la ligne
  après celles qui étaient en vol. Si l'unité de travail est annulée après la publication, ces guides sont perdus de la mémoire
  mais leurs lignes restent (la reprise se fait au prochain lancement).
- Une séance guidée **sans groupe, sans séance planifiée ni saisie** (relecture seule) n'a aucun lien avec un élève : l'effacement
  d'un élève ne la touche pas.
- Un échec d'écriture est signalé à l'observateur de blocs (cubit) ou comme erreur du framework (échec de la restauration au
  démarrage), jamais montré à l'animateur ; la reprise est alors perdue, pas la séance.
- Deux onglets web ouverts sur la même base : la dernière écriture gagne.
