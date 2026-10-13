#!/usr/bin/env bash
# Diagrammes d'exercices : source unique de vérité = docs/knowledge.
#
#   scripts/sync_diagrammes.sh          copie les pages à table vers les assets de l'application
#   scripts/sync_diagrammes.sh --check  vérifie l'égalité (lecture seule)
#
# Seules les pages qui portent au moins un diagramme à table (kind: exercise,
# game ou initiation) sont embarquées : les pages techniques (photos, schémas
# sans table) n'ont aucun usage dans l'application. L'arborescence
# <dossier>/pNN.yaml est conservée ; la source n'est jamais modifiée et l'asset
# ne s'édite pas à la main. Les dossiers sont déclarés dans app/pubspec.yaml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/docs/knowledge/03-exercices/diagrammes"
TARGET="$ROOT/app/assets/diagrammes"
PUBSPEC="$ROOT/app/pubspec.yaml"

# Chemins relatifs (<dossier>/pNN.yaml) des pages à embarquer, triés.
selected() {
  (
    cd "$SOURCE"
    grep -rlE '^[[:space:]]*kind:[[:space:]]*(exercise|game|initiation)[[:space:]]*$' \
      --include='p[0-9][0-9].yaml' . | sed 's|^\./||' | LC_ALL=C sort
  ) || true
}

# Chemins relatifs des fichiers actuellement dans l'asset, triés.
present() {
  [[ -d "$TARGET" ]] || return 0
  (cd "$TARGET" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
}

EXPECTED="$(selected)"
if [[ -z "$EXPECTED" ]]; then
  echo "Aucun diagramme à table dans $SOURCE" >&2
  exit 1
fi

case "${1:-}" in
  "")
    rm -rf "$TARGET"
    while IFS= read -r page; do
      mkdir -p "$TARGET/$(dirname "$page")"
      cp "$SOURCE/$page" "$TARGET/$page"
    done <<<"$EXPECTED"
    echo "Diagrammes copiés vers app/assets/diagrammes/ ($(wc -l <<<"$EXPECTED" | tr -d ' ') pages)."
    ;;
  --check)
    if [[ ! -d "$TARGET" ]]; then
      echo "Assets absents : lancer scripts/sync_diagrammes.sh" >&2
      exit 1
    fi
    if [[ "$(present)" != "$EXPECTED" ]]; then
      echo "Liste des assets différente de la source : lancer scripts/sync_diagrammes.sh" >&2
      diff <(echo "$EXPECTED") <(present) >&2 || true
      exit 1
    fi
    while IFS= read -r page; do
      if ! cmp -s "$SOURCE/$page" "$TARGET/$page"; then
        echo "$page différent de la source : lancer scripts/sync_diagrammes.sh" >&2
        exit 1
      fi
    done <<<"$EXPECTED"
    # Chaque dossier d'assets doit être déclaré dans le pubspec : la
    # déclaration n'est pas récursive, un dossier oublié disparaîtrait de
    # l'application sans erreur.
    undeclared=0
    while IFS= read -r folder; do
      declared="assets/diagrammes/$folder/"
      if ! grep -qE "^[[:space:]]*-[[:space:]]+${declared}[[:space:]]*$" "$PUBSPEC" 2>/dev/null; then
        echo "Dossier $declared absent de app/pubspec.yaml (section flutter: assets:)" >&2
        undeclared=1
      fi
    done < <(while IFS= read -r page; do dirname "$page"; done <<<"$EXPECTED" | LC_ALL=C sort -u)
    if [[ "$undeclared" -ne 0 ]]; then
      exit 1
    fi
    echo "Diagrammes : assets identiques à la source."
    ;;
  *)
    echo "Usage : scripts/sync_diagrammes.sh [--check]" >&2
    exit 2
    ;;
esac
