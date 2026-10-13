import 'dart:math' as math;

import 'package:billard_cfa/shared/lib/cue_side_geometry.dart';
import 'package:billard_cfa/shared/lib/illustration.dart';
import 'package:billard_cfa/shared/lib/player_figure_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Unité : la taille du joueur H (= 1). Joueur droitier, de profil, qui
  // regarde vers la droite ; y vers le haut, origine au sol.
  final surface = SidePose.of(CueBridge.surface);
  final frame = SidePose.of(CueBridge.frame);

  group('the invariants of the technical sheet n° 1 (side view)', () {
    test('the right foot is under the back hand', () {
      for (final pose in [surface, frame]) {
        expect(pose.rightFoot.x, closeTo(pose.backHand.x, 1e-9));
      }
    });

    test('the back forearm is vertical, the elbow above the hand', () {
      for (final pose in [surface, frame]) {
        expect(pose.elbow.x, closeTo(pose.backHand.x, 1e-9));
        expect(pose.elbow.y - pose.backHand.y, closeTo(0.15, 1e-9));
      }
    });

    test('the butt is raised by 10 degrees, never horizontal', () {
      final angle = math.atan2(
        surface.butt.y - surface.tip.y,
        surface.tip.x - surface.butt.x,
      );

      expect(angle, closeTo(cueElevation(CueHeight.level), 1e-9));
      expect(angle, closeTo(10 * math.pi / 180, 1e-9));
    });

    test('the cue line goes through the centre of the cue ball', () {
      final d = surface.tip - surface.butt;
      final c = surface.ballCenter - surface.butt;
      final cross = d.x * c.y - d.y * c.x;

      expect(cross / d.magnitude, closeTo(0, 1e-9));
      // La pointe touche la blanche : à un rayon du centre.
      expect(
        surface.tip.distanceTo(surface.ballCenter),
        closeTo(SidePose.drawnBallRadius, 1e-9),
      );
    });

    test('the cue is 0.83 H long and the table top at 0.48 H', () {
      expect(surface.tip.distanceTo(surface.butt), closeTo(0.83, 1e-9));
      expect(SidePose.tableTop, 0.48);
    });

    test('the cue ball rests on the cloth', () {
      expect(
        surface.ballCenter.y - SidePose.drawnBallRadius,
        closeTo(SidePose.tableTop, 1e-9),
      );
    });

    test('the head is on the cue axis side, above the cue', () {
      for (final pose in [surface, frame]) {
        final low = math.min(pose.bridgeHand.x, pose.backHand.x);
        final high = math.max(pose.bridgeHand.x, pose.backHand.x);

        expect(pose.head.x, greaterThan(low));
        expect(pose.head.x, lessThan(high));
        expect(
          pose.head.y - SidePose.headRadius,
          greaterThan(pose.cueHeightAt(pose.head.x)),
        );
      }
    });

    test('the bridge hand is on the cloth or on the rail, never below', () {
      expect(
        surface.bridgeHand.y - SidePose.handRadius,
        closeTo(SidePose.tableTop, 1e-9),
      );
      expect(
        frame.bridgeHand.y - SidePose.handRadius,
        closeTo(SidePose.railTop, 1e-9),
      );
      expect(SidePose.railTop, greaterThan(SidePose.tableTop));
    });

    test('the cue rests on the top of the bridge hand', () {
      for (final pose in [surface, frame]) {
        expect(
          pose.cueHeightAt(pose.bridgeHand.x),
          closeTo(pose.bridgeHand.y + SidePose.handRadius, 1e-9),
        );
      }
    });

    test('the rail bridge is further from the ball than the table bridge', () {
      expect(frame.bridgeHand.x, lessThan(surface.bridgeHand.x));
    });
  });

  group('the marks', () {
    test('has six numbered marks, in the order of the sheet', () {
      expect(PlayerMark.values, [
        PlayerMark.feet,
        PlayerMark.legsAndHips,
        PlayerMark.head,
        PlayerMark.backForearm,
        PlayerMark.bridgeHand,
        PlayerMark.cue,
      ]);
      expect(PlayerMark.cue.number, 6);
      expect(PlayerMark.feet.number, 1);
    });

    test('the side badges are inside the frame and do not touch', () {
      const frameRect = SidePose.frame;
      final centres = [
        for (final mark in PlayerMark.values) surface.badgeOf(mark),
      ];

      for (final c in centres) {
        expect(c.x, inInclusiveRange(frameRect.left, frameRect.right));
        expect(c.y, inInclusiveRange(frameRect.bottom, frameRect.top));
      }
      for (var i = 0; i < centres.length; i++) {
        for (var j = i + 1; j < centres.length; j++) {
          expect(
            centres[i].distanceTo(centres[j]),
            greaterThan(0.12),
            reason: '${PlayerMark.values[i]} / ${PlayerMark.values[j]}',
          );
        }
      }
    });

    test('the top view has no forearm and badges that do not touch', () {
      const marks = TopPose.visibleMarks;
      expect(marks, isNot(contains(PlayerMark.backForearm)));
      expect(marks, hasLength(5));

      final centres = [for (final m in marks) TopPose.badgeOf(m)];
      for (final c in centres) {
        expect(c.x, inInclusiveRange(0, 1));
        expect(c.y, inInclusiveRange(0, 1));
      }
      for (var i = 0; i < centres.length; i++) {
        for (var j = i + 1; j < centres.length; j++) {
          // L'aspect de la vue de dessus est 2 : x compte double.
          final dx = (centres[i].x - centres[j].x) * TopPose.aspect;
          final dy = centres[i].y - centres[j].y;
          expect(math.sqrt(dx * dx + dy * dy), greaterThan(0.2));
        }
      }
    });
  });

  group('the top view', () {
    test('the right foot is under the back hand and the cue on the axis', () {
      expect(TopPose.rightFoot.x, TopPose.backHand.x);
      expect(TopPose.backHand.y, 0.5);
      expect(TopPose.butt.y, 0.5);
      expect(TopPose.ball.y, 0.5);
    });

    test('the right of the player is below the axis, the left above', () {
      expect(TopPose.rightFoot.y, greaterThan(0.5));
      expect(TopPose.leftFoot.y, lessThan(0.5));
      expect(TopPose.eye(LeadEye.right).y, greaterThan(0.5));
      expect(TopPose.eye(LeadEye.left).y, lessThan(0.5));
    });

    test('the head case puts the right eye, the middle or the left eye on '
        'the cue', () {
      expect(
        TopPose.eye(LeadEye.right, HeadCase.rightEyeOverCue).y,
        closeTo(0.5, 1e-9),
      );
      expect(
        TopPose.eye(LeadEye.left, HeadCase.leftEyeOverCue).y,
        closeTo(0.5, 1e-9),
      );
      final right = TopPose.eye(LeadEye.right, HeadCase.cueBetweenEyes).y;
      final left = TopPose.eye(LeadEye.left, HeadCase.cueBetweenEyes).y;

      expect((right + left) / 2, closeTo(0.5, 1e-9));
      expect(TopPose.headCentre(HeadCase.cueBetweenEyes).y, 0.5);
    });

    test('the cue, the head, the bridge and the ball follow one another', () {
      expect(TopPose.butt.x, lessThan(TopPose.head.x));
      expect(TopPose.head.x, lessThan(TopPose.bridge.x));
      expect(TopPose.bridge.x, lessThan(TopPose.ball.x));
    });
  });

  group('top view details', () {
    test('the eyes, with their discs, stay inside the head of 0.12 h', () {
      // Unités : x en largeur (aspect 1,6), y en hauteur ; rayons en h.
      for (final headCase in [...HeadCase.values, null]) {
        final head = TopPose.headCentre(headCase);
        for (final which in LeadEye.values) {
          final eye = TopPose.eye(which, headCase);
          final dx = (eye.x - head.x) * TopPose.aspect;
          final dy = eye.y - head.y;

          // Œil directeur : disque de 0,04 h.
          expect(
            math.sqrt(dx * dx + dy * dy) + 0.04,
            lessThanOrEqualTo(0.12),
            reason: '$which $headCase',
          );
        }
      }
    });

    test(
      'the bridge hand lies on the rail for a frame, beside it otherwise',
      () {
        final (frameFrom, frameTo) = TopPose.railSpan(CueBridge.frame);
        final (surfaceFrom, surfaceTo) = TopPose.railSpan(CueBridge.surface);

        expect(TopPose.bridge.x, inInclusiveRange(frameFrom, frameTo));
        expect(TopPose.bridge.x, greaterThan(surfaceTo));
        expect(surfaceFrom, lessThan(surfaceTo));
        // La blanche est sur le tapis, après le rail.
        expect(TopPose.ball.x, greaterThan(frameTo));
      },
    );
  });
}
