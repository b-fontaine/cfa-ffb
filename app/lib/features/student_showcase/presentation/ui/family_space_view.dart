import 'package:billard_cfa/features/student_showcase/domain/family_space.dart';
import 'package:billard_cfa/features/student_showcase/presentation/ui/showcase_view.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/ui/empty_state.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// L'espace d'un parent ou d'un élève, en lecture seule : le sélecteur
/// d'enfant (dès deux élèves liés), le parcours de l'élève choisi (la vue « à
/// montrer à l'élève ») et les prochaines séances de ses groupes. Aucun bouton
/// d'écriture : aucune action ne s'y trouve.
class FamilySpaceView extends StatelessWidget {
  const FamilySpaceView({
    required this.space,
    required this.selected,
    required this.onSelect,
    this.stale = false,
    super.key,
  });

  final FamilySpace space;

  /// L'élève affiché ; `null` ou inconnu : le premier.
  final StudentId? selected;
  final ValueChanged<StudentId> onSelect;

  /// Les dernières données reçues, faute de joindre le serveur.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = space.children;
    if (children.isEmpty) return EmptyState(message: l10n.childrenEmpty);
    final shown = children.firstWhere(
      (child) => child.id == selected,
      orElse: () => children.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale) ...[
          _Note(icon: Icons.cloud_off_outlined, text: l10n.familyStaleNote),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (children.length > 1) ...[
          ChildSelector(
            children: children,
            selected: shown.id,
            onSelect: onSelect,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // La clé lie l'affichage à l'élève : jamais le même état de widget
        // pour deux élèves.
        KeyedSubtree(
          key: ValueKey(shown.id.value),
          child: ShowcaseView(showcase: shown.showcase),
        ),
        const SizedBox(height: AppSpacing.lg),
        UpcomingFamilySessions(sessions: space.upcoming),
        const SizedBox(height: AppSpacing.md),
        _Note(icon: Icons.visibility_outlined, text: l10n.familyReadOnlyNote),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// Le choix de l'enfant : une puce par élève lié (initiale et prénom), cible
/// de 48 dp au moins, l'élève affiché est annoncé « sélectionné ».
class ChildSelector extends StatelessWidget {
  const ChildSelector({
    required this.children,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<FamilyChild> children;
  final StudentId selected;
  final ValueChanged<StudentId> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ranks = homonymRanks(children);
    return Semantics(
      container: true,
      label: l10n.familyChildSelectorLabel,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final child in children)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: ChoiceChip(
                key: ValueKey('child-${child.id.value}'),
                avatar: ExcludeSemantics(
                  child: CircleAvatar(child: _initial(child.firstName)),
                ),
                label: Text(_label(l10n, child, ranks[child.id])),
                selected: child.id == selected,
                onSelected: (_) => onSelect(child.id),
              ),
            ),
        ],
      ),
    );
  }

  static String _label(AppLocalizations l10n, FamilyChild child, int? rank) =>
      rank == null
      ? child.firstName
      : l10n.familyChildHomonym(child.firstName, rank);

  /// L'initiale du prénom ; une icône quand il est vide.
  static Widget _initial(String name) => name.isEmpty
      ? const Icon(Icons.person_outline)
      : Text(name.characters.first.toUpperCase());
}

/// Les prochaines séances des groupes du compte : le titre, le jour et le
/// groupe. Aucune liste de présents ni de camarades, aucune saisie.
class UpcomingFamilySessions extends StatelessWidget {
  const UpcomingFamilySessions({required this.sessions, super.key});

  final List<FamilySession> sessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    return SectionCard(
      title: l10n.familyUpcomingTitle,
      child: sessions.isEmpty
          ? Text(l10n.familyUpcomingEmpty, style: theme.textTheme.bodyLarge)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final session in sessions)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Semantics(
                      container: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            session.groupName == null
                                ? dates.formatMediumDate(session.date)
                                : l10n.familySessionLine(
                                    dates.formatMediumDate(session.date),
                                    session.groupName!,
                                  ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Un message sobre : « accès refusé » ou « accès retiré » (icône, titre et
/// explication, jamais la couleur seule). Aucune action : le parent n'a rien à
/// écrire, il se reconnecte ou contacte son club.
class FamilyNotice extends StatelessWidget {
  const FamilyNotice({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
