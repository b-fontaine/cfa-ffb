#!/usr/bin/env bash
# Fumée du build web COMPILÉ contre l'émulateur Auth (lot FB2, ADR 0024).
#
#   scripts/web_smoke.sh           utilise app/build/web s'il existe, sinon le construit
#   scripts/web_smoke.sh --build   reconstruit d'abord (scripts/build_web.sh)
#
# Charge le build de production en drift explicite (dart2js) dans Chrome et vérifie, avec le vrai SDK
# `firebase_auth`, le démarrage, l'échec générique de connexion, la connexion et la
# déconnexion (scripts/web_smoke/web_smoke.test.mjs). Aucune requête n'atteint le projet
# Firebase réel : émulateur « demo-… », tout autre hôte refusé par le test.
#
# Prérequis (échec explicite, code 1, jamais de saut) : ceux de scripts/rules_test.sh
# (Node, Java, npm ci) + Google Chrome installé.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

WEB_SMOKE_PROJECT="${WEB_SMOKE_PROJECT:-demo-cfa-ffb}"

fail() {
  printf '\n✘ Fumée du build web impossible : %s\n' "$1" >&2
  printf '  Installation : scripts/setup.sh (voir docs/engineering/quality-gates.md)\n' >&2
  exit 1
}

source "$ROOT/scripts/lib/prereqs.sh"
require_node
require_java
require_firebase_cli
require_npm_package playwright-core
require_chrome

if [[ "${1:-}" == "--build" || ! -f app/build/web/index.html ]]; then
  # Build drift explicite : Firestore n'est pas émulé ici (voir web_smoke.test.mjs) ; le défaut du
  # build (Firestore) est éprouvé par scripts/emulator_e2e.sh et par scripts/local_data_web.sh.
  "$ROOT/scripts/build_web.sh" --dart-define=DATA_BACKEND=drift
fi

export PATH="$ROOT/node_modules/.bin:$PATH"
export FIREBASE_CLI_DISABLE_UPDATE_CHECK=true

firebase emulators:exec \
  --project "$WEB_SMOKE_PROJECT" \
  --only auth \
  "node --test scripts/web_smoke/"
