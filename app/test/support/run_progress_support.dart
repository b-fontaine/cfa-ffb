import 'package:billard_cfa/entities/group/data/in_memory_group_repository.dart';
import 'package:billard_cfa/entities/run_progress/data/in_memory_run_progress_repository.dart';
import 'package:billard_cfa/entities/session_record/data/in_memory_session_record_repository.dart';
import 'package:billard_cfa/features/run_sheet/domain/run_progress_keeper.dart';

import 'fixed_clock.dart';

/// Un garde d'état des séances guidées sur des dépôts en mémoire neufs et une
/// horloge figée : pour les tests du guide qui n'étudient pas la reprise.
RunProgressKeeper inMemoryRunProgressKeeper() => RunProgressKeeper(
  InMemoryRunProgressRepository(),
  InMemorySessionRecordRepository(),
  InMemoryGroupRepository(),
  FixedClock(DateTime.utc(2026, 10, 12, 9)),
);
