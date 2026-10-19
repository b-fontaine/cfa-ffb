#!/usr/bin/env bash
# Échoue tôt, avec un message clair, si un port des émulateurs Firebase est déjà
# pris (typiquement un émulateur résiduel d'une exécution interrompue) : sans ce
# contrôle, `check.sh --full` ne le découvre qu'à l'étape « Règles Firestore »
# (« Could not start Firestore Emulator, port taken »).
#
#   scripts/check_ports_free.sh            ports de firebase.json (emulators.*.port)
#   scripts/check_ports_free.sh 8080 9099  ports donnés
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if (( $# > 0 )); then
  ports=("$@")
else
  mapfile -t ports < <(node -e '
    const e = require(process.argv[1]).emulators ?? {};
    for (const c of Object.values(e)) if (c && typeof c === "object" && c.port) console.log(c.port);
  ' "$ROOT/firebase.json")
fi

busy=0
for port in "${ports[@]}"; do
  # Connexion réussie = quelqu'un écoute. Trois adresses : un émulateur peut
  # n'écouter que sur ::1 (localhost résolu en IPv6) ou sur toutes les
  # interfaces ; une sonde 127.0.0.1 seule le manquerait.
  taken=0
  for host in 127.0.0.1 ::1 0.0.0.0; do
    if (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then taken=1; break; fi
  done
  if (( taken )); then
    printf '✘ Port %s déjà pris : un émulateur Firebase résiduel tourne peut-être (java, firebase emulators).\n' "$port" >&2
    printf '  Identifier : ss -ltnp | grep :%s ; l'"'"'arrêter, puis relancer.\n' "$port" >&2
    busy=1
  fi
done
exit "$busy"
