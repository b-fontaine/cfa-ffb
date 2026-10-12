# Évaluation et suivi des élèves

Source `[S]` : *Fiches résultats CFA blackball.pdf* (1 page) et section « fiches résultats » du mémento.

## La fiche résultats

- Une fiche par **élève** et par **exercice d'entraînement** : on renseigne le nom, la séance, l'exercice, la notion technique.
- Colonnes : **essais** successifs (5 sur la fiche fournie ; l'exemple du mémento en montre 6). Chaque colonne contient « Nb de billes empochées / … ».
- Axe vertical gradué de 0 à 16 : on pointe le score à la ligne correspondante de l'essai, puis on **relie les points** pour tracer une courbe de performance.
- Exemple du mémento : essai 1 = 5/10, essai 2 = 7/10, essai 3 = 6/10, essai 4 = 8/10.

## Règle de passage

Le passage à l'exercice suivant se décide au **taux de réussite** indiqué sur chaque fiche d'entraînement (voir `03-exercices/entrainement.md`). Le nombre de séances conseillé par notion est **approximatif**.

## Billard de bronze `[S]` (mention) / `[FFB]` (contexte)

Les exercices sur les quantités de bille (plein, demi, trois-quarts, quart/finesses, quantités) portent la mention « **Billard de bronze** » dans les fiches. `[FFB]` (dossier CEB 2013, confiance moyenne) : les évaluations *bronze-billard*, *argent-billard* et *or-billard* ont été introduites en 2003 comme outils de l'« École de billard ». Le contenu exact de l'épreuve de bronze n'est **pas** dans les sources fournies : ne pas l'inventer. Voir `08-lacunes-et-questions-ouvertes.md`.

## Données minimales à suivre `[Prop]` (pour l'application)

| Donnée | Description |
|--------|-------------|
| Élève | Identifiant, prénom, public (enfant / adulte) |
| Séance | Date, durée, notions travaillées |
| Résultat | Exercice (bloc + n°), liste des essais (réussis / total) |
| Progression | Exercice validé quand le taux requis est atteint |
