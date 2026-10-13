import 'package:billard_cfa/shared/ui/ball_kind.dart';
import 'package:billard_cfa/shared/ui/billiard_ball.dart';
import 'package:flutter_test/flutter_test.dart';

/// Usage: the white ball is {0.945} times the size of the {'yellow'} ball
Future<void> theWhiteBallIsTimesTheSizeOfTheBall(
  WidgetTester tester,
  num ratio,
  String color,
) async {
  final kind = switch (color) {
    'yellow' => BallKind.yellow,
    'red' => BallKind.red,
    'black' => BallKind.black,
    _ => throw ArgumentError('groupe de billes inconnu : $color'),
  };
  Finder of(BallKind k) =>
      find.byWidgetPredicate((w) => w is BilliardBall && w.kind == k);
  final white = tester.getSize(of(BallKind.white)).width;
  final other = tester.getSize(of(kind)).width;

  expect(white / other, closeTo(ratio, 0.001));
  expect(white, lessThan(other));
}
