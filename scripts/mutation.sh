#!/usr/bin/env bash
# Mutation testing (package mutation_test) sur une COPIE TEMPORAIRE de app/.
#
#   scripts/mutation.sh                      mutation complète (tous les fichiers lib/)
#   scripts/mutation.sh --changed [base-ref] seulement les fichiers lib/**.dart modifiés
#                                            (git diff vs le merge-base avec base-ref,
#                                            défaut HEAD, + fichiers non suivis)
#   scripts/mutation.sh --files lib/a.dart…  seulement ces fichiers (chemins relatifs à app/)
#   scripts/mutation.sh --jobs N             nombre de workers, chacun sa copie (défaut : 1 ;
#                                            plafonné à nproc-2)
#
# L'arbre de travail n'est JAMAIS modifié : chaque worker mute sa propre copie
# (mktemp -d, nettoyée par trap même en cas d'échec). Le seuil est celui de
# app/mutation-test.xml, appliqué au score GLOBAL (somme des workers).
# Rapports : app/build/mutation-report/ (summary.md + part-N/mutation-test-report.html).
#
# Variables : MUTATION_JOBS (idem --jobs), MUTATION_TEST_CONCURRENCY
# (--concurrency de `flutter test` dans chaque worker ; défaut : cœurs / workers).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
XML="$APP/mutation-test.xml"
REPORT="$APP/build/mutation-report"

