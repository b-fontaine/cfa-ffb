#!/usr/bin/env bash
# Catalogue d'entraînement : source unique de vérité = docs/knowledge.
#
#   scripts/sync_catalogue.sh          copie la source vers l'asset de l'application
#   scripts/sync_catalogue.sh --check  vérifie l'égalité octet à octet (lecture seule)
#
# La source n'est jamais modifiée ; l'asset ne s'édite pas à la main.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/docs/knowledge/03-exercices/catalogue-entrainement.yaml"
TARGET="$ROOT/app/assets/catalogue/catalogue-entrainement.yaml"

case "${1:-}" in
  "")
    mkdir -p "$(dirname "$TARGET")"
    cp "$SOURCE" "$TARGET"
    echo "Catalogue copié vers app/assets/catalogue/."
    ;;
  --check)
    if [[ ! -f "$TARGET" ]]; then
      echo "Asset absent : lancer scripts/sync_catalogue.sh" >&2
      exit 1
    fi
    if ! cmp -s "$SOURCE" "$TARGET"; then
      echo "Asset différent de la source : lancer scripts/sync_catalogue.sh" >&2
      exit 1
    fi
    echo "Catalogue : asset identique à la source."
    ;;
  *)
    echo "Usage : scripts/sync_catalogue.sh [--check]" >&2
    exit 2
    ;;
esac
