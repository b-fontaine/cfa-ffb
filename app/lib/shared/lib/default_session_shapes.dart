import 'package:billard_cfa/shared/lib/audience.dart';
import 'package:billard_cfa/shared/lib/session_shape.dart';

/// Enfants 10/20/35/20/5 = 90 min ; adultes 10/25/50/25/10 = 120 min
/// `[U]` pour les durées totales, `[Prop]` pour le minutage interne.
const defaultSessionShapes = <Audience, SessionShape>{
  Audience.children: SessionShape(
    phases: [
      PhaseSlot(phase: SessionPhase.welcome, minutes: 10),
      PhaseSlot(phase: SessionPhase.notionAndInitiation, minutes: 20),
      PhaseSlot(phase: SessionPhase.training, minutes: 35),
      PhaseSlot(phase: SessionPhase.game, minutes: 20),
      PhaseSlot(phase: SessionPhase.review, minutes: 5),
    ],
    exerciseCount: 2,
    recallCount: 0,
  ),
  Audience.adults: SessionShape(
    phases: [
      PhaseSlot(phase: SessionPhase.welcome, minutes: 10),
      PhaseSlot(phase: SessionPhase.notionAndInitiation, minutes: 25),
      PhaseSlot(phase: SessionPhase.training, minutes: 50),
      PhaseSlot(phase: SessionPhase.game, minutes: 25),
      PhaseSlot(phase: SessionPhase.review, minutes: 10),
    ],
    exerciseCount: 2,
    recallCount: 1,
  ),
};
