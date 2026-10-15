import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_result/domain/exercise_attempt.dart';
import 'package:billard_cfa/features/record_results/domain/recorded_attempt.dart';
import 'package:billard_cfa/shared/l10n/generated/app_localizations.dart';
import 'package:billard_cfa/shared/lib/success_rate.dart';
import 'package:billard_cfa/shared/ui/app_alert.dart';
import 'package:billard_cfa/shared/ui/counter_field.dart';
import 'package:billard_cfa/shared/ui/pass_dots.dart';
import 'package:billard_cfa/shared/ui/section_card.dart';
import 'package:billard_cfa/shared/ui/status_badge.dart';
import 'package:billard_cfa/shared/ui/student_chip.dart';
import 'package:billard_cfa/shared/ui/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Ligne de la grille de saisie : un élève, une colonne par passage.
///
/// Les passages déjà saisis sont des résultats en toutes lettres (atteint ou
/// manqué) ; la colonne suivante est la saisie, une pastille par essai (R11).
/// L'état de validation (« n sur 5 ») est à droite du prénom. La ligne prend
/// le ton succès quand le dernier passage atteint le taux, neutre sinon ;
/// jamais la couleur seule : chaque résultat porte son texte.
///
/// Sous 600 dp (téléphone, `compactBreakpoint`), la grille devient une liste
/// de lignes compactes : prénom et état, pastilles, tentatives et « Saisir »
/// tiennent sur une seule ligne de 48 dp, de sorte que dix élèves tiennent
/// sur un écran de 844 dp.
///
/// Le nombre de tentatives (par défaut celui de la fiche) est rare à changer :
/// il reste sous la ligne, replié derrière « Changer pour ce passage ».
class StudentPassRow extends StatefulWidget {
  const StudentPassRow({
    required this.studentName,
    required this.spec,
    required this.passes,
    required this.passedCount,
    required this.maxPasses,
    required this.passesRequired,
    required this.onSubmit,
    this.feedback,
    this.nextExerciseLabel,
    this.refusedMessage,
    super.key,
  });

  /// Largeur d'écran (dp) sous laquelle la ligne devient compacte.
  static const double compactBreakpoint = 600;

  final String studentName;
  final ExerciseSpec spec;

  /// Passages de l'élève sur cet exercice dans la séance, dans l'ordre.
  final List<ExerciseAttempt> passes;

  /// Passages réussis cumulés (toutes séances) sur l'exercice.
  final int passedCount;
  final int maxPasses;
  final int passesRequired;
  final void Function(int potted, int total) onSubmit;

  /// Dernier passage enregistré (retour affiché sous la ligne).
  final RecordedAttempt? feedback;

  /// Titre de l'exercice suivant recommandé ; `null` : niveau terminé.
  final String? nextExerciseLabel;

  /// Message du dernier passage refusé.
  final String? refusedMessage;

  @override
  State<StudentPassRow> createState() => _StudentPassRowState();
}

class _StudentPassRowState extends State<StudentPassRow> {
  late List<bool> _dots = _blank(widget.spec.rate.attempts);
  late int _total = widget.spec.rate.attempts;
  bool _editingAttempts = false;

  static List<bool> _blank(int total) => List<bool>.filled(total, false);

  int get _potted => _dots.where((pocketed) => pocketed).length;

