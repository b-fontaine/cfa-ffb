#!/usr/bin/env bash
# Hook Stop (Claude Code) — empêche de conclure tant que les garde-fous rapides échouent.
# Déterministe : appelle les mêmes scripts que les hooks git et la CI.
set -uo pipefail

input="$(cat)"
# Évite une boucle infinie : si on est déjà dans une relance due au hook, on laisse passer.
if [ "$(jq -r '.stop_hook_active // false' <<<"$input")" = "true" ]; then
  exit 0
fi

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$root" || exit 0

changed="$(git status --porcelain 2>/dev/null || true)"
fail=0
report=""

if grep -Eq ' (app|scripts)/' <<<"$changed" && [ -x scripts/check.sh ]; then
  if ! out="$(scripts/check.sh --fast 2>&1)"; then
    fail=1
    report+="scripts/check.sh --fast a échoué :\n$(tail -n 40 <<<"$out")\n"
  fi
fi

if grep -Eq ' seances/' <<<"$changed" && command -v dart >/dev/null 2>&1; then
  if ! out="$(dart run scripts/validate_seances.dart seances 2>&1)"; then
    fail=1
    report+="validate_seances a échoué :\n$(tail -n 40 <<<"$out")\n"
  fi
fi

if [ "$fail" -ne 0 ]; then
  printf '%b' "$report" >&2
  echo "Corriger les échecs ci-dessus avant de conclure (ne pas contourner les garde-fous)." >&2
  exit 2
fi
exit 0
