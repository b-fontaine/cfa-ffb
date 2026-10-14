import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_spec.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/session/domain/session.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_exercise.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_initiation.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_theory.dart';
import 'package:billard_cfa/entities/session_sheet/domain/sheet_timing.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_step.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_plan.freezed.dart';

/// Le déroulé d'une séance du catalogue pour un public : les étapes dans
/// l'ordre pédagogique (accueil ou rappel, théorie, initiation, exercices,
/// jeu, bilan), leurs minutes calculées et ce que chaque étape référence.
///
/// Lecture seule : aucune étape n'est obligatoire ni bloquante.
@freezed
abstract class RunPlan with _$RunPlan {
  const factory RunPlan({
    required SessionSheet sheet,
    required Audience audience,

    /// Nombre de séances de la technique (« séance 2/2 »).
    required int partCount,
    required SheetTiming timing,
    required List<RunStep> steps,

    /// Passages réussis qui valident un exercice (règle du suivi).
    required int passesRequired,

    /// Séance précédente du catalogue : le rappel théorique porte sur elle.
    SessionSheet? previous,

    /// Nombre de séances de la technique de la séance précédente.
    int? previousPartCount,

    /// Bloc du rappel de **résultats** : celui de la plus récente séance
    /// précédente dont le bloc diffère du bloc principal ; `null` s'il n'y en
    /// a pas (la saisie refuse un rappel égal au bloc principal).
    String? recallBlockId,

    /// Titre du bloc d'entraînement de la séance.
    String? blockTitle,

    /// Séance planifiée d'où le guide a été lancé (`?session=`), si elle
    /// existe encore : son groupe et sa date pré-remplissent la saisie des
    /// résultats (ADR 0007).
    Session? planned,

    /// Exercice du catalogue d'entraînement (taux, chevalet, bronze) par
    /// identifiant d'exercice de la séance.
    @Default(<String, ExerciseSpec>{}) Map<String, ExerciseSpec> exerciseSpecs,

    /// Schémas transcrits par identifiant de diagramme.
    @Default(<String, ExerciseDiagram>{}) Map<String, ExerciseDiagram> diagrams,

    /// Vrai quand les schémas n'ont pas pu être lus : la séance reste lisible.
    @Default(false) bool diagramsUnreadable,
  }) = _RunPlan;

  const RunPlan._();

  int get stepCount => steps.length;

  /// Ramène [step] dans la plage des étapes.
  int clamp(int step) => step.clamp(0, steps.length - 1);

  /// Première étape de [phase] ; `null` si elle n'en a aucune.
  int? firstStepOf(SessionPhase phase) {
    final index = steps.indexWhere((s) => s.phase == phase);
    return index < 0 ? null : index;
  }

  SheetTheorySection? theoryOf(RunStep step) =>
      sheet.theorySections.where((s) => s.id == step.elementId).firstOrNull;

  SheetInitiation? initiationOf(RunStep step) =>
      sheet.initiation.where((i) => i.id == step.elementId).firstOrNull;

  SheetExercise? exerciseOf(RunStep step) =>
      sheet.exercises.where((e) => e.id == step.elementId).firstOrNull;

  /// Rang (à partir de 1) de l'exercice de [step] parmi les exercices
  /// affichés, ou `null` si l'étape n'est pas un exercice.
  int? exerciseIndexOf(RunStep step) {
    if (step.kind != RunStepKind.exercise) return null;
    final shown = steps
        .where((s) => s.kind == RunStepKind.exercise)
        .toList(growable: false);
    final index = shown.indexOf(step);
    return index < 0 ? null : index + 1;
  }

  int get exerciseCount =>
      steps.where((s) => s.kind == RunStepKind.exercise).length;

  Illustration? illustration(String id) =>
      sheet.illustrations.where((i) => i.id == id).firstOrNull;

  /// Illustrations de [step] (le schéma d'un exercice est à part : voir
  /// [SheetExercise.diagramId]).
  List<Illustration> illustrationsOf(RunStep step) {
    switch (step.kind) {
      case RunStepKind.recall:
        final reuse = sheet.recall.reuse;
        final reused = reuse == null
            ? null
            : previous?.illustrations
                  .where((i) => i.id == reuse.illustration)
                  .firstOrNull;
        return [?reused];
      case RunStepKind.theory:
        return [
          for (final id in theoryOf(step)?.illustrationIds ?? const <String>[])
            ?illustration(id),
        ];
      case RunStepKind.initiation:
        final id = initiationOf(step)?.illustrationId;
        return [if (id != null) ?illustration(id)];
      case RunStepKind.game:
        final id = sheet.game.setupIllustrationId;
        return [if (id != null) ?illustration(id)];
      case RunStepKind.exercise:
      case RunStepKind.review:
        return const [];
    }
  }

  /// Vrai quand [step] a quelque chose à montrer aux élèves : une
  /// illustration dessinée, ou le schéma de mise en place d'un exercice.
  ///
  /// Un simple renvoi à une page du PDF (`pdf_ref`) n'en est pas une : il
  /// n'est qu'une pastille de texte pour l'animateur, déjà affichée dans le
  /// guide ; il n'y a rien d'illustré à montrer.
  bool isPresentable(RunStep step) {
    if (step.kind == RunStepKind.exercise) {
      final exercise = exerciseOf(step);
      return exercise != null && diagrams.containsKey(exercise.diagramId);
    }
    return presentableIllustrationsOf(step).isNotEmpty;
  }

  /// Indices des étapes qui ont quelque chose à montrer, dans l'ordre.
  List<int> get presentableSteps => [
    for (final (index, step) in steps.indexed)
      if (isPresentable(step)) index,
  ];

  /// L'étape à montrer en premier pour la demande [step] : elle-même si elle
  /// a quelque chose à montrer, sinon la première étape à montrer qui la
  /// suit, sinon la dernière qui la précède ; [step] ramenée dans la plage
  /// quand rien n'est présentable.
  int presentationStart(int step) {
    final start = clamp(step);
    final presentable = presentableSteps;
    if (presentable.isEmpty || presentable.contains(start)) return start;
    return presentable.firstWhere(
      (i) => i > start,
      orElse: () => presentable.last,
    );
  }

  /// Illustrations de [step] qui se montrent aux élèves : celles de
  /// [illustrationsOf] sans les renvois au PDF.
  List<Illustration> presentableIllustrationsOf(RunStep step) => [
    for (final i in illustrationsOf(step))
      if (i is! PdfRefIllustration) i,
  ];

  /// Vrai quand l'élément de [step] est une proposition `[Prop]` : ses
  /// illustrations en portent le badge.
  bool isProposal(RunStep step) => switch (step.kind) {
    RunStepKind.recall => sheet.recall.src.isProposal,
    RunStepKind.theory => theoryOf(step)?.src.isProposal ?? false,
    RunStepKind.initiation => initiationOf(step)?.src.isProposal ?? false,
    RunStepKind.exercise => exerciseOf(step)?.src.isProposal ?? false,
    RunStepKind.game => sheet.game.src.isProposal,
    RunStepKind.review => false,
  };
}
