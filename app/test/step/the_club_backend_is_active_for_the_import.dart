import 'package:flutter_test/flutter_test.dart';

import '../support/club_import_app_world.dart';

/// Usage: the club backend is active for the import
///
/// Le build est `DATA_BACKEND=firestore` : « Plus » mène à l'import dans le
/// club, la sauvegarde locale renvoie vers lui.
Future<void> theClubBackendIsActiveForTheImport(WidgetTester tester) =>
    useClubBackendForImport(tester);
