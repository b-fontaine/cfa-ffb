import 'package:billard_cfa/app/auth/auth_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/auth_rig.dart';

void main() {
  test('notifies at every change of the session state', () async {
    final rig = AuthRig();
    addTearDown(rig.cubit.close);
    final refresh = AuthRefresh(rig.cubit);
    var notified = 0;
    refresh.addListener(() => notified++);

    await rig.cubit.start();
    await pumpEventQueue();

    expect(notified, 1);
    refresh.dispose();
  });
}
