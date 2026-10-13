import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the cue ball is {0.945} times the size of the object ball
Future<void> theCueBallIsTimesTheSizeOfTheObjectBall(
  WidgetTester tester,
  num ratio,
) async {
  final white = find.byWidgetPredicate(
    (w) => w is BilliardBall && w.kind == BallKind.white,
  );
  final red = find.byWidgetPredicate(
    (w) => w is BilliardBall && w.kind == BallKind.red,
  );
  final measured = tester.getSize(white).width / tester.getSize(red).width;

  expect(measured, closeTo(ratio, 0.001));
  expect(tester.getSize(white).width, lessThan(tester.getSize(red).width));
}
