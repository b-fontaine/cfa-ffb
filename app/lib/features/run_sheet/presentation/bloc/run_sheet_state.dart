part of 'run_sheet_cubit.dart';

enum RunStatus { loading, ready, notFound, failure }

/// Camp d'un score de jeu saisi à la main.
enum ScoreSide { a, b }

/// Le groupe, la date et les absents choisis à la première saisie des
/// résultats depuis la séance guidée : ils sont repris aux exercices suivants.
typedef RunRecordChoice = ({
  GroupId group,
  DateTime date,
  Set<StudentId> absent,
});

@freezed
abstract class RunSheetState with _$RunSheetState {
  const factory RunSheetState({
    @Default(RunStatus.loading) RunStatus status,
    RunPlan? plan,
    Failure? failure,

    /// Étape courante (à partir de 0).
    @Default(0) int step,

    /// Réussites comptées par initiation (locales, jamais enregistrées).
    @Default(<String, int>{}) Map<String, int> counts,

    /// Critères acquis (indices) par initiation à grille.
    @Default(<String, Set<int>>{}) Map<String, Set<int>> checked,

    /// Score du jeu, saisi à la main.
    @Default(0) int scoreA,
    @Default(0) int scoreB,

    /// Minuteur indicatif de la phase courante : jamais bloquant.
    @Default(false) bool timerRunning,
    @Default(0) int timerSeconds,

    /// Vrai quand la séance est relancée alors qu'elle avait de la
    /// progression : l'animateur choisit de reprendre ou de recommencer.
    @Default(false) bool resumeOffered,

    /// Choix de la dernière saisie des résultats faite depuis ce guide.
    RunRecordChoice? recordChoice,
  }) = _RunSheetState;

  const RunSheetState._();

  /// Vrai quand la séance a de la progression à reprendre : étape après la
  /// première, réussites comptées, critères cochés ou score. Le minuteur
  /// seul n'en est pas (indicatif).
  bool get hasProgress =>
      step > 0 ||
      counts.values.any((count) => count > 0) ||
      this.checked.values.any((criteria) => criteria.isNotEmpty) ||
      scoreA > 0 ||
      scoreB > 0;

  /// L'étape courante, une fois le déroulé prêt.
  RunStep? get currentStep => plan?.steps.elementAtOrNull(step);

  /// Groupe, date et absents proposés à la saisie des résultats : le choix
  /// d'une saisie précédente de ce guide, sinon la séance planifiée d'où il a
  /// été lancé (ADR 0007), sinon rien (le groupe se choisit à la saisie).
  ({GroupId? group, DateTime? date, Set<StudentId> absent}) get recordDefaults {
    final choice = recordChoice;
    final planned = plan?.planned;
    return (
      group: choice?.group ?? planned?.groupId,
      date: choice?.date ?? planned?.date,
      absent: choice?.absent ?? const {},
    );
  }
}
