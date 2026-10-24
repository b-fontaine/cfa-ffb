import 'package:billard_cfa/features/purge_stale_markers/domain/purge_stale_markers.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_cubit.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/bloc/stale_markers_state.dart';
import 'package:billard_cfa/features/purge_stale_markers/presentation/ui/stale_markers_card.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Club et rôles]';

Widget _padded(Widget child) => SingleChildScrollView(
  padding: const EdgeInsets.all(16),
  child: Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: child,
    ),
  ),
);

/// Les issues montrées par la carte.
enum _Shown { idle, running, completed, none, paused, interrupted, refused }

StaleMarkersState _state(_Shown shown) => switch (shown) {
  _Shown.idle => const StaleMarkersState.idle(),
  _Shown.running => const StaleMarkersState.running(),
  _Shown.completed => const StaleMarkersState.finished(
    StaleMarkerPurgeResult(
      status: StaleMarkerPurgeStatus.completed,
      removed: 3,
    ),
  ),
  _Shown.none => const StaleMarkersState.finished(
    StaleMarkerPurgeResult(
      status: StaleMarkerPurgeStatus.completed,
      removed: 0,
    ),
  ),
  _Shown.paused => const StaleMarkersState.finished(
    StaleMarkerPurgeResult(status: StaleMarkerPurgeStatus.paused, removed: 400),
  ),
  _Shown.interrupted => const StaleMarkersState.finished(
    StaleMarkerPurgeResult(
      status: StaleMarkerPurgeStatus.interrupted,
      removed: 2,
      failure: ServiceFailure(ServiceFailureCode.unavailable),
    ),
  ),
  _Shown.refused => const StaleMarkersState.finished(
    StaleMarkerPurgeResult(
      status: StaleMarkerPurgeStatus.failed,
      removed: 0,
      failure: ServiceFailure(ServiceFailureCode.denied),
    ),
  ),
};

@widgetbook.UseCase(
  name: 'Marqueurs abandonnés',
  type: StaleMarkersCard,
  path: _path,
)
Widget buildStaleMarkersCardUseCase(BuildContext context) => _padded(
  StaleMarkersCard(
    state: _state(
      context.knobs.object.dropdown<_Shown>(
        label: 'État',
        options: _Shown.values,
        labelBuilder: (value) => value.name,
      ),
    ),
    onPurge: () {},
  ),
);

@widgetbook.UseCase(
  name: 'Purge des marqueurs (cubit)',
  type: StaleMarkersSection,
  path: _path,
)
Widget buildStaleMarkersSectionUseCase(BuildContext context) => BlocProvider(
  create: (_) => StaleMarkersCubit(
    () async => const StaleMarkerPurgeResult(
      status: StaleMarkerPurgeStatus.completed,
      removed: 3,
    ),
  ),
  child: _padded(const StaleMarkersSection()),
);
