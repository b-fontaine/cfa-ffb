import 'package:billard_cfa/entities/session_record/data/firestore_session_record_repository.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/operations_world.dart';

Future<void> laPremiereSaisieDePorteLetiquette(
  WidgetTester tester,
  String name,
  String tag,
) async {
  await OperationsWorld.current.seeding(
    (w) => FirestoreSessionRecordRepository(w.seeder)
        .setTags(SessionId(w.firstRecord[name]!), {SessionTag.tryParse(tag)!}),
  );
}
