import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetspot/features/room_design/providers/room_provider.dart';
import 'package:sweetspot/features/room_design/screens/room_design_screen.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RoomDesignScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the app identity and the inspector sections',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('Sweetspot'), findsOneWidget);
    expect(find.text('Placement quality'), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('Geometry'), findsOneWidget);
    expect(find.text('Toe-in'), findsOneWidget);
  });

  testWidgets('the advice bar offers the next change to make', (tester) async {
    await pumpApp(tester);

    // The default room is not optimal, so there is something to act on.
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('applying the advice improves the placement score',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoomDesignScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final before = container
        .read(_sweetSpot)
        .triangleAccuracy;

    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    final after = container.read(_sweetSpot).triangleAccuracy;
    expect(after, greaterThan(before));
  });
}

// Imported lazily so the test file reads top-down.
final _sweetSpot = sweetSpotResultProvider;
