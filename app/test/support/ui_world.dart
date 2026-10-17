import 'package:billard_cfa/app/di/injection.dart';
import 'package:billard_cfa/app/session_startup.dart';
import 'package:billard_cfa/entities/account/data/in_memory_auth_repository.dart';
import 'package:billard_cfa/entities/account/domain/auth_repository.dart';
import 'package:billard_cfa/entities/exercise_catalog/domain/catalogue_repository.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_repository.dart';
import 'package:billard_cfa/entities/exercise_result/domain/attempt_repository.dart';
import 'package:billard_cfa/entities/group/domain/group_repository.dart';
import 'package:billard_cfa/entities/membership/domain/club_membership.dart';
import 'package:billard_cfa/entities/season/domain/season_repository.dart';
import 'package:billard_cfa/entities/session_sheet/domain/session_sheet_repository.dart';
import 'package:billard_cfa/entities/student/domain/student.dart';
import 'package:billard_cfa/entities/student/domain/student_repository.dart';
import 'package:billard_cfa/features/export_sheet/domain/pdf_files.dart';
import 'package:billard_cfa/features/manage_groups/domain/create_group.dart';
import 'package:billard_cfa/features/manage_students/domain/enroll_student.dart';
import 'package:billard_cfa/features/place_student/domain/mark_block_acquired.dart';
import 'package:billard_cfa/features/record_results/domain/open_session.dart';
import 'package:billard_cfa/features/record_results/domain/record_attempt.dart';
import 'package:billard_cfa/shared/lib/active_club_scope.dart';
import 'package:billard_cfa/shared/lib/app_update_source.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/clock.dart';
import 'package:billard_cfa/shared/lib/exercise_ref.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/fullscreen_controller.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/key_value_store.dart';
import 'package:billard_cfa/shared/persistence/document_store.dart';
import 'package:billard_cfa/shared/persistence/in_memory_document_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show Environment;

import 'fake_app_update_source.dart';
import 'fake_fullscreen_controller.dart';
import 'fake_pdf_files.dart';
import 'fixed_clock.dart';
import 'memberships_fixture.dart';

/// Monde des scénarios d'interface : graphe get_it réel (dépôts en mémoire,
/// catalogue de l'asset, horloge figée) et amorçage du club par les cas
/// d'usage, comme le fera l'application.
///
/// Les étapes `Given` peuvent précéder `the app is running` : [prepare] est
/// idempotent pour un scénario.
class UiWorld {
  UiWorld._();

  /// « Aujourd'hui » des scénarios.
  static final today = DateTime(2026, 10, 12, 9, 30);

  static late FixedClock _clock;
  static bool _ready = false;

  /// Plein écran de l'appareil simulé : pris en charge par défaut ; un
  /// `Given` peut en décider avant le lancement ([prepare]).
  static bool fullscreenSupported = true;
  static FakeFullscreenController? _fullscreen;

  /// Le double de plein écran du scénario en cours.
  static FakeFullscreenController get fullscreen =>
      _fullscreen ?? (throw StateError("l'application n'est pas lancée"));

  /// La plate-forme sait imprimer un PDF : un `Given` peut en décider avant le
  /// lancement ([prepare]).
  static bool pdfCanPrint = true;

  /// L'enregistrement du prochain PDF est annulé par l'utilisateur.
  static bool pdfSaveCancelled = false;
  static FakePdfFiles? _pdfFiles;

  /// Le double de sortie PDF du scénario en cours.
  static FakePdfFiles get pdfFiles =>
      _pdfFiles ?? (throw StateError("l'application n'est pas lancée"));

  /// Version en attente d'activation à l'ouverture : un `Given` peut en
  /// décider avant le lancement ([prepare]).
  static bool updateWaiting = false;
  static FakeAppUpdateSource? _appUpdate;

  /// Le double de mise à jour du scénario en cours.
  static FakeAppUpdateSource get appUpdate =>
      _appUpdate ?? (throw StateError("l'application n'est pas lancée"));
  static int _seededDays = 0;

  /// Le compte de l'animateur des scénarios, connecté sur l'appareil à
  /// l'ouverture (session persistée) et seul membre d'un club : les scénarios
  /// qui ne parlent pas de comptes s'exécutent ainsi connectés, sans écran de
  /// connexion. Un `Given` d'authentification peut le déconnecter.
  static const defaultEmail = 'animateur@example.org';
  static const defaultPassword = 'mot-de-passe-12';
  static const defaultClub = 'Test club';

  /// L'authentification en mémoire du scénario en cours.
  static InMemoryAuthRepository get auth =>
      getIt<AuthRepository>() as InMemoryAuthRepository;

  /// Le stock de documents en mémoire du scénario en cours (ce que serait
  /// Firestore).
  static InMemoryDocumentStore get documents =>
      getIt<DocumentStore>() as InMemoryDocumentStore;