MODE=full
BASE=HEAD
EXPLICIT=()
JOBS="${MUTATION_JOBS:-}"

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --changed)
      MODE=changed
      if [[ $# -gt 1 && "$2" != --* ]]; then BASE="$2"; shift; fi
      ;;
    --files)
      MODE=files; shift
      while [[ $# -gt 0 && "$1" != --* ]]; do EXPLICIT+=("$1"); shift; done
      [[ ${#EXPLICIT[@]} -gt 0 ]] || { echo "--files attend des chemins" >&2; exit 2; }
      continue
      ;;
    --jobs)
      [[ $# -gt 1 ]] || { echo "--jobs attend un nombre" >&2; exit 2; }
      JOBS="$2"; shift
      ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Argument inconnu : $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# --- Fichiers à muter (chemins relatifs à app/) ------------------------------
# Miroir des <exclude> de mutation-test.xml : code généré, point d'entrée, câblage.
filter_sources() {
  grep -E '^lib/.*\.dart$' \
    | grep -Ev '\.(g|freezed|config|steps)\.dart$' \
    | grep -Ev '^lib/shared/l10n/generated/' \
    | grep -Ev '^lib/(main\.dart|app/di/injection\.dart)$' \
    | sort -u || true
}

list_sources() {
  cd "$APP"
  if [[ "$MODE" == "full" ]]; then
    find lib -name '*.dart' | filter_sources
    return
  fi
  if [[ "$MODE" == "files" ]]; then
    printf '%s\n' "${EXPLICIT[@]}" | filter_sources
    return
  fi
  local ref
  ref="$(git -C "$ROOT" merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")"
  {
    git -C "$ROOT" diff --name-only --diff-filter=d "$ref" -- app/lib
    git -C "$ROOT" ls-files --others --exclude-standard -- app/lib
  } | sed 's#^app/##' | while IFS= read -r file; do
    [[ -f "$file" ]] && printf '%s\n' "$file"
  done | filter_sources
}

FILES=()
while IFS= read -r file; do FILES+=("$file"); done < <(list_sources)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Mutation : aucun fichier lib/**.dart à muter ($MODE) - rien à faire."
  exit 0
fi

# --- Code généré nécessaire aux tests ----------------------------------------
if [[ ! -f "$APP/lib/app/di/injection.config.dart" || ! -d "$APP/lib/shared/l10n/generated" ]]; then
  "$ROOT/scripts/generate.sh" >/dev/null
fi

# --- Parallélisme -------------------------------------------------------------
CORES="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)"
MAX_JOBS=$((CORES - 2))
[[ $MAX_JOBS -ge 1 ]] || MAX_JOBS=1
# Défaut 1 : mesuré, des copies parallèles n'accélèrent pas (les tests exploitent
# déjà tous les cœurs ; voir docs/engineering/quality-gates.md).
[[ -n "$JOBS" ]] || JOBS=1
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "Nombre de workers invalide : $JOBS" >&2; exit 2; }
[[ $JOBS -le $MAX_JOBS ]] || JOBS="$MAX_JOBS"

THRESHOLD="$(sed -n 's/.*<threshold[^>]*failure="\([0-9.]*\)".*/\1/p' "$XML" | head -1)"
[[ -n "$THRESHOLD" ]] || { echo "Seuil introuvable dans $XML" >&2; exit 2; }

# --- Copies temporaires + nettoyage garanti -----------------------------------
WORK="$(mktemp -d "${TMPDIR:-/tmp}/mutation.XXXXXX")"
PIDS=()
cleanup() {
  local pid cwd proc
  for pid in "${PIDS[@]:-}"; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
  done
  # Les workers lancent dart/flutter : tuer aussi les processus qui travaillent
  # dans les copies temporaires (Linux : /proc/<pid>/cwd).
  for proc in /proc/[0-9]*; do
    cwd="$(readlink "$proc/cwd" 2>/dev/null || true)"
    if [[ "$cwd" == "$WORK"/* ]]; then kill "${proc#/proc/}" 2>/dev/null || true; fi
  done
  rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

tree_fingerprint() {
  (cd "$APP" && find lib test tool -type f -print0 | sort -z | xargs -0 cksum | cksum)
}
BEFORE="$(tree_fingerprint)"

# --- Répartition par mutant ----------------------------------------------------
# Un passage à blanc (--dry : aucune écriture, aucun test) énumère les mutants
# (fichier, lignes) ; ils sont répartis entre workers par bloc de lignes,
# gloutonnement (le bloc le plus lourd vers le worker le moins chargé).
make_xml() { # make_xml <plan "fichier<TAB>début<TAB>fin"> <seuil> <concurrence|""> : XML sur stdout
  awk -F'\t' -v plan="$1" -v threshold="$2" -v conc="$3" '
    BEGIN {
      while ((getline row < plan) > 0) {
        split(row, c, "\t")
        if (!(c[1] in seen)) { order[++n] = c[1]; seen[c[1]] = 1 }
        lines[c[1]] = lines[c[1]] "      <lines begin=\"" c[2] "\" end=\"" c[3] "\"/>\n"
      }
    }
    /<files>/ {
      print "  <files>"
      for (i = 1; i <= n; i++) printf "    <file>%s\n%s    </file>\n", order[i], lines[order[i]]
      print "  </files>"; skip = 1; next
    }
    skip && /<\/files>/ { skip = 0; next }
    skip { next }
    /<threshold/ { print "  <threshold failure=\"" threshold "\"/>"; next }
    conc != "" && /flutter test/ { sub(/flutter test --no-pub/, "flutter test --no-pub --concurrency=" conc) }
    { print }
  ' "$XML"
}

printf '%s\n' "${FILES[@]}" >"$WORK/all-files.txt"
echo "Énumération des mutants (passage à blanc)…"
(
  cd "$APP"
  awk -v list="$WORK/all-files.txt" '
    /<files>/ { print "  <files>"; while ((getline f < list) > 0) print "    <file>" f "</file>"; print "  </files>"; skip = 1; next }
    skip && /<\/files>/ { skip = 0; next }
    skip { next }
    { print }
  ' "$XML" >"$WORK/dry.xml"
  # En --dry tout mutant est « non détecté » : le code de sortie est donc 255 ;
  # seul le rapport compte.
  dart run mutation_test "$WORK/dry.xml" --exclude-strings --dry -q -f xml \
    -o "$WORK/dry" >"$WORK/dry.log" 2>&1 || true
)
[[ -f "$WORK/dry/mutation-test-report.xml" ]] || {
  echo "Mutation : énumération des mutants impossible :" >&2
  cat "$WORK/dry.log" >&2
  exit 1
}
# mutation_test n'accepte un mutant que si TOUT son texte est dans une plage
# <lines> : on découpe donc en blocs de lignes disjoints (les plages des mutants
# qui se chevauchent sont fusionnées), chaque bloc allant à un seul worker.
# Sortie : "fichier<TAB>début<TAB>fin<TAB>nb mutants", triée par nb décroissant.
awk '
  /<file name=/ { match($0, /name="[^"]+"/); file = substr($0, RSTART + 6, RLENGTH - 7) }
  /<mutation line=/ { match($0, /line="[0-9]+"/); start = substr($0, RSTART + 6, RLENGTH - 7) + 0; extra = 0; inside = 0 }
  /<original>/ {
    inside = 1
    if ($0 ~ /<\/original>/) { print file "\t" start "\t" start; inside = 0 }
    next
  }
  inside {
    extra++
    if ($0 ~ /<\/original>/) { print file "\t" start "\t" start + extra; inside = 0 }
  }
' "$WORK/dry/mutation-test-report.xml" \
  | sort -t$'\t' -k1,1 -k2,2n -k3,3n \
  | awk -F'\t' '
      function flush() { if (file != "") print file "\t" begin "\t" end "\t" count }
      $1 != file || $2 > end { flush(); file = $1; begin = $2; end = $3; count = 0 }
      { if ($3 > end) end = $3; count++ }
      END { flush() }
    ' \
  | sort -t$'\t' -k4,4nr -k1,1 -k2,2n >"$WORK/mutants.tsv"
TOTAL_MUTANTS="$(awk -F'\t' '{ n += $4 } END { print n + 0 }' "$WORK/mutants.tsv")"
if [[ "$TOTAL_MUTANTS" -eq 0 ]]; then
  echo "Mutation : aucun mutant à tester."
  exit 0
fi
BLOCKS="$(wc -l <"$WORK/mutants.tsv")"
[[ $JOBS -le $BLOCKS ]] || JOBS="$BLOCKS"
# Les cœurs sont partagés entre workers : N workers x C processus de test.
CONCURRENCY="${MUTATION_TEST_CONCURRENCY:-$((CORES / JOBS))}"
[[ $CONCURRENCY -ge 1 ]] || CONCURRENCY=1

awk -F'\t' -v jobs="$JOBS" -v work="$WORK" '
  BEGIN { for (k = 0; k < jobs; k++) { load[k] = 0; printf "" > (work "/plan-" k ".tsv") } }
  {
    best = 0
    for (k = 1; k < jobs; k++) if (load[k] < load[best]) best = k
    load[best] += $4
    print $1 "\t" $2 "\t" $3 >> (work "/plan-" best ".tsv")
  }
' "$WORK/mutants.tsv"

rm -rf "$REPORT"
mkdir -p "$REPORT"

echo "Mutation ($MODE) : ${#FILES[@]} fichier(s), $TOTAL_MUTANTS mutants, $JOBS worker(s), seuil global $THRESHOLD %."
START="$(date +%s)"

run_worker() {
  local k="$1" dir="$WORK/w$k"
  mkdir -p "$dir"
  rsync -a --exclude build/ --exclude coverage/ "$APP/" "$dir/app/"
  rsync -a "$ROOT/scripts/" "$dir/scripts/"
  # Même configuration que mutation-test.xml, restreinte aux lignes du worker,
  # sans seuil local (le seuil s'applique au total).
  make_xml "$WORK/plan-$k.tsv" 0 "$CONCURRENCY" >"$dir/app/mutation-worker.xml"
  (
    cd "$dir/app"
    dart run mutation_test mutation-worker.xml --exclude-strings -f all \
      -o "$REPORT/part-$k" >"$WORK/worker-$k.log" 2>&1
  )
}

for ((k = 0; k < JOBS; k++)); do
  run_worker "$k" &
  PIDS+=("$!")
done

FAILED=0
for ((k = 0; k < JOBS; k++)); do
  if wait "${PIDS[k]}"; then
    echo "  worker $k terminé ($(sed -n 's/^Total tests: //p' "$WORK/worker-$k.log" | head -1) mutations)"
  else
    echo "  worker $k EN ÉCHEC :" >&2
    tail -n 25 "$WORK/worker-$k.log" >&2
    FAILED=1
  fi
done
[[ $FAILED -eq 0 ]] || { echo "Mutation : au moins un worker a échoué." >&2; exit 1; }

echo "Durée : $(($(date +%s) - START)) s"

# L'arbre de travail doit être strictement identique.
AFTER="$(tree_fingerprint)"
if [[ "$BEFORE" != "$AFTER" ]]; then
  echo "Mutation : l'arbre de travail a été modifié (lib/test/tool) !" >&2
  exit 1
fi

cd "$ROOT"
dart run scripts/mutation_report.dart "$THRESHOLD" "$REPORT" "$TOTAL_MUTANTS"
