{{flutter_js}}
{{flutter_build_config}}

// Aucun réglage de service worker ici : celui de Flutter (obsolète, il se
// désinscrit lui-même) ne doit pas remplacer le nôtre. Le nôtre est enregistré
// par offline.js (voir docs/engineering/hors-ligne-plan.md).
_flutter.loader.load();
