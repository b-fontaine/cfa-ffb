#!/usr/bin/env bash
# Parcours de bout en bout : APPLICATION web + émulateurs Auth et Firestore + graine (lot FB3).
#
#   scripts/emulator_e2e.sh
#
# Lance `firebase emulators:exec` (Auth + Firestore, projet « demo-cfa-ffb », ports de
# firebase.json), pose la graine (scripts/seed_emulator.mjs), sert l'application en MODE DEBUG
# (`flutter run -d web-server --dart-define=FIREBASE_EMULATOR=true`, projet de l'émulateur) puis
# joue scripts/emulator_e2e/e2e.test.mjs dans Chrome : la directrice se connecte et lit son club
# sous les règles, un parent atterrit sur « Mes enfants ». Aucune requête n'atteint un projet
# Firebase réel : émulateurs seuls, projet « demo-… », hôtes autres que localhost refusés (SDK web servi en local).
#
# Pourquoi le mode debug : la release refuse l'émulateur (FirebaseEnvironment) et le build
# `--profile` est inutilisable avec firebase_auth_web 6.x (voir le test pour la cause).
#
# Prérequis (échec explicite, code 1, jamais de saut) : ceux de scripts/web_smoke.sh (Node, Java,
# npm ci, Chrome) + Flutter. Le port E2E_PORT (défaut 8099) doit être libre : un reste d'une
# exécution interrompue se nettoie avec `pkill -f "web-server --web-port"`.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

E2E_PROJECT="${E2E_PROJECT:-demo-cfa-ffb}"
E2E_PORT="${E2E_PORT:-8099}"

fail() {
  printf '\n✘ Parcours de bout en bout impossible : %s\n' "$1" >&2
  printf '  Installation : scripts/setup.sh (voir docs/engineering/quality-gates.md)\n' >&2
  exit 1
}

source "$ROOT/scripts/lib/prereqs.sh"
require_node
command -v flutter >/dev/null 2>&1 || fail "flutter introuvable."
require_java
require_firebase_cli
require_npm_package playwright-core
require_chrome

if (echo > "/dev/tcp/127.0.0.1/${E2E_PORT}") >/dev/null 2>&1; then
  fail "le port ${E2E_PORT} est déjà utilisé : arrêter l'exécution précédente."
fi

export PATH="$ROOT/node_modules/.bin:$PATH"
export FIREBASE_CLI_DISABLE_UPDATE_CHECK=true
export E2E_PORT

firebase emulators:exec \
  --project "$E2E_PROJECT" \
  --only auth,firestore \
  "$ROOT/scripts/emulator_e2e/serve_and_test.sh"
