# ADR 0016 — Identité d'une saisie : groupe, jour et séance du catalogue

- Statut : **accepté et implémenté** (2026-10-16), points [U] au défaut proposé. Plan :
  `../lien-saisie-planifiee-plan.md`. Amende la décision 2 et la limite de
  l'[ADR 0007](0007-lien-seance-planifiee-saisie-catalogue.md).

## Contexte

Le lien séance planifiée ↔ saisie est dérivé par (groupe, jour) : une saisie
d'une autre séance du catalogue le même jour fait afficher « Résultats saisis »
(l'accueil annonce « Aucune séance planifiée »), et « Noter » reprend cette
saisie en **réécrivant sa séance du catalogue** (défaut D1, reproduit par
`d1_link_repro_test.dart`).

## Décision

1. Une saisie est identifiée par **(groupe, jour, séance du catalogue)**. Règle
   unique, pure, dans `entities/session_record/domain/record_matching.dart` :
   deux séances du catalogue **différentes** ne se confondent jamais ; `null`
   (saisie sans séance du catalogue) est compatible avec toute séance ; à
   candidats multiples, l'égalité exacte l'emporte, puis l'ordre de sauvegarde.
2. `ListSessions` (lien « saisie faite ») et `OpenOrResumeSession` (reprise)
   appellent cette règle. Une saisie reprise ne perd plus sa séance du
   catalogue.
3. **Aucun lien stocké, aucune migration, format de sauvegarde inchangé (3).**

## Transfert silencieux d'une saisie sans séance du catalogue

Cas à connaître, **assumé** (point U-1 du plan) : quand `OpenOrResumeSession`
reprend une saisie dont `sheetId` est `null` et que la séance demandée en porte
une, la saisie **reçoit** cette séance du catalogue (`copyWith(sheetId:)`),
sans message ni confirmation. La saisie libre du jour (formulaire manuel,
suggestion sans séance, ancienne saisie) devient alors celle de la première
séance planifiée qui la réclame ; une seconde planifiée du même jour, d'une
autre séance du catalogue, ouvre ensuite sa propre saisie (la première a
désormais une séance). Conséquences :

- le choix de la séance qui « absorbe » la saisie libre dépend de l'ordre dans
  lequel l'animateur appuie sur « Noter » ; ce n'est pas l'ordre de la
  planification ;
- tant que la saisie reste sans séance, `ListSessions` la rattache à **toutes**
  les planifiées du jour du groupe (« Résultats saisis » sur chacune) : défaut
  D1 résiduel, couvert par `list_sessions_test` et
  `open_or_resume_session_test` ;
- l'inverse n'existe pas : une saisie qui a une séance ne la perd jamais, et la
  reprise sans séance demandée (formulaire manuel) la conserve.

Le corriger (saisie libre jamais rattachée) casserait la reprise depuis le
formulaire manuel et créerait des doublons : écarté tant que l'option B du plan
(lien explicite) n'est pas retenue.

## Alternatives rejetées

- Filtre d'affichage seul : « Noter » réécrirait la saisie de l'autre séance.
- `SessionRecord.plannedSessionId` (schéma v9, sauvegarde v4) : reporté ; le
  repli par la règle ci-dessus resterait nécessaire pour les saisies sans lien.
  À rouvrir si deux séances identiques le même jour deviennent un besoin.
- Une seule planifiée par (groupe, jour) ; `Session.recordId` : voir le plan § 3.

## Conséquences

- Deux saisies le même jour pour un groupe deviennent un cas normal (assiduité
  et « séances données » les comptent chacune).
- Limites : deux planifiées indiscernables partagent leur saisie ; une saisie
  sans séance du catalogue est prise pour celle de la planifiée du jour.
