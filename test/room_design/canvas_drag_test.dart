import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetspot/features/room_design/providers/room_provider.dart';
import 'package:sweetspot/features/room_design/screens/room_design_screen.dart';
import 'package:sweetspot/features/room_design/painters/room_painter.dart';

/// Drives the canvas the way a pointer does, so the gesture wiring is tested
/// rather than the maths underneath it.
/// The one CustomPaint that draws the plan.
final _planFinder = find.byWidgetPredicate(
  (widget) => widget is CustomPaint && widget.painter is RoomPainter,
);

void main() {
  late ProviderContainer container;

  Future<void> pumpCanvas(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoomDesignScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Where a room coordinate lands on screen, derived from the canvas box.
  Offset screenFor(WidgetTester tester, double xMeters, double yMeters) {
    final state = container.read(roomProvider);
    final canvasBox = tester.renderObject<RenderBox>(_planFinder);
    final topLeft = canvasBox.localToGlobal(Offset.zero);
    final scale = canvasBox.size.width / state.room.widthMeters;
    return topLeft + Offset(xMeters * scale, yMeters * scale);
  }

  double metersPerPixel(WidgetTester tester) {
    final state = container.read(roomProvider);
    final canvasBox = tester.renderObject<RenderBox>(_planFinder);
    return state.room.widthMeters / canvasBox.size.width;
  }

  testWidgets('dragging a speaker moves it', (tester) async {
    await pumpCanvas(tester);

    final before = container.read(roomProvider).leftSpeaker.position;
    final grabPoint = screenFor(tester, before.x, before.y);

    await tester.dragFrom(grabPoint, const Offset(60, 0));
    await tester.pumpAndSettle();

    final after = container.read(roomProvider).leftSpeaker.position;
    expect(
      after.x,
      greaterThan(before.x + 0.1),
      reason: 'the speaker should follow a drag to the right',
    );
  });

  testWidgets('a speaker grabbed off-centre does not jump to the cursor',
      (tester) async {
    await pumpCanvas(tester);

    final before = container.read(roomProvider).leftSpeaker.position;
    final mpp = metersPerPixel(tester);

    // Grab 12px right and 9px below the marker's centre, still inside its
    // hit radius, then drag 60px right.
    const grabOffsetPx = Offset(12, 9);
    final grabPoint = screenFor(tester, before.x, before.y) + grabOffsetPx;

    await tester.dragFrom(grabPoint, const Offset(60, 0));
    await tester.pumpAndSettle();

    final after = container.read(roomProvider).leftSpeaker.position;

    // Respecting the grab offset means it travels exactly the drag distance.
    expect(
      after.x,
      closeTo(before.x + 60 * mpp, 0.02),
      reason: 'x should advance by the drag distance, not snap to the cursor',
    );
    expect(
      after.y,
      closeTo(before.y, 0.02),
      reason: 'a purely horizontal drag must not shift the speaker vertically',
    );
  });

  testWidgets('dragging empty canvas leaves the placement alone',
      (tester) async {
    await pumpCanvas(tester);

    final before = container.read(roomProvider);
    // A point well away from every marker.
    final empty = screenFor(tester, 0.6, 5.4);

    await tester.dragFrom(empty, const Offset(70, 20));
    await tester.pumpAndSettle();

    final after = container.read(roomProvider);
    expect(after.leftSpeaker.position.x, before.leftSpeaker.position.x);
    expect(after.listeningPosition.position.x,
        before.listeningPosition.position.x);
  });
}
