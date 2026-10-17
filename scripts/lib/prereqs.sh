#!/usr/bin/env bash
# Contrôles de prérequis communs aux lanceurs d'émulateurs (rules_test.sh, web_smoke.sh,
# emulator_e2e.sh). À SOURCER : le script appelant définit `fail "message"` (qui sort en code 1).
# Jamais de saut silencieux : un prérequis manquant ou trop ancien échoue avec un message explicite.
#
# Java : borne BASSE seule (>= 21, imposée par firebase-tools 15) ; aucune borne haute vérifiée.
# Testé avec Java 27 en local, 21 en CI.

PREREQ_NODE_MIN_MAJOR=24
PREREQ_NODE_MIN_MINOR=12
PREREQ_JAVA_MIN=21

require_node() {
  command -v node >/dev/null 2>&1 \
    || fail "node introuvable (Node >= ${PREREQ_NODE_MIN_MAJOR}.${PREREQ_NODE_MIN_MINOR} requis)."
  local version major minor
  version="$(node -p 'process.versions.node')"
  major="${version%%.*}"
  minor="$(printf '%s' "$version" | cut -d. -f2)"
  if (( major < PREREQ_NODE_MIN_MAJOR || (major == PREREQ_NODE_MIN_MAJOR && minor < PREREQ_NODE_MIN_MINOR) )); then
    fail "Node ${version} trop ancien (>= ${PREREQ_NODE_MIN_MAJOR}.${PREREQ_NODE_MIN_MINOR} requis)."
  fi
}

require_java() {
  command -v java >/dev/null 2>&1 \
    || fail "java introuvable (Java >= ${PREREQ_JAVA_MIN} requis par les émulateurs)."
  local version
  version="$(java -version 2>&1 | sed -n '1s/.*version "\([0-9]*\).*/\1/p')"
  [[ "$version" =~ ^[0-9]+$ ]] || fail "version de Java illisible (java -version)."
  (( version >= PREREQ_JAVA_MIN )) || fail "Java ${version} trop ancien (>= ${PREREQ_JAVA_MIN} requis)."
}

require_firebase_cli() {
  [[ -x node_modules/.bin/firebase ]] \
    || fail "node_modules/.bin/firebase absent : lancer « npm ci » à la racine du dépôt."
}

# Paquet npm installé, par chemin relatif à node_modules (ex. « playwright-core »).
require_npm_package() {
  [[ -d "node_modules/$1" ]] \
    || fail "$1 absent : lancer « npm ci » à la racine du dépôt."
}

require_chrome() {
  local candidate
  for candidate in google-chrome google-chrome-stable chrome chromium; do
    command -v "$candidate" >/dev/null 2>&1 && return 0
  done
  [[ -d "/Applications/Google Chrome.app" ]] \
    || fail "Google Chrome introuvable (installé d'office sur les exécuteurs GitHub)."
}
