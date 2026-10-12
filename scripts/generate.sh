#!/usr/bin/env bash
# Génère le code (build_runner : freezed/injectable/bdd_widget_test) et les
# localisations (gen-l10n). Les fichiers générés ne sont PAS versionnés.
set -euo pipefail
cd "$(dirname "$0")/../app"

flutter pub get ${CI:+--enforce-lockfile}
flutter gen-l10n
dart run build_runner build

# Les tests BDD générés sont formatés à la source : `dart format` sur test/
# reste propre juste après une génération.
if compgen -G "test/bdd/*_test.dart" >/dev/null; then
  dart format test/bdd/*_test.dart >/dev/null
fi
