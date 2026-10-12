#!/usr/bin/env bash
# Génère le code de Widgetbook (build_runner : main.directories.g.dart).
# Prérequis : le code généré de app/ existe (scripts/generate.sh), car le
# projet Widgetbook dépend de app/ par chemin.
set -euo pipefail
cd "$(dirname "$0")/../widgetbook"

flutter pub get ${CI:+--enforce-lockfile}
dart run build_runner build --delete-conflicting-outputs
