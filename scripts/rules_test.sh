#!/usr/bin/env bash
# Tests des règles Firestore (lots FB1 et FB3) et de l'authentification (lot FB2) contre
# l'ÉMULATEUR (ADR 0024) : refus par défaut, grille rôle x action x collection, invitations,
# élévation de privilège, bornes, couverture du modèle (model.json), budget de get(), graine
# des émulateurs avec de vrais jetons, comportement de Firebase Auth.
#
#   scripts/rules_test.sh
#
# Lance `firebase emulators:exec` (Auth + Firestore, ports de firebase.json) puis
# `node --test --test-concurrency=1 scripts/rules_test/` (un fichier à la fois : ils
# partagent la même base d'émulateur). `RULES_FILE=copie.rules` fait tourner la suite sur une
# COPIE des règles (mutations à la main, docs/engineering/testing.md). Aucune requête n'atteint le projet Firebase
# réel : projet « demo-… » (émulateurs seuls), jamais de déploiement.
#
# Les écritures de l'import d'une sauvegarde (FB7, `import.test.mjs`) viennent de l'application :
# `app/tool/import_plan_fixture.dart` applique son planificateur à des sauvegardes FICTIVES et les
# écrit dans un dossier temporaire (IMPORT_PLAN_DIR) ; rien n'est versionné, rien ne peut dériver.
#
# Prérequis (échec explicite, code 1, jamais de saut silencieux) : Node >= 24.12,
# Java >= 21 (borne basse seule, imposée par firebase-tools 15 ; testé avec 27 en local, 21 en CI :
# voir docs/engineering/quality-gates.md), dépendances npm installées (`npm ci`).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Projet « demo- » : l'émulateur refuse toute connexion à un vrai projet.
RULES_TEST_PROJECT="${RULES_TEST_PROJECT:-demo-cfa-ffb}"
fail() {
  printf '\n✘ Tests des règles Firestore impossibles : %s\n' "$1" >&2
  printf '  Installation : scripts/setup.sh (voir docs/engineering/quality-gates.md)\n' >&2
  exit 1
}

source "$ROOT/scripts/lib/prereqs.sh"
require_node
require_java

command -v npx >/dev/null 2>&1 || fail "npx introuvable (npm requis)."
command -v dart >/dev/null 2>&1 || fail "dart introuvable (les écritures de l'import viennent de l'application)."

require_firebase_cli
require_npm_package @firebase/rules-unit-testing

# Écritures du plan d'import (outil de l'application, sauvegardes fictives).
IMPORT_PLAN_DIR="$(mktemp -d)"
trap 'rm -rf "$IMPORT_PLAN_DIR"' EXIT
(cd "$ROOT/app" && dart run tool/import_plan_fixture.dart "$IMPORT_PLAN_DIR" >/dev/null) \
  || fail "l'outil app/tool/import_plan_fixture.dart a échoué."
export IMPORT_PLAN_DIR

# firebase-tools du paquet (version épinglée), jamais le binaire global.
export PATH="$ROOT/node_modules/.bin:$PATH"
# Pas de télémétrie ni de mise à jour intrusive en CI / local.
export FIREBASE_CLI_DISABLE_UPDATE_CHECK=true

firebase emulators:exec \
  --project "$RULES_TEST_PROJECT" \
  --only auth,firestore \
  "node --test --test-concurrency=1 scripts/rules_test/"
