import 'package:billard_cfa/entities/exercise_catalog/domain/exercise_catalogue.dart';
import 'package:billard_cfa/entities/exercise_result/domain/watch_list.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'watch_list.freezed.dart';

/// Une ligne « à surveiller » de l'accueil : l'élève et son alerte la plus
/// alarmante.
@freezed
abstract class WatchedLine with _$WatchedLine {
  const factory WatchedLine({
    required Student student,
    required WatchedStudent watched,
  }) = _WatchedLine;
}

/// Les élèves à surveiller du club, limités à l'affichage.
@freezed
abstract class WatchList with _$WatchList {
  const factory WatchList({
    /// Les premières lignes, au plus la limite demandée.
    @Default(<WatchedLine>[]) List<WatchedLine> lines,

    /// Nombre total d'élèves à surveiller (limite non appliquée).
    @Default(0) int total,

    /// Titre des blocs, pour libeller l'exercice de chaque ligne.
    @Default(<String, BlockLabel>{}) Map<String, BlockLabel> blockLabels,
  }) = _WatchList;
}
