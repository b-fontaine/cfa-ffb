import 'package:billard_cfa/entities/student/domain/student_directory.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/store_guard.dart';

/// Annuaire des fiches sous `DATA_BACKEND=firestore` : les fiches y **existent
/// déjà** (l'inscription les crée, la liste des élèves invitables les lit).
/// `publish` ne fait donc que vérifier leur présence et ne crée **jamais** de
/// fiche : si un autre appareil a supprimé la fiche entre la liste et la
/// publication, elle ne revient pas (elle reviendrait avec son prénom et la
/// règle d'invitation la reverrait). Une fiche absente lève l'échec
/// « action non autorisée », comme un élève qui n'est plus invitable.
class ExistingStudentDirectory implements StudentDirectory {
  ExistingStudentDirectory(this._store);

  final DocumentStore _store;

  @override
  Future<void> publish(ClubId club, List<PublishedStudent> students) =>
      guardStore(() async {
        for (final student in students) {
          final path = 'clubs/${club.value}/students/${student.id.value}';
          if (await _store.get(path) == null) {
            throw const InvariantViolation(InvariantCode.actionNotAllowed);
          }
        }
      });
}
