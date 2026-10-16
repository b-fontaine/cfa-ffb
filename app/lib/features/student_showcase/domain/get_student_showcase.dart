import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/student_progress.dart';
import 'package:billard_cfa/entities/exercise_result/domain/technique_summary.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/student_showcase/domain/student_showcase.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/rules_config.dart';
import 'package:injectable/injectable.dart';

/// Cas d'usage : la vue « à montrer à l'élève » (prénom et parcours).
@injectable
class GetStudentShowcase {
  GetStudentShowcase(
    this._students,
    this._attempts,
    this._acquisitions,
    this._catalogue,
    this._config,
  );

  final StudentRepository _students;
  final AttemptRepository _attempts;
  final AcquisitionRepository _acquisitions;
  final CatalogueRepository _catalogue;
  final RulesConfig _config;

  /// Ne lit que les passages et les blocs acquis de l'élève : ni alertes, ni
  /// acquittements, ni bilans de maturité, ni séances, ni autres élèves.
  Future<Result<StudentShowcase>> call(StudentId studentId) =>
      runGuarded(() async {
        final student = await _students.byId(studentId);
        if (student == null) throw NotFound('student', studentId.value);
        final catalogue = await _catalogue.load();
        final progress = StudentProgress.derive(
          studentId: studentId,
          attempts: await _attempts.forStudent(studentId),
          acquisitions: await _acquisitions.forStudent(studentId),
          rates: catalogue.rates,
          config: _config,
        );
        final summaries = [
          for (final block in catalogue.blocks)
            (
              block,
              techniqueSummary(
                blockId: block.id,
                exercises: block.exerciseRefs,
                progress: progress,
              ),
            ),
        ];
        final current = catalogue.nextExercise(validated: progress.validated);
        return StudentShowcase(
          firstName: student.firstName,
          rows: [
            for (final (block, summary) in summaries)
              ShowcaseRow(
                title: block.title,
                status: switch (summary.status) {
                  BlockStatus.notStarted => ShowcaseRowStatus.todo,
                  // Une technique « à revoir » se montre « en cours ».
                  BlockStatus.inProgress ||
                  BlockStatus.toReview => ShowcaseRowStatus.inProgress,
                  BlockStatus.mastered => ShowcaseRowStatus.finished,
                  BlockStatus.acquiredAtPlacement => ShowcaseRowStatus.acquired,
                },
                cells: [
                  for (final cell in summary.cells)
                    ShowcaseCell(
                      number: cell.exercise.number,
                      state: cell.state,
                      passed: cell.passedCount,
                    ),
                ],
              ),
          ],
          current: current == null
              ? null
              : ShowcaseCurrent(
                  blockTitle: catalogue.blockById(current.blockId)!.title,
                  number: current.number,
                  passed: progress.results[current]?.passedCount ?? 0,
                  required: _config.passesRequired,
                ),
          validatedCount: progress.validated.length,
          finishedTechniques: summaries
              .where((entry) => entry.$2.isFinished)
              .length,
          techniqueCount: summaries.length,
          toStart: progress.toStart,
          passesRequired: _config.passesRequired,
        );
      });
}
