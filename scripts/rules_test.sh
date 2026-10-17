#!/usr/bin/env bash
# Tests des règles Firestore (lot FB1) et de l'authentification (lot FB2) contre
# l'ÉMULATEUR (ADR 0024).
#
#   scripts/rules_test.sh
#
# Lance `firebase emulators:exec` (Auth + Firestore, ports de firebase.json) puis
# `node --test scripts/rules_test/`. Aucune requête n'atteint le projet Firebase
# réel : projet « demo-… » (émulateurs seuls), jamais de déploiement.
#
# Prérequis (échec explicite, code 1, jamais de saut silencieux) : Node >= 24.12,
# Java >= 21 (testé avec 21 à 27, la plage acceptée par firebase-tools 15 :
# voir docs/engineering/quality-gates.md), dépendances npm installées (`npm ci`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Projet « demo- » : l'émulateur refuse toute connexion à un vrai projet.
RULES_TEST_PROJECT="${RULES_TEST_PROJECT:-demo-cfa-ffb}"
# Java : version minimale acceptée (les émulateurs de firebase-tools 15 exigent 21+).
JAVA_MIN=21
NODE_MIN_MAJOR=24
NODE_MIN_MINOR=12

fail() {
  printf '\n✘ Tests des règles Firestore impossibles : %s\n' "$1" >&2
  printf '  Installation : scripts/setup.sh (voir docs/engineering/quality-gates.md)\n' >&2
  exit 1
}

command -v node >/dev/null 2>&1 || fail "node introuvable (Node >= ${NODE_MIN_MAJOR}.${NODE_MIN_MINOR} requis)."
node_version="$(node -p 'process.versions.node')"
node_major="${node_version%%.*}"
node_minor="$(printf '%s' "$node_version" | cut -d. -f2)"
if (( node_major < NODE_MIN_MAJOR || (node_major == NODE_MIN_MAJOR && node_minor < NODE_MIN_MINOR) )); then
  fail "Node ${node_version} trop ancien (>= ${NODE_MIN_MAJOR}.${NODE_MIN_MINOR} requis)."
fi

command -v java >/dev/null 2>&1 || fail "java introuvable (Java >= ${JAVA_MIN} requis par les émulateurs)."
java_version="$(java -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')"
[[ "$java_version" =~ ^[0-9]+$ ]] || fail "version de Java illisible (java -version)."
(( java_version >= JAVA_MIN )) || fail "Java ${java_version} trop ancien (>= ${JAVA_MIN} requis)."

command -v npx >/dev/null 2>&1 || fail "npx introuvable (npm requis)."
[[ -x node_modules/.bin/firebase ]] \
  || fail "node_modules/.bin/firebase absent : lancer « npm ci » à la racine du dépôt."
[[ -d node_modules/@firebase/rules-unit-testing ]] \
  || fail "@firebase/rules-unit-testing absent : lancer « npm ci » à la racine du dépôt."

# firebase-tools du paquet (version épinglée), jamais le binaire global.
export PATH="$ROOT/node_modules/.bin:$PATH"
# Pas de télémétrie ni de mise à jour intrusive en CI / local.
export FIREBASE_CLI_DISABLE_UPDATE_CHECK=true

firebase emulators:exec \
  --project "$RULES_TEST_PROJECT" \
  --only auth,firestore \
  "node --test scripts/rules_test/"
