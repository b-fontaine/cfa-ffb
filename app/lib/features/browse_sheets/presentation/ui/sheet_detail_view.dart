import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/entities/session_sheet/domain/needs_review.dart';
import 'package:billard_cfa/entities/session_sheet/domain/scoring.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_initiation.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_source.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theory.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/entities/session_sheet/presentation/sheet_illustration_view.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_detail.dart';
import 'package:billard_cfa/features/browse_sheets/domain/sheet_row.dart';
import 'package:billard_cfa/features/browse_sheets/presentation/ui/review_labels.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/provenance.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:billard_cfa/shared/ui/audience_labels.dart';
import 'package:billard_cfa/shared/ui/french_content_notice.dart';
import 'package:billard_cfa/shared/ui/phase_timeline.dart';
import 'package:billard_cfa/shared/ui/proposal_badge.dart';
import 'package:billard_cfa/shared/ui/provenance_badge.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_player.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart'
    as ui;
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

part 'sheet_detail_sections.dart';

/// Une séance du catalogue, lue en entier : rappel, théorie illustrée,
/// exercices (mise en place, schéma, consigne, attendu), jeu, bilan et
/// sources.
///
/// Le public ([audience]) ne change que les minutes (calculées, `[Prop]`) et
/// les éléments propres à un public. Chaque élément non sourcé porte le badge
/// « Proposition » en contexte ; les éléments sourcés portent leur source.
/// Aucun champ de saisie : seule la bascule de public et la frise des phases
/// agissent.
///
/// La frise des phases, sous la bascule de public, est le sommaire : taper un
/// segment fait défiler la page parente jusqu'à la phase choisie. Dès 720 dp
/// de fenêtre, la carte d'un exercice passe sur deux colonnes (schéma à
/// gauche).
class SheetDetailView extends StatefulWidget {
  const SheetDetailView({
    required this.detail,
    required this.audience,
    required this.onAudienceChanged,
    super.key,
  });

  final SheetDetail detail;
  final Audience audience;
  final ValueChanged<Audience> onAudienceChanged;

  @override
  State<SheetDetailView> createState() => _SheetDetailViewState();
}

class _SheetDetailViewState extends State<SheetDetailView> {
  final Map<SessionPhase, GlobalKey> _phaseKeys = {
    for (final phase in SessionPhase.values) phase: GlobalKey(),
  };

  void _jumpTo(SessionPhase phase) {
    final target = _phaseKeys[phase]!.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = widget.detail;
    final sheet = detail.sheet;
    final audience = widget.audience;
    final timing = detail.timings[audience]!;
    final scope = _SheetScope(
      detail: detail,
      audience: audience,
      timing: timing,
      specs: {
        for (final entry in detail.diagrams.entries)
          entry.key: tableDiagramSpecOf(entry.value),
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Readable(child: FrenchContentNotice()),
        const SizedBox(height: AppSpacing.md),
        _Readable(child: _ThemeBlock(sheet: sheet)),
        const SizedBox(height: AppSpacing.md),
        if (needsReview(sheet)) ...[
          _Readable(
            child: _ToValidateNote(
              row: sheetRowOf(sheet, partCount: detail.partCount),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        _Readable(
          child: _AudienceBar(
            audience: audience,
            total: timing.total,
            onChanged: widget.onAudienceChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Readable(
          child: PhaseTimeline(
            phases: [
              for (final phase in SessionPhase.values)
                PhaseTimelineEntry(
                  label: _timelineLabel(l10n, phase, sheet.previous == null),
                  minutes: timing.phaseMinutes[phase]!,
                ),
            ],
            currentIndex: -1,
            onSelected: (index) => _jumpTo(SessionPhase.values[index]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _PhaseSection(
          sectionKey: _phaseKeys[SessionPhase.welcome]!,
          phase: SessionPhase.welcome,
          minutes: timing.phaseMinutes[SessionPhase.welcome]!,
          title: sheet.previous == null
              ? l10n.suggestPhaseWelcome
              : l10n.sheetPhaseRecall,
          children: [_RecallContent(scope: scope)],
        ),
        _PhaseSection(
          sectionKey: _phaseKeys[SessionPhase.notionAndInitiation]!,
          phase: SessionPhase.notionAndInitiation,
          minutes: timing.phaseMinutes[SessionPhase.notionAndInitiation]!,
          title: l10n.suggestPhaseNotion,
          children: [
            for (final section in sheet.theorySections)
              if (section.weight.isShownFor(audience))
                _TheoryCard(scope: scope, section: section),
            for (final item in sheet.initiation)
              if (item.weight.isShownFor(audience))
                _InitiationCard(scope: scope, item: item),
          ],
        ),
        _PhaseSection(
          sectionKey: _phaseKeys[SessionPhase.training]!,
          phase: SessionPhase.training,
          minutes: timing.phaseMinutes[SessionPhase.training]!,
          title: l10n.suggestPhaseTraining,
          children: [
            for (final exercise in sheet.exercises)
              if (exercise.weight.isShownFor(audience))
                _ExerciseCard(scope: scope, exercise: exercise),
          ],
        ),
        _PhaseSection(
          sectionKey: _phaseKeys[SessionPhase.game]!,
          phase: SessionPhase.game,
          minutes: timing.phaseMinutes[SessionPhase.game]!,
          title: l10n.suggestPhaseGame,
          children: [_GameCard(scope: scope)],
        ),
        _PhaseSection(
          sectionKey: _phaseKeys[SessionPhase.review]!,
          phase: SessionPhase.review,
          minutes: timing.phaseMinutes[SessionPhase.review]!,
          title: l10n.suggestPhaseReview,
          children: [_ReviewContent(sheet: sheet)],
        ),
        _Readable(child: _SourcesSection(sheet: sheet)),
      ],
    );
  }
}
