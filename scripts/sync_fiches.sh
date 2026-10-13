#!/usr/bin/env bash
# Séances du catalogue : source unique de vérité = docs/knowledge.
#
#   scripts/sync_fiches.sh          copie les séances vers les assets de l'application
#   scripts/sync_fiches.sh --check  vérifie l'égalité (lecture seule)
#
# Seuls les fichiers de séance NN-<id>.yaml sont embarqués (FORMAT.md et les
# autres fichiers du dossier restent hors de l'application). La source n'est
# jamais modifiée et l'asset ne s'édite pas à la main. Le dossier est déclaré
# dans app/pubspec.yaml.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/docs/knowledge/05-seances/catalogue"
TARGET="$ROOT/app/assets/fiches"
PUBSPEC="$ROOT/app/pubspec.yaml"
DECLARED="assets/fiches/"

# Noms (NN-<id>.yaml) des séances de la source, triés.
selected() {
  [[ -d "$SOURCE" ]] || return 0
  (cd "$SOURCE" && find . -maxdepth 1 -type f -name '[0-9][0-9]-*.yaml' \
    | sed 's|^\./||' | LC_ALL=C sort)
}

# Noms des fichiers actuellement dans l'asset, triés.
present() {
  [[ -d "$TARGET" ]] || return 0
  (cd "$TARGET" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
}

EXPECTED="$(selected)"
if [[ -z "$EXPECTED" ]]; then
  echo "Aucune séance dans $SOURCE" >&2
  exit 1
fi

case "${1:-}" in
  "")
    rm -rf "$TARGET"
    mkdir -p "$TARGET"
    while IFS= read -r name; do
      cp "$SOURCE/$name" "$TARGET/$name"
    done <<<"$EXPECTED"
    echo "Séances copiées vers app/assets/fiches/ ($(wc -l <<<"$EXPECTED" | tr -d ' ') fichiers)."
    ;;
  --check)
    if [[ ! -d "$TARGET" ]]; then
      echo "Assets absents : lancer scripts/sync_fiches.sh" >&2
      exit 1
    fi
    if [[ "$(present)" != "$EXPECTED" ]]; then
      echo "Liste des assets différente de la source : lancer scripts/sync_fiches.sh" >&2
      diff <(echo "$EXPECTED") <(present) >&2 || true
      exit 1
    fi
    while IFS= read -r name; do
      if ! cmp -s "$SOURCE/$name" "$TARGET/$name"; then
        echo "$name différent de la source : lancer scripts/sync_fiches.sh" >&2
        exit 1
      fi
    done <<<"$EXPECTED"
    # La déclaration d'un dossier d'assets n'est pas récursive : un dossier
    # oublié disparaîtrait de l'application sans erreur.
    if ! grep -qE "^[[:space:]]*-[[:space:]]+${DECLARED}[[:space:]]*$" "$PUBSPEC" 2>/dev/null; then
      echo "Dossier $DECLARED absent de app/pubspec.yaml (section flutter: assets:)" >&2
      exit 1
    fi
    echo "Séances : assets identiques à la source."
    ;;
  *)
    echo "Usage : scripts/sync_fiches.sh [--check]" >&2
    exit 2
    ;;
esac