  /// Les clubs et les membres des scénarios, écrits dans [documents].
  static MembershipsFixture get memberships => MembershipsFixture(documents);

  /// Le démarrage du service de comptes du scénario en cours.
  static InMemorySessionStartup get startup =>
      getIt<SessionStartup>() as InMemorySessionStartup;

  /// Le stockage local de l'appareil du scénario en cours.
  static InMemoryKeyValueStore get store =>
      getIt<KeyValueStore>() as InMemoryKeyValueStore;

  /// Identifiant de club dérivé du nom (`Club Nice` devient `club-nice`).
  static ClubId clubIdOf(String name) =>
      ClubId(name.toLowerCase().replaceAll(' ', '-'));

  static Role role(String label) => Role.values.firstWhere(
    (role) => role.name == label,
    orElse: () => throw ArgumentError('rôle inconnu : $label'),
  );

  static ClubMembership membership(String club, String roleName) =>
      ClubMembership(
        clubId: clubIdOf(club),
        clubName: club,
        role: role(roleName),
      );

  static Future<void> prepare(WidgetTester tester) async {
    if (_ready) return;
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
    await getIt.unregister<Clock>();
    _clock = FixedClock(today);
    getIt.registerSingleton<Clock>(_clock);
    documents.serverNow = _clock.now;
    if (getIt.isRegistered<FullscreenController>()) {
      await getIt.unregister<FullscreenController>();
    }
    final fullscreen = FakeFullscreenController(supported: fullscreenSupported);
    _fullscreen = fullscreen;
    getIt.registerSingleton<FullscreenController>(fullscreen);
    if (getIt.isRegistered<AppUpdateSource>()) {
      await getIt.unregister<AppUpdateSource>();
    }
    if (getIt.isRegistered<PdfFiles>()) await getIt.unregister<PdfFiles>();
    final pdfFiles = FakePdfFiles(printSupported: pdfCanPrint)
      ..cancelSave = pdfSaveCancelled;
    _pdfFiles = pdfFiles;
    getIt.registerSingleton<PdfFiles>(pdfFiles);
    final appUpdate = FakeAppUpdateSource(available: updateWaiting);
    _appUpdate = appUpdate;
    getIt.registerSingleton<AppUpdateSource>(appUpdate);
    final account = auth.seed(email: defaultEmail, password: defaultPassword);
    memberships.grant(account.id, membership(defaultClub, 'director'));
    auth.restoreSession(defaultEmail);
    _ready = true;
    _seededDays = 0;
    addTearDown(() async {
      _ready = false;
      fullscreenSupported = true;
      pdfCanPrint = true;
      pdfSaveCancelled = false;
      _pdfFiles = null;
      await fullscreen.close();
      _fullscreen = null;
      updateWaiting = false;
      await appUpdate.close();
      _appUpdate = null;
      await getIt.reset();
    });
    // Le chargement d'asset est de l'E/S réelle : une fois le catalogue et les
    // schémas en cache, les écrans les lisent sans attendre.
    await tester.runAsync(() async {
      await getIt<CatalogueRepository>().load();
      await getIt<DiagramRepository>().load();
      await getIt<SessionSheetRepository>().getAll();
    });
  }

  /// Fait avancer « aujourd'hui » sans reconstruire les écrans ouverts.
  static void advanceDays(int days) => _clock.advance(Duration(days: days));

