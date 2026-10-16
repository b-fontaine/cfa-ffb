import 'package:billard_cfa/features/close_season/domain/student_eraser.dart';
import 'package:billard_cfa/features/manage_students/domain/erase_student.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:injectable/injectable.dart';

/// Relie le port `StudentEraser` de la clôture de saison à l'enchaînement
/// d'effacement d'`EraseStudent` : une seule liste de dépôts nominatifs.
@Injectable(as: StudentEraser)
class EraseStudentRecords implements StudentEraser {
  EraseStudentRecords(this._erase);

  final EraseStudent _erase;

  @override
  Future<void> erase(StudentId studentId) => _erase.eraseRecords(studentId);
}
