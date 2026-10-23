#!/usr/bin/env bash
# Détection des données locales par le build web `firestore`, dans un VRAI Chrome (lot FB7c,
# ADR 0024 notes FB7c).
#
#   scripts/local_data_web.sh                 construit les deux builds web puis joue le test
#   scripts/local_data_web.sh --no-build      réutilise LOCAL_DATA_WEB_DRIFT / LOCAL_DATA_WEB_FIRESTORE
#
# Deux builds de production (dart2js) partagent la même origine, donc la même base IndexedDB :
# le build `drift` (explicite) la remplit, le build `firestore` la relève (scripts/local_data_web/).
# Les deux builds sont copiés hors de app/build/web, que les autres garde-fous réutilisent.
# Aucune requête n'atteint un projet Firebase : émulateur Auth « demo-… », tout autre hôte refusé.
#
# Prérequis (échec explicite, code 1, jamais de saut) : ceux de scripts/web_smoke.sh (Node, Java,
# Firebase CLI, npm ci) + Google Chrome installé.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOCAL_DATA_WEB_PROJECT="${LOCAL_DATA_WEB_PROJECT:-demo-cfa-ffb}"

fail() {
  printf '\n✘ Détection web des données locales impossible : %s\n' "$1" >&2
  printf '  Installation : scripts/setup.sh (voir docs/engineering/quality-gates.md)\n' >&2
  exit 1
}

source "$ROOT/scripts/lib/prereqs.sh"
require_node
require_java
require_firebase_cli
require_npm_package playwright-core
require_chrome

if [[ "${1:-}" != "--no-build" ]]; then
  WORK="$(mktemp -d -t local_data_web.XXXXXX)"
  trap 'rm -rf "$WORK"' EXIT
  # Le build par défaut (firestore, bascule du 2026-10-21), sans drapeau.
  "$ROOT/scripts/build_web.sh"
  cp -r app/build/web "$WORK/firestore"
  # Le build drift (explicite) en dernier : c'est celui que app/build/web doit contenir ensuite
  # (par hygiène : web_smoke.sh reconstruit désormais toujours son propre build drift).
  "$ROOT/scripts/build_web.sh" --dart-define=DATA_BACKEND=drift
  cp -r app/build/web "$WORK/drift"
  export LOCAL_DATA_WEB_DRIFT="$WORK/drift"
  export LOCAL_DATA_WEB_FIRESTORE="$WORK/firestore"
fi
[[ -n "${LOCAL_DATA_WEB_DRIFT:-}" && -n "${LOCAL_DATA_WEB_FIRESTORE:-}" ]] ||
  fail "LOCAL_DATA_WEB_DRIFT et LOCAL_DATA_WEB_FIRESTORE doivent désigner les deux builds."

export PATH="$ROOT/node_modules/.bin:$PATH"
export FIREBASE_CLI_DISABLE_UPDATE_CHECK=true

firebase emulators:exec \
  --project "$LOCAL_DATA_WEB_PROJECT" \
  --only auth \
  "node --test ${LOCAL_DATA_WEB_NODE_ARGS:-} scripts/local_data_web/*.test.mjs"
