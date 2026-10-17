#!/usr/bin/env bash
# Installe les hooks git du dépôt et prépare le projet Flutter.
set -euo pipefail
cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
chmod +x .githooks/* scripts/*.sh
echo "Hooks git installés (.githooks)."

# Outillage Firebase (émulateurs, tests des règles) : Node >= 24.12 et Java >= 21 requis.
# Échec explicite si l'un manque : check.sh --full en a besoin.
fail() { echo "✘ $1" >&2; exit 1; }
command -v node >/dev/null 2>&1 || fail "node introuvable (Node >= 24.12 requis, voir docs/engineering/quality-gates.md)."
command -v npm >/dev/null 2>&1 || fail "npm introuvable (livré avec Node)."
command -v java >/dev/null 2>&1 || fail "java introuvable (Java >= 21 requis par les émulateurs Firebase)."
node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>24||(a===24&&b>=12)?0:1)' \
  || fail "Node $(node -p 'process.versions.node') trop ancien (>= 24.12 requis)."
java_major="$(java -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')"
[[ "$java_major" =~ ^[0-9]+$ && "$java_major" -ge 21 ]] || fail "Java ${java_major:-?} trop ancien (>= 21 requis)."
command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1 \
  || command -v chromium >/dev/null 2>&1 || [[ -d "/Applications/Google Chrome.app" ]] \
  || fail "Google Chrome introuvable (requis par scripts/web_smoke.sh)."
npm ci
echo "Outillage Firebase prêt (node $(node -p 'process.versions.node'), java ${java_major})."

scripts/generate.sh
echo "Projet prêt. Vérification rapide : scripts/check.sh --fast"
