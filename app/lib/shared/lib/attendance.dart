import 'package:freezed_annotation/freezed_annotation.dart';

part 'attendance.freezed.dart';

/// Compte les séances comptées d'un élève : une valeur par séance où il était
/// membre, vraie s'il y était présent. Calcul unique de l'assiduité (fiche
/// élève et grille du groupe).
Attendance attendanceFrom(Iterable<bool> presences) => Attendance(
  attended: presences.where((present) => present).length,
  total: presences.length,
);

/// Assiduité d'un élève : séances suivies sur les séances où il était membre
/// (ADR 0006). Une seule définition, pour la fiche élève et pour la grille du
/// groupe ; la règle d'appartenance reste `Group.isMemberOn`.
@freezed
abstract class Attendance with _$Attendance {
  const factory Attendance({required int attended, required int total}) =
      _Attendance;

  const Attendance._();

  /// Aucune séance à compter.
  bool get isEmpty => total == 0;
}
