#!/usr/bin/env bash
# Build web de production : UNE seule recette pour la CI et le déploiement.
#
#   scripts/build_web.sh [options de flutter build web]
#
# - `--no-web-resources-cdn` : CanvasKit est servi par l'application (dossier
#   canvaskit/), pas par le CDN de Google : requis pour fonctionner hors ligne ;
# - `scripts/pwa.dart stamp` : écrit la version et la liste de précache dans le
#   service worker hors ligne ; `verify` contrôle le résultat.
# - le backend des données est celui du build : Firestore par défaut (bascule du
#   2026-10-21) ; `--dart-define=DATA_BACKEND=drift` construit le build local
#   (prévisualisations de PR, fumée du navigateur, base locale des essais).
# Prérequis : le code généré existe (scripts/generate.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$ROOT/app" && flutter build web --release --no-pub --no-web-resources-cdn "$@")
(cd "$ROOT" && dart run scripts/pwa.dart stamp && dart run scripts/pwa.dart verify)
