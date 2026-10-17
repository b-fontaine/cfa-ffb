import 'package:billard_cfa/features/review_session/domain/set_session_tags.dart';
import 'package:billard_cfa/shared/lib/failure.dart';
import 'package:billard_cfa/shared/lib/identifiers.dart';
import 'package:billard_cfa/shared/lib/session_tag.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/domain_world.dart';

void main() {
  late DomainWorld world;
  const id = SessionId('x12');

  setUp(() async {
    world = DomainWorld();
    await world.seedClub(studentNames: ['s1', 's2']);
    await world.session(id: 'x12', dayOfMonth: 12, present: {'s1', 's2'});
  });

  test('replaces the tags of the session and nothing else', () async {
    final before = (await world.sessions.byId(id))!;

    final result = await SetSessionTags(world.sessions)(id, {
      SessionTag.tooLong,
      SessionTag.toRedo,
    });

    expect(result, isA<Ok<void>>());
    final after = (await world.sessions.byId(id))!;
    expect(after.tags, {SessionTag.tooLong, SessionTag.toRedo});
    expect(after, before.copyWith(tags: after.tags));
  });

  test('clears the tags with an empty set', () async {
    final set = SetSessionTags(world.sessions);
    await set(id, {SessionTag.tooLong});

    await set(id, const {});

    expect((await world.sessions.byId(id))!.tags, isEmpty);
  });

  test('refuses an unknown session', () async {
    final failure = err(
      await SetSessionTags(world.sessions)(const SessionId('nope'), {
        SessionTag.tooLong,
      }),
    );

    expect(failure, isA<NotFound>());
  });
}
