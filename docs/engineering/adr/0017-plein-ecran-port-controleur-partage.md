# ADR 0017 — Plein écran : port `FullscreenController`, API Fullscreen via `dart:js_interop`, un seul contrôleur partagé

- Statut : **accepté et implémenté** (2026-10-16), points `[U]` au défaut proposé
  (U3-1 à U3-4). Plan : `../presentation-plan.md`. Lot **U3** de la
  [roadmap](../roadmap.md) ; solde F1. Prolonge le point d'accroche de
  [guide-mener-plan.md § 9](../guide-mener-plan.md).

## Contexte

La présentation montre un schéma aux élèves, souvent sur une tablette ou un
téléphone posé en salle. F1 : à 1280 × 800 la légende du bas était tronquée et
les commandes du lecteur coupées, parce que `RunPresentationView` bornait le
schéma par une mesure de texte (`TextPainter`) recopiant à la main les marges de
`PresentationScope`. Le plein écran, lui, n'existait pas (ni API Fullscreen web,
ni mode immersif mobile).

## Décision

1. **Port Dart pur** `FullscreenController` (`shared/lib`) : `isSupported`,
   `isActive`, `changes`, `enter`, `exit`. Les implémentations sont dans la
   couche `app` (`app/platform/`), choisies par import conditionnel
   (`dart.library.io` : natif ; sinon web). Le web est la valeur par défaut du
   conditionnel, ce qui laisse le contrôle de couverture voir le fichier web
   (non chargeable dans la machine virtuelle Dart) comme référencé.
2. **Aucune nouvelle dépendance** : `dart:js_interop` du SDK plutôt que
   `package:web` (seulement transitif ; le passer en direct est une décision de
   dépendance). La logique du web est isolée dans `WebFullscreenController`
   derrière une couture `FullscreenDocument` (testée en machine virtuelle) ; les
   liaisons d'interopérabilité tiennent dans `fullscreen_controller_web.dart`.
3. **L'entrée n'apparaît que si `isSupported`** : faux sur iPhone Safari (pas
   d'API) et sur le bureau natif (U3-1) ; en PWA `display: standalone` le plein
   écran est déjà obtenu (test au lot 15).
4. **Un seul contrôleur** (singleton get_it) lu par un `FullscreenCubit` jetable
   par écran : le plein écran est global à la séance et **fermer la présentation
   ne le quitte pas** (U3-2). Le raccourci `F` bascule dans la présentation
   seulement (U3-3). Échap est consommé par le navigateur en plein écran.
5. **`DiagramStage` remplace la mesure de texte** : la mise en page réserve
   d'abord titre, bandeau et légende à leur hauteur naturelle, le schéma reçoit
   le reste (au moins 304 dp pour un schéma de table avec ses commandes) ; un
   schéma qui ne tient pas grandit et la scène défile, l'en-tête et la barre
   basse restent en place. `TableDiagramPlayer.maxHeight` est conservé.
6. **« Tournez l'appareil »** : bandeau non bloquant, affiché en portrait quand la
   largeur borne le schéma (`isWidthLimited`, règle pure), fermable, réaffiché à
   chaque étape (U3-4).

## Alternatives rejetées

- `package:web` direct, `universal_html`, plugin `fullscreen` : dépendance de plus
  pour deux appels.
- Verrouillage d'orientation : on indique, on ne force pas.
- Un contrôleur par écran : le plein écran se perdrait à chaque navigation.
- Garder la mesure de texte : elle se désynchronise dès qu'un padding change
  (cause de F1).

## Conséquences

- `requestFullscreen` exige un geste de l'utilisateur : l'appel part dans le
  `onPressed` / la touche `F`, avant tout `await`.
- Le rendu `DiagramStage` ne sait pas calculer sa mise en page à sec (il contient
  un `LayoutBuilder`) : ne pas le placer sous un `IntrinsicHeight`.
- Non vérifiable automatiquement : iPhone Safari, PWA installée, Android natif
  (lot 15). Le web a été vérifié dans Chromium (clic réel, `F`, sortie par le
  navigateur, survie à la navigation).
