# ADR 0002 — Design system et Widgetbook 3.x en projet séparé

- Statut : accepté (2026-10-11), d'après `research/widgetbook.md` et `research/identite-visuelle.md`.
- Décision :
  1. **Widgetbook 3.x stable** (pas la 4.0 bêta) dans un projet Flutter **séparé** `widgetbook/` avec dépendance `path` vers `app/` (conflit `analyzer` possible avec freezed 4 si mêlé).
  2. Thème Material 3 **explicite** (pas `fromSeed`) : bleu FFB `#1964af`, rouge FFB assombri pour le texte `#b80d1a`, tapis « bleu poudre » (règlement Blackball FFB), `ThemeExtension` pour les billes (rouge/jaune/noire/blanche) et le tapis.
  3. Typographie **Exo 2** (charte FFB, licence OFL) embarquée en assets.
  4. Un test unitaire recalcule les contrastes WCAG (≥ 4,5:1 texte, ≥ 3:1 composants).
  5. **Ne pas intégrer le logo FFB** (charte : usage encadré, contact site@ffbillard.com) ; l'application se présente comme un outil d'animateur, pas comme une application officielle.
- Alerte : ne jamais coder un groupe de billes par la couleur seule (daltonisme) : ajouter lettre/icône.
- Les valeurs hexadécimales des billes et du tapis sont des **propositions** non publiées par la FFB.
