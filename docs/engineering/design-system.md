# Design system et Widgetbook

Décision : [ADR 0002](adr/0002-design-system-widgetbook.md). Recherches :
[identite-visuelle.md](research/identite-visuelle.md),
[widgetbook.md](research/widgetbook.md).

Le design system vit dans la couche `shared` de l'application
(`app/lib/shared/ui/`) et est documenté **et prévisualisé** dans le projet
Widgetbook séparé `widgetbook/`.

## Principes

- **Thème évoquant la FFB et le Blackball** : bleu FFB, rouge FFB assombri,
  tapis « bleu poudre », billes rouges/jaunes/noire/blanche, police Exo 2.
- **Aucun logo FFB** : la charte graphique encadre son usage (contact
  `site@ffbillard.com`). L'application se présente comme un outil
  d'animateur, jamais comme une application officielle de la fédération.
- **Un seul jeu de jetons** pour les publics enfants et adultes ; seules la
  densité (`AppTheme.light(density: …)`) et la taille du texte (réglage
  système, `TextScaleAddon` dans Widgetbook) varient.
- **Jamais la couleur seule** : une bille porte sa lettre (R/J/N ou R/Y/B/W
  selon la langue), une alerte porte une icône et un libellé de niveau, un
  score porte son texte `x/n`, un public porte une icône et son nom.
- **Accessibilité** : contrastes WCAG vérifiés par test, cibles tactiles
  ≥ 48 dp, texte ≥ 12 px (corps 14–16 px), titres exposés comme en-têtes
  sémantiques, étiquettes parlées localisées.

## Provenance des couleurs

| Jeton | Valeur | Statut |
|---|---|---|
| Bleu FFB (`primary` clair) | `#1964af` | **Publié** : charte graphique FFB v1.0 (2015) |
| Rouge FFB (référence) | `#e10a19` | **Publié** (4,93:1 sur blanc : trop juste pour du texte) |
| Rouge assombri (`secondary` clair) | `#b80d1a` | Proposition (dérivé du rouge FFB, 6,75:1) |
| Autres rôles `ColorScheme`, clair et sombre | voir `app_color_schemes.dart` | **Proposition** (non publiée par la FFB) |
| Billes : rouge `#d4101e`, jaune `#f2c200`, noire `#111111`, blanche `#ffffff` | `ball_colors.dart` | **Proposition** à valider visuellement par l'animateur |
| Tapis : `#7fb0cf` (clair), `#2d6a8a` (sombre) | `ball_colors.dart` | **Proposition** : le règlement FFB impose un drap « bleu poudre » sans valeur hexadécimale |
| Succès, attention (ambre) | `status_colors.dart` | **Proposition** |

Toute couleur « non publiée par la FFB » est une **proposition** : ne jamais la
présenter comme la couleur officielle.

## Où est quoi

```
app/lib/shared/ui/
├── theme/
│   ├── app_color_schemes.dart   # ColorScheme M3 explicite, clair + sombre (pas fromSeed)
│   ├── ball_colors.dart         # ThemeExtension : billes + tapis
│   ├── status_colors.dart       # ThemeExtension : succès, attention
│   ├── app_typography.dart      # échelle Exo 2 (axe wght de la police variable)
│   ├── app_spacing.dart         # AppSpacing (4/8/16/24/32, cible 48) et AppRadii (8/12/16)
│   └── app_theme.dart           # AppTheme.light() / AppTheme.dark()
├── score_indicator.dart         # score x/n : pastilles pleines/creuses + texte
├── ball_chip.dart               # pastille de bille avec lettre
├── section_card.dart            # carte de section (titre = en-tête sémantique)
├── page_header.dart             # titre + sous-titre de page
├── empty_state.dart             # état vide (icône, message, action)
├── audience_badge.dart          # badge enfants / adultes
├── app_alert.dart               # alerte attention / persistante
└── responsive_body.dart         # largeur maximale tablette/desktop/web
app/assets/fonts/                # Exo 2 (variable) + OFL.txt (licence SIL OFL 1.1)
app/test/unit/shared/ui/         # tests widget + contrastes (theme/contrast_test.dart)
widgetbook/                      # catalogue (projet séparé, voir ci-dessous)
```

La police Exo 2 vient de `github.com/google/fonts` (`ofl/exo2`) ; la licence
OFL est conservée à côté des fichiers et mentionnée dans `app/pubspec.yaml`.
Pas de téléchargement à l'exécution (Linux, Windows, web hors ligne).

## Règles d'usage

1. **Jamais de couleur ou de style en dur** dans les écrans : lire
   `Theme.of(context).colorScheme`, `textTheme` et les extensions
   (`BallColors`, `StatusColors`).
