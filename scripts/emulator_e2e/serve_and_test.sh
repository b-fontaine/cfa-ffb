#!/usr/bin/env bash
# Exécuté PAR `firebase emulators:exec` (scripts/emulator_e2e.sh) : les variables des émulateurs
# (FIRESTORE_EMULATOR_HOST, FIREBASE_AUTH_EMULATOR_HOST, GCLOUD_PROJECT) sont déjà posées.
# Pose la graine, sert l'application en mode debug, joue le test, puis arrête l'application.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

E2E_PORT="${E2E_PORT:-8099}"
LOG="$(mktemp -t emulator_e2e_flutter.XXXXXX)"
FIFO_DIR="$(mktemp -d -t emulator_e2e_fifo.XXXXXX)"
FIFO="$FIFO_DIR/stdin"
APP_PID=""

cleanup() {
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    # « q » : arrêt propre de `flutter run` ; sinon on termine le processus.
    printf 'q\n' >&3 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$APP_PID" 2>/dev/null || break
      sleep 1
    done
    kill "$APP_PID" 2>/dev/null || true
  fi
  exec 3>&- 2>/dev/null || true
  rm -rf "$FIFO_DIR"
}
trap cleanup EXIT

node scripts/seed_emulator.mjs

# `flutter run` lit l'entrée standard (commandes interactives) : un tube la garde ouverte.
mkfifo "$FIFO"
exec 3<>"$FIFO"
# `--no-web-resources-cdn` : le moteur (CanvasKit) est servi en local, comme dans le build de
# production : le parcours n'a besoin d'aucun hôte autre que localhost (FB5a).
# Pas de `DATA_BACKEND` : le défaut est Firestore (bascule du 2026-10-21), comme en production.
(cd app && flutter run -d web-server --web-port "$E2E_PORT" --no-pub --no-web-resources-cdn \
  --dart-define=FIREBASE_EMULATOR=true <"$FIFO" >"$LOG" 2>&1) &
APP_PID=$!

printf 'Compilation de l'"'"'application (mode debug)…\n'
for _ in $(seq 1 600); do
  grep -q 'is being served at' "$LOG" 2>/dev/null && break
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    cat "$LOG" >&2
    echo "✘ flutter run s'est arrêté avant de servir l'application." >&2
    exit 1
  fi
  sleep 1
done
grep -q 'is being served at' "$LOG" || { cat "$LOG" >&2; echo "✘ L'application n'est pas servie après 10 minutes." >&2; exit 1; }

E2E_URL="http://127.0.0.1:${E2E_PORT}" node --test ${E2E_NODE_ARGS:-} scripts/emulator_e2e/*.test.mjs
