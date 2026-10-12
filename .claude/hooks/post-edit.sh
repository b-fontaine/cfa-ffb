#!/usr/bin/env bash
# Hook PostToolUse (Claude Code) — formate automatiquement le fichier Dart édité.
# Déterministe : `dart format`. Ne bloque jamais (le contrôle strict est dans scripts/check.sh).
set -uo pipefail

input="$(cat)"
path="$(jq -r '.tool_input.file_path // ""' <<<"$input")"

case "$path" in
  *.dart)
    case "$path" in
      *.g.dart|*.freezed.dart|*.config.dart|*.steps.dart) exit 0 ;;
    esac
    if [ -f "$path" ] && command -v dart >/dev/null 2>&1; then
      dart format "$path" >/dev/null 2>&1 || true
    fi
    ;;
esac
exit 0