2. **Espacements et rayons** : constantes `AppSpacing` / `AppRadii`.
3. **Textes** : uniquement via `AppLocalizations` (clés `fr` **et** `en`,
   voir [i18n.md](i18n.md)). Un composant du design system reçoit ses textes
   métier en paramètre (`title`, `message`) et n'embarque que des libellés
   génériques localisés (nom de bille, niveau d'alerte).
4. **Indépendance du métier** : `shared/ui` n'importe aucune entité. Un
   composant exprime ses variantes avec ses propres enums (`BallKind`,
   `AudienceKind`, `AlertLevel`) ; la page mappe le domaine vers ces enums.
5. **Police dans Widgetbook** : l'application utilisée comme dépendance sert
   ses polices sous `packages/billard_cfa/Exo2` ; Widgetbook passe donc
   `AppTypography.packageFontFamily` à `AppTheme`.
6. Les billes ne sont jamais identifiées par la couleur seule (daltonisme).

## Garde-fou : contrastes

`app/test/unit/shared/ui/theme/contrast_test.dart` recalcule, avec la formule
WCAG 2.x, le ratio de chaque paire `onX/X` des deux schémas (et des extensions
billes/statuts) : **≥ 4,5:1** pour le texte, **≥ 3:1** pour `outline` contre la
surface. Il échoue si une valeur est modifiée sans respecter ces seuils.

## Ajouter un composant et son use case

1. **Comportement** : si le composant change ce que l'utilisateur voit dans
   l'application, écrire d'abord un scénario `.feature`
   (`app/test/bdd/`, voir [testing.md](testing.md)).
2. **Test widget rouge** dans `app/test/unit/shared/ui/<composant>_test.dart`
   (helper `pump_ui.dart` : thème + l10n fr/en), puis le composant minimal dans
   `app/lib/shared/ui/<composant>.dart` (TDD).
3. **Textes** : clés dans `app_fr.arb` **et** `app_en.arb`, puis
   `scripts/generate.sh`.
4. **Use case Widgetbook** dans `widgetbook/lib/use_cases/<composant>_use_cases.dart` :

   ```dart
   @widgetbook.UseCase(
     name: 'Interactif',
     type: MonComposant,
     path: '[Design system]/Composants',
   )
   Widget buildMonComposantUseCase(BuildContext context) =>
       MonComposant(label: context.knobs.string(label: 'label', initialValue: 'x'));
   ```

   Prévoir un use case interactif (knobs) et les états limites (vide, plein,
   erreur).
5. `scripts/generate_widgetbook.sh`, puis `scripts/check.sh --full` : le
   garde-fou `scripts/check_widgetbook.dart` échoue si un widget public de
   `shared/ui`, `widgets`, `pages` ou `features/*/presentation/ui` n'a aucun
   use case.

## Widgetbook

- Projet Flutter séparé `widgetbook/` (package `widgetbook_workspace`),
  dépendance `billard_cfa: path: ../app`. Il reste hors de la résolution de
  l'application : le générateur Widgetbook 3.x contraint `analyzer` (< 14) alors
  que `freezed` 4 exige `analyzer` ≥ 14 ; seules les dépendances d'exécution de
  l'app entrent dans la résolution de Widgetbook.
- Versions : `widgetbook ^3.25.0`, `widgetbook_annotation ^3.11.0`, dev
  `widgetbook_generator ^3.24.0` et `build_runner` (pas la 4.0 bêta).
- Addons : viewports (mobile, tablette, desktop), thème clair/sombre,
  localisation fr/en, échelle de texte, grille, inspecteur. `DeviceFrameAddon`
  et `AccessibilityAddon` sont dépréciés et non utilisés.
- Code généré (`lib/main.directories.g.dart`) : non versionné, produit par
  `scripts/generate_widgetbook.sh`. Le projet dépend du code généré de `app/`
  (freezed) : lancer d'abord `scripts/generate.sh`.

```bash
scripts/generate.sh && scripts/generate_widgetbook.sh   # code généré
cd widgetbook && flutter run -d chrome                  # catalogue en local
cd widgetbook && flutter build web                      # build de contrôle
dart run scripts/check_widgetbook.dart app widgetbook   # use cases complets
```

## Catalogue des pages et des composants du suivi

`widgetbook/lib/support/preview_world.dart` compose le graphe réel (dépôts en
mémoire, catalogue de l'asset, horloge figée au 12/10/2026) et amorce un club de
démonstration (une élève enfants avec passages réussis et manqués, un élève
adulte). Les use cases des pages et des vues du suivi
(`app_pages_use_cases.dart`, `feature_use_cases.dart`, `shared_ui_use_cases.dart`)
s'appuient sur ce monde via `WorldScope` / `LoadedScope`, avec les vrais Bloc.