  static T _value<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('échec inattendu : $failure'),
  };

  static Audience audience(String label) => switch (label) {
    'children' => Audience.children,
    'adults' => Audience.adults,
    _ => throw ArgumentError('public inconnu : $label'),
  };

  static ExerciseRef exercise(String label) {
    final cut = label.lastIndexOf(' ');
    return ExerciseRef(
      blockId: label.substring(0, cut),
      number: int.parse(label.substring(cut + 1)),
    );
  }

  static Future<Student> studentNamed(String name) async {
    final students = await getIt<StudentRepository>().all();
    return students.firstWhere((student) => student.firstName == name);
  }

  static Future<void> enroll(
    WidgetTester tester,
    String name,
    Audience audience,
  ) async {
    await prepare(tester);
    await tester.runAsync(() async {
      _value(
        await getIt<EnrollStudent>()(
          firstName: name,
          audience: audience,
          today: DateTime(today.year, today.month, today.day),
          groupName: switch (audience) {
            Audience.children => 'Children group',
            Audience.adults => 'Adults group',
          },
        ),
      );
    });
  }

  /// Crée un groupe de plus pour [audience] dans la saison en cours (la saison
  /// existe : un élève du même public est déjà inscrit, ou la saison courante
  /// est créée par une inscription préalable de l'autre public).
  static Future<void> createGroup(
    WidgetTester tester,
    String name,
    Audience audience,
  ) async {
    await prepare(tester);
    await tester.runAsync(() async {
      final seasons = await getIt<SeasonRepository>().all();
      final season = seasons.firstWhere((s) => s.isOpenOn(today));
      _value(
        await getIt<CreateGroup>()(
          seasonId: season.id,
          name: name,
          audience: audience,
        ),
      );
    });
  }

  /// Le nom du groupe où [student] est membre aujourd'hui.
  static Future<String?> groupNameOf(String student) async {
    final id = (await studentNamed(student)).id;
    final groups = await getIt<GroupRepository>().all();
    for (final group in groups) {
      if (group.isMemberOn(id, DateTime(today.year, today.month, today.day))) {
        return group.name;
      }
    }
    return null;
  }

  /// [count] passages réussis (taux requis exact) ou manqués (une bille de
  /// moins), deux par séance passée au plus, dans l'ordre chronologique.
  static Future<void> seedPasses(
    WidgetTester tester,
    String name,
    ExerciseRef exercise,
    int count, {
    required bool passed,
  }) async {
    await prepare(tester);
    await tester.runAsync(() async {
      final student = await studentNamed(name);
      final groups = await getIt<GroupRepository>().all();
      final group = groups.firstWhere((g) => g.isMemberOn(student.id, today));
      final catalogue = await getIt<CatalogueRepository>().load();
      final rate = catalogue.exercise(exercise)!.rate;
      var remaining = count;
      while (remaining > 0) {
        final session = _value(
          await getIt<OpenSession>()(
            groupId: group.id,
            date: DateTime(2026, 9, 12).add(Duration(days: _seededDays++)),
            present: {student.id},
          ),
        );
        for (var pass = 0; pass < 2 && remaining > 0; pass++, remaining--) {
          _value(
            await getIt<RecordAttempt>()(
              sessionId: session.id,
              studentId: student.id,
              exercise: exercise,
              potted: passed ? rate.successes : rate.successes - 1,
              total: rate.attempts,
            ),
          );
        }
      }
    });
  }

  static Future<void> seedValidatedBlock(
    WidgetTester tester,
    String name,
    String blockId,
  ) async {
    await prepare(tester);
    final catalogue = await tester.runAsync(
      () => getIt<CatalogueRepository>().load(),
    );
    for (final spec in catalogue!.blockById(blockId)!.exercises) {
      await seedPasses(tester, name, spec.ref, 5, passed: true);
    }
  }

  /// Marque [blockId] acquis au positionnement le [date] (cas d'usage réel).
  static Future<void> seedAcquired(
    WidgetTester tester,
    String name,
    String blockId,
    DateTime date,
  ) async {
    await prepare(tester);
    await tester.runAsync(() async {
      final student = await studentNamed(name);
      _value(
        await getIt<MarkBlockAcquired>()(
          studentId: student.id,
          blockId: blockId,
          date: date,
          today: DateTime(today.year, today.month, today.day),
        ),
      );
    });
  }

  /// Les groupes où l'élève est membre aujourd'hui.
  static Future<List<String>> currentGroupIdsOf(StudentId student) async {
    final day = DateTime(today.year, today.month, today.day);
    return [
      for (final group in await getIt<GroupRepository>().all())
        if (group.isMemberOn(student, day)) group.id.value,
    ];
  }

  /// Une invitation telle que le serveur la stocke : valable (durée de son
  /// rôle depuis « aujourd'hui ») sauf [expiresAt] ou [used] contraires.
  static void seedInvitation({
    required String code,
    required String club,
    required String role,
    List<String> groupIds = const [],
    List<String> studentIds = const [],
    DateTime? expiresAt,
    bool used = false,
  }) {
    final validity = switch (role) {
      'teacher' || 'director' => const Duration(hours: 48),
      _ => const Duration(days: 7),
    };
    final expiry = expiresAt ?? today.add(validity);
    documents.seed('invitations/$code', {
      'clubId': clubIdOf(club).value,
      'role': role,
      'groupIds': groupIds,
      'studentIds': studentIds,
      'createdBy': 'u-seed',
      // Une invitation expirée a été créée avant son expiration.
      'createdAt': expiry.subtract(validity),
      'expiresAt': expiry,
      'used': used,
      if (used) 'usedBy': 'u-other',
    });
  }

  /// L'identifiant du club de ce nom dans le stock de documents (un club créé
  /// par l'application reçoit un identifiant tiré par le générateur).
  static String clubIdNamed(String name) {
    final ids = [
      for (final entry in documents.documents.entries)
        if (entry.key.startsWith('clubs/') &&
            entry.key.split('/').length == 2 &&
            entry.value['name'] == name)
          entry.key.split('/')[1],
    ];
    expect(ids, hasLength(1), reason: 'club « $name » introuvable ou ambigu');
    return ids.single;
  }

  static Future<int> attemptCountOf(String name) async {
    final student = await studentNamed(name);
    return (await getIt<AttemptRepository>().forStudent(student.id)).length;
  }
}
