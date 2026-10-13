import 'package:billard_cfa/entities/exercise_diagram/domain/diagram_table.dart';
import 'package:billard_cfa/entities/exercise_diagram/domain/exercise_diagram.dart';
import 'package:billard_cfa/entities/exercise_diagram/presentation/table_diagram_mapper.dart';
import 'package:billard_cfa/shared/ui/table_diagram/table_diagram_spec.dart'
    as ui;
import 'package:flutter_test/flutter_test.dart';

ExerciseDiagram _diagram(DiagramTable table) => ExerciseDiagram(
  id: 'x-p01-e1',
  kind: DiagramKind.exercise,
  sheet: 'Fiche',
  caption: 'Légende',
  description: 'Description',
  sourceFile: 'Test.pdf',
  sourcePage: 1,
  table: table,
);

void main() {
  group('a complete diagram', () {
    final spec = tableDiagramSpecOf(
      _diagram(
        const DiagramTable(
          balls: [
            TableBall(
              id: 'r1',
              color: TableBallColor.red,
              at: TablePoint(1, 2),
              role: TableBallRole.object,
              label: 'x4',
              order: 2,
            ),
            TableBall(
              id: 'w',
              color: TableBallColor.white,
              at: TablePoint(3, 3),
            ),
          ],
          ghosts: [
            TableGhost(
              id: 'g',
              at: TablePoint(1, 1),
              role: TableGhostRole.cueStart,
              forBallId: 'w',
              label: '1',
            ),
          ],
          arrows: [
            TableArrow(
              id: 'a',
              kind: TableArrowKind.cue,
              path: [TablePoint(3, 3), TablePoint(4, 0), TablePoint(1, 2)],
              ballId: 'w',
              bounces: [TableBand.top],
              pocket: TablePocket.bm,
              label: 'L',
              note: 'N',
            ),
          ],
          zones: [
            TableZone(
              id: 'z',
              from: TablePoint(0, 0),
              to: TablePoint(2, 4),
              label: 'zone',
            ),
          ],
          steps: [
            TableStep(
              cueId: 'w',
              hitId: 'r1',
              contact: TableContact.half,
              pocket: TablePocket.tl,
              repeat: 3,
              fromGhostId: 'g',
              extras: {'effect': 'rétro'},
            ),
          ],
        ),
      ),
    );

    test('keeps the id', () {
      expect(spec.id, 'x-p01-e1');
    });

    test('maps balls', () {
      expect(spec.balls, const [
        ui.DiagramBall(
          id: 'r1',
          color: ui.BallKind.red,
          at: ui.DiagramPoint(1, 2),
          role: ui.DiagramBallRole.object,
          label: 'x4',
          order: 2,
        ),
        ui.DiagramBall(
          id: 'w',
          color: ui.BallKind.white,
          at: ui.DiagramPoint(3, 3),
        ),
      ]);
    });

    test('maps ghosts', () {
      expect(spec.ghosts, const [
        ui.DiagramGhost(
          id: 'g',
          at: ui.DiagramPoint(1, 1),
          role: ui.DiagramGhostRole.cueStart,
          forBallId: 'w',
          label: '1',
        ),
      ]);
    });

    test('maps arrows', () {
      expect(spec.arrows, const [
        ui.DiagramArrow(
          id: 'a',
          kind: ui.DiagramArrowKind.cue,
          path: [
            ui.DiagramPoint(3, 3),
            ui.DiagramPoint(4, 0),
            ui.DiagramPoint(1, 2),
          ],
          ballId: 'w',
          bounces: [ui.DiagramBand.top],
          pocket: ui.DiagramPocket.bm,
          label: 'L',
          note: 'N',
        ),
      ]);
    });

    test('maps zones', () {
      expect(spec.zones, const [
        ui.DiagramZone(
          id: 'z',
          from: ui.DiagramPoint(0, 0),
          to: ui.DiagramPoint(2, 4),
          label: 'zone',
        ),
      ]);
    });

    test('maps steps', () {
      expect(spec.steps, const [
        ui.DiagramStep(
          cueId: 'w',
          hitId: 'r1',
          contact: ui.ContactFraction.half,
          pocket: ui.DiagramPocket.tl,
          repeat: 3,
          fromGhostId: 'g',
          extras: {'effect': 'rétro'},
        ),
      ]);
    });
  });

  group('every value of an enumeration keeps its name', () {
    final spec = tableDiagramSpecOf(
      _diagram(
        DiagramTable(
          balls: [
            for (final c in TableBallColor.values)
              TableBall(id: c.name, color: c, at: const TablePoint(1, 1)),
            for (final r in TableBallRole.values)
              TableBall(
                id: 'r-${r.name}',
                color: TableBallColor.red,
                at: const TablePoint(1, 1),
                role: r,
              ),
          ],
          ghosts: [
            for (final r in TableGhostRole.values)
              TableGhost(id: r.name, at: const TablePoint(1, 1), role: r),
          ],
          arrows: [
            for (final k in TableArrowKind.values)
              TableArrow(id: k.name, kind: k, path: const []),
            const TableArrow(
              id: 'bands',
              kind: TableArrowKind.cue,
              path: [],
              bounces: TableBand.values,
            ),
            for (final p in TablePocket.values)
              TableArrow(
                id: 'p-${p.name}',
                kind: TableArrowKind.object,
                path: const [],
                pocket: p,
              ),
          ],
          steps: [
            for (final c in TableContact.values)
              TableStep(cueId: 'w', contact: c),
          ],
        ),
      ),
    );

    test('ball colors', () {
      expect(
        spec.balls.take(TableBallColor.values.length).map((b) => b.color.name),
        TableBallColor.values.map((c) => c.name),
      );
    });

    test('ball roles', () {
      expect(
        spec.balls.skip(TableBallColor.values.length).map((b) => b.role!.name),
        TableBallRole.values.map((r) => r.name),
      );
    });

    test('ghost roles', () {
      expect(
        spec.ghosts.map((g) => g.role.name),
        TableGhostRole.values.map((r) => r.name),
      );
    });

    test('arrow kinds', () {
      expect(
        spec.arrows.take(3).map((a) => a.kind.name),
        TableArrowKind.values.map((k) => k.name),
      );
    });

    test('bands', () {
      expect(
        spec.arrows[3].bounces.map((b) => b.name),
        TableBand.values.map((b) => b.name),
      );
    });

    test('pockets', () {
      expect(
        spec.arrows.skip(4).map((a) => a.pocket!.name),
        TablePocket.values.map((p) => p.name),
      );
    });

    test('contacts', () {
      expect(
        spec.steps.map((s) => s.contact!.name),
        TableContact.values.map((c) => c.name),
      );
    });
  });

  group('contactFractionOf', () {
    test('gives the design system fraction of the same name', () {
      expect(
        TableContact.values.map((c) => contactFractionOf(c).name),
        TableContact.values.map((c) => c.name),
      );
    });
  });
}
