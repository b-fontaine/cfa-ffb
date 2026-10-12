#!/usr/bin/env bash
# Hook PreToolUse (Claude Code) — garde-fous déterministes, sans IA.
# Entrée : JSON sur stdin. Sortie : code 2 + message sur stderr = action bloquée.
set -euo pipefail

input="$(cat)"
tool="$(jq -r '.tool_name // ""' <<<"$input")"

block() {
  echo "BLOQUÉ par .claude/hooks/pre-tool-guard.sh : $1" >&2
  exit 2
}

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$input")"
    case "$path" in
      */docs/sources/*)
        block "docs/sources/ est en lecture seule (sources de rang 1)." ;;
      *.g.dart|*.freezed.dart|*.config.dart|*.steps.dart|*/app/lib/l10n/app_localizations*.dart)
        block "fichier généré : régénérer avec build_runner / flutter gen-l10n, ne pas éditer à la main." ;;
      */.claude/hooks/*|*/.claude/settings.json)
        block "la configuration des garde-fous ne se modifie pas depuis un agent ; demander à l'utilisateur." ;;
    esac
    ;;
  Bash)
    cmd="$(jq -r '.tool_input.command // ""' <<<"$input")"
    if grep -Eq -- '(^|[[:space:];&|])git[[:space:]]+(commit|push|merge|rebase|cherry-pick|am)\b.*(--no-verify|[[:space:]]-n([[:space:]]|$))' <<<"$cmd"; then
      block "contournement des hooks git interdit (--no-verify)."
    fi
    if grep -Eq -- 'git[[:space:]]+push\b.*(--force|[[:space:]]-f([[:space:]]|$))' <<<"$cmd"; then
      block "push --force interdit sans accord explicite de l'utilisateur."
    fi
    if grep -Eq -- '(rm|mv|git[[:space:]]+(checkout|restore|rm))[^;&|]*docs/sources' <<<"$cmd"; then
      block "docs/sources/ est en lecture seule."
    fi
    ;;
esac
exit 0
