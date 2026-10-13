import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/shared/lib/contact_fraction.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart'
    as ui;

/// Schéma du design system (`shared/ui`) correspondant à [diagram].
///
/// Conversion sans perte des champs que le design system représente : les
/// énumérations ont les mêmes valeurs des deux côtés. Elle vit en
/// présentation parce que le domaine ne connaît pas `shared/ui` et que
/// `shared/ui` ne connaît aucune entité.
ui.TableDiagramSpec tableDiagramSpecOf(ExerciseDiagram diagram) {
  final table = diagram.table;
  return ui.TableDiagramSpec(
    id: diagram.id,
    balls: [
      for (final b in table.balls)
        ui.DiagramBall(
          id: b.id,
          color: _color(b.color),
          at: b.at,
          role: b.role == null ? null : _role(b.role!),
          label: b.label,
          order: b.order,
        ),
    ],
    ghosts: [
      for (final g in table.ghosts)
        ui.DiagramGhost(
          id: g.id,
          at: g.at,
          role: switch (g.role) {
            TableGhostRole.cueStart => ui.DiagramGhostRole.cueStart,
            TableGhostRole.impact => ui.DiagramGhostRole.impact,
          },
          forBallId: g.forBallId,
          label: g.label,
        ),
    ],
    arrows: [
      for (final a in table.arrows)
        ui.DiagramArrow(
          id: a.id,
          kind: switch (a.kind) {
            TableArrowKind.object => ui.DiagramArrowKind.object,
            TableArrowKind.cue => ui.DiagramArrowKind.cue,
            TableArrowKind.indication => ui.DiagramArrowKind.indication,
          },
          path: a.path,
          ballId: a.ballId,
          bounces: [for (final band in a.bounces) _band(band)],
          pocket: a.pocket == null ? null : _pocket(a.pocket!),
          label: a.label,
          note: a.note,
        ),
    ],
    zones: [
      for (final z in table.zones)
        ui.DiagramZone(id: z.id, from: z.from, to: z.to, label: z.label),
    ],
    steps: [
      for (final s in table.steps)
        ui.DiagramStep(
          cueId: s.cueId,
          hitId: s.hitId,
          contact: s.contact == null ? null : contactFractionOf(s.contact!),
          pocket: s.pocket == null ? null : _pocket(s.pocket!),
          repeat: s.repeat,
          fromGhostId: s.fromGhostId,
          extras: s.extras,
        ),
    ],
  );
}

ui.BallKind _color(TableBallColor color) => switch (color) {
  TableBallColor.red => ui.BallKind.red,
  TableBallColor.yellow => ui.BallKind.yellow,
  TableBallColor.black => ui.BallKind.black,
  TableBallColor.white => ui.BallKind.white,
};

ui.DiagramBallRole _role(TableBallRole role) => switch (role) {
  TableBallRole.cue => ui.DiagramBallRole.cue,
  TableBallRole.object => ui.DiagramBallRole.object,
  TableBallRole.obstacle => ui.DiagramBallRole.obstacle,
};

ui.DiagramBand _band(TableBand band) => switch (band) {
  TableBand.top => ui.DiagramBand.top,
  TableBand.bottom => ui.DiagramBand.bottom,
  TableBand.left => ui.DiagramBand.left,
  TableBand.right => ui.DiagramBand.right,
};

ui.DiagramPocket _pocket(TablePocket pocket) => switch (pocket) {
  TablePocket.tl => ui.DiagramPocket.tl,
  TablePocket.tm => ui.DiagramPocket.tm,
  TablePocket.tr => ui.DiagramPocket.tr,
  TablePocket.bl => ui.DiagramPocket.bl,
  TablePocket.bm => ui.DiagramPocket.bm,
  TablePocket.br => ui.DiagramPocket.br,
};

/// Quantité de bille du design system pour [contact] (mêmes valeurs).
ContactFraction contactFractionOf(TableContact contact) => switch (contact) {
  TableContact.full => ContactFraction.full,
  TableContact.threeQuarter => ContactFraction.threeQuarter,
  TableContact.half => ContactFraction.half,
  TableContact.quarter => ContactFraction.quarter,
  TableContact.thin => ContactFraction.thin,
};
