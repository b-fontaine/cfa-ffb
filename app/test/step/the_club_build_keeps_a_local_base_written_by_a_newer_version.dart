import 'package:flutter_test/flutter_test.dart';

import '../support/local_data_world.dart';

/// Usage: the club build keeps a local base written by a newer version
Future<void> theClubBuildKeepsALocalBaseWrittenByANewerVersion(
  WidgetTester tester,
) => LocalDataWorld.keepNewer(tester);