  @override
  void didUpdateWidget(StudentPassRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spec.ref != widget.spec.ref) {
      _total = widget.spec.rate.attempts;
      _dots = _blank(_total);
      _editingAttempts = false;
    } else if (oldWidget.passes.length != widget.passes.length) {
      // Un passage vient d'être saisi : la saisie repart à blanc.
      _dots = _blank(_total);
    }
  }

  void _setTotal(int total) => setState(() {
    _total = total;
    _dots = [for (var i = 0; i < total; i++) i < _dots.length && _dots[i]];
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = widget.studentName;
    final rate = widget.spec.rate;
    final passes = widget.passes;
    final limitReached = passes.length >= widget.maxPasses;
    final lastReached = passes.isNotEmpty && passes.last.isPassed(rate);
    final feedback = widget.feedback;
    final refused = widget.refusedMessage;
    if (MediaQuery.sizeOf(context).width < StudentPassRow.compactBreakpoint) {
      return _compact(l10n, theme, lastReached: lastReached);
    }
    return SectionCard(
      title: name,
      header: StudentChip(
        name: name,
        status: _status(lastReached),
        statusLabel: _statusLabel(l10n, lastReached),
        semanticsLabel: name,
      ),
      emphasis: lastReached ? SectionEmphasis.high : SectionEmphasis.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              l10n.recordValidationState(
                widget.passedCount,
                widget.passesRequired,
              ),
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, pass) in passes.indexed)
                StatusBadge(
                  tone: pass.isPassed(rate)
                      ? BadgeTone.success
                      : BadgeTone.neutral,
                  label: pass.isPassed(rate)
                      ? l10n.recordPassReached(i + 1, pass.potted, pass.total)
                      : l10n.recordPassMissed(i + 1, pass.potted, pass.total),
                ),
              if (!limitReached) ...[
                PassDots(
                  value: _dots,
                  total: _total,
                  onChanged: (next) => setState(() => _dots = next),
                ),
                FilledButton(
                  key: const ValueKey('pass-submit'),
                  onPressed: () => widget.onSubmit(_potted, _total),
                  child: Text(l10n.recordSubmit),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.recordPassesDone(passes.length, widget.maxPasses),
            style: theme.textTheme.bodyMedium,
          ),
          if (limitReached)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: StatusBadge(
                tone: BadgeTone.neutral,
                label: l10n.recordLimitReached,
              ),
            )
          else
            _attempts(l10n, theme, name, rate),
          if (refused != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppAlert(level: AlertLevel.attention, message: refused),
          ],
          if (feedback != null) ..._feedback(l10n, theme, feedback),
        ],
      ),
    );
  }

  /// Ligne compacte : prénom et état, pastilles, tentatives, « Saisir ».
  Widget _compact(
    AppLocalizations l10n,
    ThemeData theme, {
    required bool lastReached,
  }) {
    final scheme = theme.colorScheme;
    final name = widget.studentName;
    final rate = widget.spec.rate;
    final passes = widget.passes;
    final limitReached = passes.length >= widget.maxPasses;
    final custom = _total != rate.attempts;
    final feedback = widget.feedback;
    final refused = widget.refusedMessage;
    return DecoratedBox(
      key: const ValueKey('student-row-compact'),
      decoration: BoxDecoration(
        color: lastReached ? scheme.surfaceContainer : null,
        border: lastReached
            ? Border.all(color: scheme.secondary, width: 2)
            : Border(bottom: BorderSide(color: scheme.outlineVariant)),
        borderRadius: lastReached ? AppRadii.mediumRadius : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: AppSpacing.xs,
              children: [
                StudentChip(
                  name: name,
                  detail: l10n.recordValidationStateShort(
                    widget.passedCount,
                    widget.passesRequired,
                  ),
                  status: _status(lastReached),
                  statusLabel: _statusLabel(l10n, lastReached),
                  semanticsLabel: l10n.recordCompactRowLabel(
                    name,
                    l10n.recordValidationState(
                      widget.passedCount,
                      widget.passesRequired,
                    ),
                  ),
                  nameMaxLines: 1,
                  maxWidth: MediaQuery.textScalerOf(context)
                      .scale(_compactNameWidth),
                ),
                for (final (i, pass) in passes.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: StatusBadge(
                      tone: pass.isPassed(rate)
                          ? BadgeTone.success
                          : BadgeTone.neutral,
                      label: pass.isPassed(rate)
                          ? l10n.recordPassReached(
                              i + 1,
                              pass.potted,
                              pass.total,
                            )
                          : l10n.recordPassMissed(
                              i + 1,
                              pass.potted,
                              pass.total,
                            ),
                    ),
                  ),
                if (!limitReached) ...[
                  PassDots(
                    value: _dots,
                    total: _total,
                    showScore: false,
                    onChanged: (next) => setState(() => _dots = next),
                  ),
                  IconButton(
                    key: const ValueKey('pass-attempts-toggle'),
                    tooltip: l10n.recordAttemptsChangeFor(name),
                    icon: const Icon(Icons.tune),
                    onPressed: () =>
                        setState(() => _editingAttempts = !_editingAttempts),
                  ),
                  IconButton.filled(
                    key: const ValueKey('pass-submit'),
                    tooltip: l10n.recordSubmitFor(name),
                    icon: const Icon(Icons.check),
                    onPressed: () => widget.onSubmit(_potted, _total),
                  ),
                ],
              ],
            ),
            if (passes.isNotEmpty)
              Text(
                l10n.recordPassesDone(passes.length, widget.maxPasses),
                style: theme.textTheme.bodyMedium,
              ),
            if (limitReached)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: StatusBadge(
                  tone: BadgeTone.neutral,
                  label: l10n.recordLimitReached,
                ),
              )
            else if (_editingAttempts || custom)
              _attempts(l10n, theme, name, rate),
            if (refused != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: AppAlert(level: AlertLevel.attention, message: refused),
              ),
            if (feedback != null) ..._feedback(l10n, theme, feedback),
          ],
        ),
      ),
    );
  }

  static const double _compactNameWidth = 64;

  StudentChipStatus _status(bool lastReached) {
    if (lastReached) return StudentChipStatus.reached;
    return widget.passes.isEmpty
        ? StudentChipStatus.todo
        : StudentChipStatus.missed;
  }

  String _statusLabel(AppLocalizations l10n, bool lastReached) =>
      switch (_status(lastReached)) {
        StudentChipStatus.reached => l10n.studentChipReached,
        StudentChipStatus.missed => l10n.studentChipMissed,
        StudentChipStatus.todo => l10n.studentChipTodo,
      };

  Widget _attempts(
    AppLocalizations l10n,
    ThemeData theme,
    String name,
    SuccessRate rate,
  ) {
    final custom = _total != rate.attempts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            Text(
              custom
                  ? l10n.recordAttemptsSummaryCustom(_total, rate.attempts)
                  : l10n.recordAttemptsSummary(_total),
              style: theme.textTheme.bodyMedium,
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _editingAttempts = !_editingAttempts),
              child: Text(l10n.recordAttemptsChange),
            ),
          ],
        ),
        if (_editingAttempts)
          CounterField(
            label: l10n.recordAttempts,
            value: _total,
            min: rate.attempts,
            max: SuccessRate.maxAttempts,
            decreaseTooltip: l10n.recordAttemptsLess(name),
            increaseTooltip: l10n.recordAttemptsMore(name),
            onChanged: _setTotal,
          ),
        if (custom) Text(l10n.recordCustomTotal),
      ],
    );
  }

  List<Widget> _feedback(
    AppLocalizations l10n,
    ThemeData theme,
    RecordedAttempt feedback,
  ) => [
    const SizedBox(height: AppSpacing.sm),
    Text(
      feedback.passed
          ? l10n.recordFeedbackReached(
              feedback.attempt.potted,
              feedback.attempt.total,
            )
          : l10n.recordFeedbackMissed(
              feedback.attempt.potted,
              feedback.attempt.total,
            ),
      style: theme.textTheme.bodyLarge,
    ),
    if (feedback.resumedFromPlacement) ...[
      const SizedBox(height: AppSpacing.xs),
      Text(
        l10n.placementResumedFeedback(
          feedback.result.passedCount,
          widget.passesRequired,
        ),
      ),
    ],
    if (feedback.justValidated) ...[
      const SizedBox(height: AppSpacing.xs),
      StatusBadge(tone: BadgeTone.success, label: l10n.recordValidated),
      const SizedBox(height: AppSpacing.xs),
      Text(
        widget.nextExerciseLabel == null
            ? l10n.recordNextNone
            : l10n.recordNext(widget.nextExerciseLabel!),
      ),
    ],
    if (feedback.result.hasActiveAlert) ...[
      const SizedBox(height: AppSpacing.sm),
      AppAlert(
        level: AlertLevel.attention,
        message: l10n.recordAlert(feedback.result.consecutiveFailures),
      ),
    ],
  ];
}
