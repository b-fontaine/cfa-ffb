import 'dart:async';

import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/review_session/domain/get_session_review.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/features/review_session/domain/set_session_tags.dart';
import 'package:billard_cfa/features/review_session/presentation/bloc/session_review_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGet extends Mock implements GetSessionReview;

class _MockSetTags extends Mock implements SetSessionTags;

void main() {
  late _MockGet get;
  late _MockSetTags setTags;
  const id = SessionId('x1');
  final review = SessionReview(
    record: SessionRecord(
      id: id,
      groupId: const GroupId('g1'),
      seasonId: const SeasonId('season'),
      date: DateTime(2026, 10, 12),
      audience: Audience.children,
      present: const {},
    ),
    outcome: const SessionOutcome(),
    proposedDate: DateTime(2026, 10, 19),
  );

  setUp(() {
    get = _MockGet();
    setTags = _MockSetTags();
  });

  blocTest<SessionReviewBloc, SessionReviewState>(
    'loads the review of the record',
    setUp: () => when(() => get(id)).thenAnswer((_) async => Ok(review)),
    build: () => SessionReviewBloc(get, setTags),
    act: (bloc) => bloc.add(const SessionReviewEvent.started(id)),
    expect: () => [
      SessionReviewState(status: SessionReviewStatus.ready, review: review),
    ],
  );

  blocTest<SessionReviewBloc, SessionReviewState>(
    'reports an unknown record as NotFound',
    setUp: () => when(() => get(id)).thenAnswer(
      (_) async => const Err<SessionReview>(NotFound('session', 'x1')),
    ),
    build: () => SessionReviewBloc(get, setTags),
    act: (bloc) => bloc.add(const SessionReviewEvent.started(id)),
    expect: () => [
      const SessionReviewState(
        status: SessionReviewStatus.failure,
        failure: NotFound('session', 'x1'),
      ),
    ],
  );

  blocTest<SessionReviewBloc, SessionReviewState>(
    'shows loading again when reloaded after a failure',
    setUp: () => when(() => get(id)).thenAnswer((_) async => Ok(review)),
    build: () => SessionReviewBloc(get, setTags),
    seed: () => const SessionReviewState(
      status: SessionReviewStatus.failure,
      failure: NotFound('session', 'x1'),
    ),
    act: (bloc) => bloc.add(const SessionReviewEvent.started(id)),
    expect: () => [
      const SessionReviewState(),
      SessionReviewState(status: SessionReviewStatus.ready, review: review),
    ],
  );

  group('tagsChanged', () {
    final ready = SessionReviewState(
      status: SessionReviewStatus.ready,
      review: review,
    );
    final tags = {SessionTag.tooLong, SessionTag.toRedo};

    blocTest<SessionReviewBloc, SessionReviewState>(
      'saves the tags then shows them on the record of the review',
      setUp: () =>
          when(() => setTags(id, tags))
              .thenAnswer((_) async => const Ok<void>(null)),
      build: () => SessionReviewBloc(get, setTags),
      seed: () => ready,
      act: (bloc) => bloc.add(SessionReviewEvent.tagsChanged(tags)),
      expect: () => [
        SessionReviewState(
          status: SessionReviewStatus.ready,
          review: review.copyWith(record: review.record.copyWith(tags: tags)),
        ),
      ],
      verify: (_) => verify(() => setTags(id, tags)).called(1),
    );

    blocTest<SessionReviewBloc, SessionReviewState>(
      'keeps the review, restores the previous tags and reports the failure',
      setUp: () => when(() => setTags(id, tags))
          .thenAnswer((_) async => const Err<void>(NotFound('session', 'x1'))),
      build: () => SessionReviewBloc(get, setTags),
      seed: () => ready,
      act: (bloc) => bloc.add(SessionReviewEvent.tagsChanged(tags)),
      expect: () => [
        SessionReviewState(
          status: SessionReviewStatus.ready,
          review: review.copyWith(record: review.record.copyWith(tags: tags)),
        ),
        SessionReviewState(
          status: SessionReviewStatus.ready,
          review: ready.review,
          tagsFailure: const NotFound('session', 'x1'),
        ),
      ],
    );

    Future<SessionReviewBloc> opened() async {
      when(() => get(id)).thenAnswer((_) async => Ok(review));
      final bloc = SessionReviewBloc(get, setTags)
        ..add(const SessionReviewEvent.started(id));
      await pumpEventQueue();
      return bloc;
    }

    test('clears a reported failure as soon as a new change is made', () async {
      when(() => setTags(id, tags))
          .thenAnswer((_) async => const Err<void>(NotFound('session', 'x1')));
      when(() => setTags(id, {SessionTag.tooLong}))
          .thenAnswer((_) async => const Ok<void>(null));
      final bloc = await opened();
      bloc.add(SessionReviewEvent.tagsChanged(tags));
      await pumpEventQueue();
      expect(bloc.state.tagsFailure, isA<NotFound>());
      bloc.add(const SessionReviewEvent.tagsChanged({SessionTag.tooLong}));
      await pumpEventQueue();
      expect(bloc.state.tagsFailure, isNull);
      expect(bloc.state.review!.record.tags, {SessionTag.tooLong});
      await bloc.close();
    });

    test(
      'two quick changes keep both: the second builds on the first',
      () async {
        final first = Completer<Result<void>>();
        when(() => setTags(id, {SessionTag.tooLong}))
            .thenAnswer((_) => first.future);
        when(() => setTags(id, {SessionTag.tooLong, SessionTag.toRedo}))
            .thenAnswer((_) async => const Ok<void>(null));
        final bloc = await opened();
        bloc.add(const SessionReviewEvent.tagsChanged({SessionTag.tooLong}));
        await pumpEventQueue();
        // La première écriture n'est pas terminée : l'écran montre déjà son
        // résultat, d'où part le second choix.
        expect(bloc.state.review!.record.tags, {SessionTag.tooLong});
        bloc.add(
          const SessionReviewEvent.tagsChanged({
            SessionTag.tooLong,
            SessionTag.toRedo,
          }),
        );
        await pumpEventQueue();
        first.complete(const Ok<void>(null));
        await pumpEventQueue();
        expect(bloc.state.review!.record.tags, {
          SessionTag.tooLong,
          SessionTag.toRedo,
        });
        expect(bloc.state.tagsFailure, isNull);
        await bloc.close();
      },
    );

    blocTest<SessionReviewBloc, SessionReviewState>(
      'ignores a change while no review is shown',
      build: () => SessionReviewBloc(get, setTags),
      act: (bloc) => bloc.add(SessionReviewEvent.tagsChanged(tags)),
      expect: () => <SessionReviewState>[],
      verify: (_) => verifyNever(() => setTags(any(), any())),
    );
  });
}
