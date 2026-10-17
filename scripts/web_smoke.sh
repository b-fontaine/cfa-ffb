#!/usr/bin/env bash
# Fumée du build web COMPILÉ contre l'émulateur Auth (lot FB2, ADR 0024).
#
#   scripts/web_smoke.sh           utilise app/build/web s'il existe, sinon le construit
#   scripts/web_smoke.sh --build   reconstruit d'abord (scripts/build_web.sh)
#
# Charge le build de production (dart2js) dans Chrome et vérifie, avec le vrai SDK
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
JAVA_MIN=21

fail() {
  printf '\n✘ Fumée du build web impossible : %s\n' "$1" >&2
  printf '  Installation : scripts/setup.sh (voir docs/engineering/quality-gates.md)\n' >&2
  exit 1
}

command -v node >/dev/null 2>&1 || fail "node introuvable (Node >= 24.12 requis)."
command -v java >/dev/null 2>&1 || fail "java introuvable (Java >= ${JAVA_MIN} requis par les émulateurs)."
java_version="$(java -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')"
[[ "$java_version" =~ ^[0-9]+$ ]] || fail "version de Java illisible (java -version)."
(( java_version >= JAVA_MIN )) || fail "Java ${java_version} trop ancien (>= ${JAVA_MIN} requis)."
[[ -x node_modules/.bin/firebase ]] \
  || fail "node_modules/.bin/firebase absent : lancer « npm ci » à la racine du dépôt."
[[ -d node_modules/playwright-core ]] \
  || fail "playwright-core absent : lancer « npm ci » à la racine du dépôt."

chrome_found=false
for candidate in google-chrome google-chrome-stable chrome chromium; do
  command -v "$candidate" >/dev/null 2>&1 && chrome_found=true
done
[[ "$chrome_found" == true || -d "/Applications/Google Chrome.app" ]] \
  || fail "Google Chrome introuvable (installé d'office sur les exécuteurs GitHub)."

if [[ "${1:-}" == "--build" || ! -f app/build/web/index.html ]]; then
  "$ROOT/scripts/build_web.sh"
fi

export PATH="$ROOT/node_modules/.bin:$PATH"
export FIREBASE_CLI_DISABLE_UPDATE_CHECK=true

firebase emulators:exec \
  --project "$WEB_SMOKE_PROJECT" \
  --only auth \
  "node --test scripts/web_smoke/"
