# ADR 0023 — Étiquettes de séance : liste fermée sans texte libre, colonnes `tags_json` (schéma v11), sauvegarde v5

- Statut : **accepté et livré** (2026-10-17). Décision de l'animateur du même jour : « étiquettes prédéfinies, pas de texte libre ». Solde
  le reste du lot 10b ; conception : [../etiquettes-seance-plan.md](../etiquettes-seance-plan.md). S'appuie sur l'[ADR 0001](0001-persistance-locale-drift.md)
  (effacement), l'[ADR 0020](0020-seance-en-cours-persistee-locale-hors-sauvegarde.md) (séance en cours) et l'[ADR 0019](0019-cloture-de-saison-archive-agregee-et-effacement-en-lot.md).
- Contexte : l'animateur veut garder un jugement sur la séance donnée. Un texte libre sur des mineurs échappe à toute maîtrise (nom d'un
  enfant, santé, comportement) et exigerait finalité, durée, effacement et visibilité propres.

## Décision

1. **Liste fermée** `SessionTag` (huit valeurs `[Prop]`, `shared/lib`) : jugements sur la **séance**, jamais sur un élève ni un groupe.
   Aucun champ de texte nulle part.
2. **`tags_json`** (liste JSON de codes, défaut `'[]'`) sur `session_records` et sur `run_progress_entries` : schéma **v11**, migration
   additive `from10To11`. Lecture tolérante pour la saisie, stricte pour l'état en cours.
3. **Sauvegarde v5** : `sessionRecords[].tags` obligatoire (codes connus, sans doublon), refusée dans les formats 1 à 4 ; tout autre
   contenu est `backupInvalid`, avant toute écriture. Lecture des v1 à v4 inchangée. L'état en cours reste hors sauvegarde (ADR 0020).
4. **Saisie** à l'étape « Bilan » du guide, passage à la saisie à « Terminer » (si une saisie est ouverte), **correction** depuis le bilan.
   Sans saisie ouverte, les étiquettes sont oubliées avec la séance, et le guide le dit.
5. **Effacement** : les étiquettes de la séance en cours partent avec sa ligne (par lien, clôture, péremption, fin, abandon) ; celles
   d'une saisie sont non nominatives et restent quand un élève est effacé.

## Alternatives écartées

- **Texte libre** (même court, même borné) : écarté par l'animateur.
- **Table fille `session_record_tags`** : plus de SQL pour un ensemble fermé de huit valeurs lu et écrit d'un bloc.
- **Étiquettes sur l'élève ou sur le groupe** (« dissipé ») : qualifieraient des mineurs ; hors périmètre.
- **Tolérer `tags` dans les anciens formats** : contraire à la doctrine du codec (clé inconnue du format = fichier invalide).
- **Écrire les étiquettes dans la saisie à chaque tap du guide** : écritures surprises, même quand l'animateur « Recommence » ou « Abandonne ».

## Conséquences

- Une ancienne version de l'application refuse un fichier v5.
- Les étiquettes ne sont pas exploitées (pas de statistique) ; la liste est à valider, la modifier demande une migration.
- Changer d'appareil ne reprend pas les étiquettes de la séance en cours ; celles de la saisie suivent la sauvegarde.
- Aucune dépendance ajoutée.

## Limites assumées

- Une étiquette sur la séance d'un groupe d'un seul élève dit quelque chose de cette séance sans nommer l'élève.
- Deux taps simultanés dans le bilan : le dernier terminé gagne (chaque événement porte l'ensemble complet).
