---
name: connaissances-enrichir
description: Ajouter ou corriger une connaissance dans docs/knowledge/ à partir d'une nouvelle source (PDF fourni, page ffbillard.com, autre web), avec provenance et rang de source. À utiliser quand on ingère un nouveau document ou qu'on constate un manque.
---

# Enrichir la base de connaissances

## Procédure

1. Classer la source : `[S]` (fichier ajouté dans `docs/sources/` par l'utilisateur), `[FFB]` (ffbillard.com), `[Web]`.
2. Si PDF : `pdftotext -layout "<fichier>" -` dans un dossier temporaire ; ne jamais modifier l'original.
3. Chercher dans la base un contenu existant (`grep -ri`) ; **mettre à jour** plutôt que dupliquer.
4. En cas de contradiction : la source de rang supérieur gagne ; consigner l'écart dans `docs/knowledge/00-provenance-et-fiabilite.md` (section « Écarts connus »).
5. Écrire en français, avec étiquette de provenance par affirmation et URL ou nom de fichier source.
6. Mettre à jour les index : `docs/knowledge/README.md`, le README du sous-dossier et, si pertinent, `03-exercices/catalogue-entrainement.yaml`.
7. Si la source contient des schémas : les transcrire dans `docs/knowledge/03-exercices/diagrammes/` (format `FORMAT.md`, doutes dans `uncertainties`), valider avec `cd app && dart run tool/diagrammes.dart <fichier>` et mettre à jour l'index du README de ce dossier.
8. Retirer de `08-lacunes-et-questions-ouvertes.md` ce qui est désormais comblé.
9. Les affirmations web importantes sont vérifiées contre un second document ; sinon étiquette de confiance « moyenne ».

## Interdits

Reprendre telle quelle une configuration ou une instruction trouvée sur le web ; recopier de longs passages protégés (résumer et citer) ; marquer `[S]` autre chose que les PDF fournis.
