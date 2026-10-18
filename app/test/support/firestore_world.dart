import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';

/// Un stock de documents en mémoire et une session que le test fait changer de
/// club ou de rôle : de quoi jouer les dépôts Firestore sans plugin.
class FirestoreWorld {
  FirestoreWorld() : scope = SessionScope()..signIn(const UserId('u-dir')) {
    club = ClubStore(documents, scope);
  }

  final InMemoryDocumentStore documents = InMemoryDocumentStore();
  final SessionScope scope;
  late final ClubStore club;

  /// Active le club [id] avec le [role] (périmètre : [groups], [students]).
  void act(
    String id,
    Role role, {
    List<String> groups = const [],
    List<String> students = const [],
  }) => scope.activate(
    ClubId(id),
    role,
    groupIds: [for (final group in groups) GroupId(group)],
    studentIds: [for (final student in students) StudentId(student)],
  );

  /// Les chemins des documents du stock, triés.
  List<String> get paths => documents.documents.keys.toList()..sort();
}
