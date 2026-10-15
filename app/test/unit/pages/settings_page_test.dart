import 'package:billard_cfa/entities/settings/domain/club_settings.dart';
import 'package:billard_cfa/features/manage_settings/presentation/bloc/settings_bloc.dart';
import 'package:billard_cfa/pages/settings/presentation/settings_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/ui/pump_ui.dart';

class _MockBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc;

void main() {
  testWidgets('shows the form under a title and goes back to More', (
    tester,
  ) async {
    final bloc = _MockBloc();
    whenListen(
      bloc,
      const Stream<SettingsState>.empty(),
      initialState: SettingsState(
        status: SettingsStatus.editing,
        saved: ClubSettings.defaults,
        draft: ClubSettings.defaults,
      ),
    );
    var back = 0;
    await pumpUi(
      tester,
      BlocProvider<SettingsBloc>.value(
        value: bloc,
        child: SettingsPage(onBack: () => back++),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Exercise validation'), findsOneWidget);
    await tester.tap(find.text('Back to More'));

    expect(back, 1);
  });
}
