import 'package:billard_cfa/app/di/injection.config.dart';
import 'package:billard_cfa/entities/account/domain/session_scope.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/data/firestore_attempt_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acknowledgement_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/acquisition_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/data/firestore_group_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/data/firestore_assessment_repository.dart';
import 'package:billard_cfa/entities/maturity_assessment/domain/assessment_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_archive_repository.dart';
import 'package:billard_cfa/entities/season/data/firestore_season_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_archive_repository.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session/data/firestore_session_repository.dart';
import 'package:billard_cfa/entities/session/domain/session_repository.dart';
import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/entities/session_record/domain/session_record_repository.dart';
import 'package:billard_cfa/entities/settings/data/firestore_settings_repository.dart';
import 'package:billard_cfa/entities/settings/domain/settings_repository.dart';
import 'package:billard_cfa/entities/student/data/firestore_student_repository.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/current_user.dart';
import 'package:billard_cfa/shared/lib/id_generator.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/club_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/firestore_unit_of_work.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:billard_cfa/shared/persistence/open_app_database.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart' show Environment;

/// Remplace, dans le graphe [graph], les dépôts de données en mémoire par les
/// dépôts **Firestore** du montage de production (`DataBackendModule` avec
/// `DATA_BACKEND=firestore`), posés sur le `DocumentStore` du graphe. Deux
/// graphes dont le `DocumentStore` mène au même serveur partagé sont deux
/// appareils du même club.
Future<void> useFirestoreRepositories(GetIt graph) async {
  final club = graph<ClubStore>();
  final user = graph<CurrentUser>();
  Future<void> swap<T extends Object>(T repository) async {
    if (graph.isRegistered<T>()) await graph.unregister<T>();
    graph.registerSingleton<T>(repository);
  }

  await swap<SettingsRepository>(FirestoreSettingsRepository(club));
  await swap<StudentRepository>(FirestoreStudentRepository(club));
  await swap<GroupRepository>(FirestoreGroupRepository(club));
  await swap<SeasonRepository>(FirestoreSeasonRepository(club));
  await swap<SeasonArchiveRepository>(FirestoreSeasonArchiveRepository(club));
  await swap<SessionRepository>(FirestoreSessionRepository(club));
  await swap<SessionRecordRepository>(FirestoreSessionRecordRepository(club));
  await swap<AttemptRepository>(FirestoreAttemptRepository(club));
  await swap<AcquisitionRepository>(FirestoreAcquisitionRepository(club));
  await swap<AssessmentRepository>(FirestoreAssessmentRepository(club));
  await swap<AcknowledgementRepository>(
    FirestoreAcknowledgementRepository(club, user),
  );
  await swap<UnitOfWork>(FirestoreUnitOfWork(club));
}

/// Des identifiants que deux appareils ne produisent jamais ensemble.
class PrefixedIdGenerator implements IdGenerator {
  PrefixedIdGenerator(this._prefix);

  final String _prefix;
  int _counter = 0;

  @override
  String next() => '$_prefix-${++_counter}';
}

/// **Un autre appareil** du même club : un graphe de dépendances complet et
/// indépendant (ses propres `ClubStore`, dépôts Firestore, cas d'usage, portée
/// de session), posé sur le serveur partagé de la scène. Ce qu'il écrit arrive
/// à l'appareil de la scène par les flux (`watch…`), comme depuis un autre
/// téléphone.
class OtherDevice {
  OtherDevice._(this.graph, this.scope);

  final GetIt graph;

  /// La session de cet appareil.
  final SessionScope scope;

  /// Ouvre un appareil connecté à [server] : [user] dans [club] avec [role].
  static Future<OtherDevice> open({
    required InMemoryDocumentStore server,
    required Clock clock,
    required String user,
    required ClubId club,
    Role role = Role.director,
    List<GroupId> groups = const [],
    List<StudentId> students = const [],
    String idPrefix = 'other',
  }) async {
    final graph = GetIt.asNewInstance()
      ..registerSingleton<DatabaseSettings>(const DatabaseSettings());
    await graph.init(environment: Environment.test);
    for (final replaced in [
      graph.unregister<DocumentStore>(),
      graph.unregister<Clock>(),
      graph.unregister<IdGenerator>(),
    ]) {
      await replaced;
    }
    graph
      ..registerSingleton<DocumentStore>(server)
      ..registerSingleton<Clock>(clock)
      ..registerSingleton<IdGenerator>(PrefixedIdGenerator(idPrefix));
    final scope = graph<SessionScope>()
      ..signIn(UserId(user))
      ..activate(club, role, groupIds: groups, studentIds: students);
    await useFirestoreRepositories(graph);
    return OtherDevice._(graph, scope);
  }

  /// Un objet du graphe de cet appareil (cas d'usage, dépôt).
  T call<T extends Object>() => graph<T>();

  Future<void> close() => graph.reset();
}
