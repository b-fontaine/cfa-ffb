import 'package:billard_cfa/entities/session_record/domain/session_record.dart';
import 'package:billard_cfa/features/review_session/domain/get_session_review.dart';
import 'package:billard_cfa/features/review_session/domain/session_review.dart';
import 'package:billard_cfa/features/review_session/presentation/bloc/session_review_bloc.dart';
import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGet extends Mock implements GetSessionReview;

void main() {
  late _MockGet get;
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

  setUp(() => get = _MockGet());

  blocTest<SessionReviewBloc, SessionReviewState>(
    'loads the review of the record',
    setUp: () => when(() => get(id)).thenAnswer((_) async => Ok(review)),
    build: () => SessionReviewBloc(get),
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
    build: () => SessionReviewBloc(get),
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
    build: () => SessionReviewBloc(get),
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
}
