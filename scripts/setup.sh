#!/usr/bin/env bash
# Installe les hooks git du dépôt et prépare le projet Flutter.
set -euo pipefail
cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
chmod +x .githooks/* scripts/*.sh
echo "Hooks git installés (.githooks)."

scripts/generate.sh
echo "Projet prêt. Vérification rapide : scripts/check.sh --fast"
