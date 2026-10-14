import 'package:billard_cfa/entities/exercise_catalog/domain/training_block.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'recorded_session_summary.freezed.dart';

/// Une séance saisie, telle que l'historique la présente : la séance, le nom
/// de son groupe, son bloc principal (s'il est connu du catalogue) et le
/// nombre de passages enregistrés.
@freezed
abstract class RecordedSessionSummary with _$RecordedSessionSummary {
  const factory RecordedSessionSummary({
    required SessionRecord session,
    required String groupName,
    required TrainingBlock? mainBlock,
    required int attemptCount,
  }) = _RecordedSessionSummary;

  const RecordedSessionSummary._();

  int get presentCount => session.present.length;
}
