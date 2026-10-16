#!/usr/bin/env bash
# Point d'entrée UNIQUE des garde-fous déterministes (hooks, agent, CI).
#
#   scripts/check.sh --fast   catalogue + diagrammes + fiches + fichiers web drift + PWA (+ tests JS du service worker, Node) + format + analyse
#                             + architecture + séances + validation des fiches
#   scripts/check.sh --full   --fast + l10n + tests + couverture + Widgetbook
#                             (génération, format, analyse, use cases)
#
# --fast est en LECTURE SEULE sur les sources (dart format --output=none) ; la
# preuve est dans app/test/tool/check_fast_read_only_test.dart.
#
# Variable : COVERAGE_MIN (défaut 90).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:---fast}"
COVERAGE_MIN="${COVERAGE_MIN:-90}"

case "$MODE" in
  --fast | --full) ;;
  *) echo "Usage : scripts/check.sh [--fast|--full]" >&2; exit 2 ;;
esac

step() { printf '\n▶ %s\n' "$1"; }

cd "$ROOT/app"

# Le code généré n'est pas versionné : le produire s'il manque (ou en --full).
if [[ "$MODE" == "--full" || ! -f lib/app/di/injection.config.dart \
  || ! -d lib/shared/l10n/generated || -z "$(ls test/bdd/*_test.dart 2>/dev/null)" ]]; then
  step "Génération de code (freezed, injectable, bdd, l10n)"
  "$ROOT/scripts/generate.sh" >/dev/null
fi

step "Catalogue (asset identique à docs/knowledge)"
"$ROOT/scripts/sync_catalogue.sh" --check

step "Diagrammes (assets identiques à docs/knowledge)"
"$ROOT/scripts/sync_diagrammes.sh" --check

step "Fiches de séance (assets identiques à docs/knowledge)"
"$ROOT/scripts/sync_fiches.sh" --check

step "Fichiers web drift (sqlite3.wasm, drift_worker.js)"
(cd "$ROOT" && dart run scripts/sync_web_assets.dart --check)

step "PWA (manifeste, service worker hors ligne, icônes, aucune ressource externe)"
(cd "$ROOT" && dart run scripts/pwa.dart check && dart run scripts/generate_pwa_icons.dart --check)

step "Service worker et pont de mise à jour (comportement, node --test)"
node --test "$ROOT/scripts/pwa_js_test.mjs"

step "Formatage (dart format --set-exit-if-changed)"
FILES=()
while IFS= read -r file; do FILES+=("$file"); done < <(find lib test tool -name '*.dart' \
  ! -name '*.g.dart' ! -name '*.freezed.dart' ! -name '*.config.dart' ! -name '*.steps.dart' \
  ! -path 'lib/shared/l10n/generated/*' ! -path 'test/bdd/*_test.dart')
dart format --output=none --set-exit-if-changed "${FILES[@]}" "$ROOT/scripts"/*.dart

step "Analyse statique (flutter analyze --fatal-infos)"
flutter analyze --no-pub --fatal-infos

step "Analyse des scripts Dart"
(cd "$ROOT" && dart analyze --fatal-infos scripts)

step "Architecture FSD + Clean"
dart run tool/check_architecture.dart

step "Séances (front matter, durées, déroulé)"
(cd "$ROOT" && dart run scripts/validate_seances.dart seances)

step "Fiches de séance (FORMAT.md § 7, 28 séances, lecture seule)"
dart run tool/fiches.dart --complete

if [[ "$MODE" == "--fast" ]]; then
  printf '\n✔ check --fast OK\n'
  exit 0
fi

step "Localisations fr/en (mêmes clés)"
(cd "$ROOT" && dart run scripts/check_l10n.dart app/lib/shared/l10n)

step "Tests (BDD + unitaires) avec couverture"
rm -rf coverage
flutter test --no-pub --coverage --reporter failures-only

step "Couverture ≥ ${COVERAGE_MIN} %"
(cd "$ROOT" && dart run scripts/check_coverage.dart "$COVERAGE_MIN" app)

step "Widgetbook (génération, format, analyse, use cases)"
"$ROOT/scripts/generate_widgetbook.sh" >/dev/null
(
  cd "$ROOT/widgetbook"
  WB_FILES=()
  while IFS= read -r file; do WB_FILES+=("$file"); done < <(find lib -name '*.dart' ! -name '*.g.dart')
  dart format --output=none --set-exit-if-changed "${WB_FILES[@]}"
  flutter analyze --no-pub --fatal-infos
)
(cd "$ROOT" && dart run scripts/check_widgetbook.dart app widgetbook)


printf '\n✔ check --full OK\n'
