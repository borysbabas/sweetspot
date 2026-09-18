import 'package:flutter_test/flutter_test.dart';
import 'package:sweetspot/features/acoustic/models/reflection_point.dart';
import 'package:sweetspot/features/acoustic/services/reflection_calculator.dart';
import 'package:sweetspot/features/room_design/models/listening_position.dart';
import 'package:sweetspot/features/room_design/models/room.dart';
import 'package:sweetspot/features/room_design/models/room_position.dart';
import 'package:sweetspot/features/room_design/models/speaker.dart';

void main() {
  const calculator = ReflectionCalculator();
  const room = Room(widthMeters: 6.0, lengthMeters: 8.0);

  group('ReflectionCalculator', () {
    test('calculates reflections for speaker', () {
      const leftSpeaker = Speaker(
        channel: SpeakerChannel.left,
        position: RoomPosition(1.5, 1.5),
      );
      const rightSpeaker = Speaker(
        channel: SpeakerChannel.right,
        position: RoomPosition(4.5, 1.5),
      );
      const listener = ListeningPosition(
        position: RoomPosition(3.0, 5.0),
      );

      final reflections = calculator.calculateReflections(
        room: room,
        leftSpeaker: leftSpeaker,
        rightSpeaker: rightSpeaker,
        listeningPosition: listener,
      );

      expect(reflections, isNotEmpty);
      for (final r in reflections) {
        expect(r.position.x, greaterThanOrEqualTo(0));
        expect(r.position.x, lessThanOrEqualTo(room.widthMeters));
        expect(r.position.y, greaterThanOrEqualTo(0));
        expect(r.position.y, lessThanOrEqualTo(room.lengthMeters));
      }
    });

    test('reflection point is on the correct wall', () {
      const leftSpeaker = Speaker(
        channel: SpeakerChannel.left,
        position: RoomPosition(1.5, 1.5),
      );
      const rightSpeaker = Speaker(
        channel: SpeakerChannel.right,
        position: RoomPosition(4.5, 1.5),
      );
      const listener = ListeningPosition(
        position: RoomPosition(3.0, 5.0),
      );

      final reflections = calculator.calculateReflections(
        room: room,
        leftSpeaker: leftSpeaker,
        rightSpeaker: rightSpeaker,
        listeningPosition: listener,
      );

      for (final rp in reflections) {
        switch (rp.wall) {
          case ReflectionWall.left:
            expect(rp.position.x, closeTo(0.0, 0.001));
            break;
          case ReflectionWall.right:
            expect(rp.position.x, closeTo(room.widthMeters, 0.001));
            break;
          case ReflectionWall.front:
            expect(rp.position.y, closeTo(0.0, 0.001));
            break;
          case ReflectionWall.back:
            expect(rp.position.y, closeTo(room.lengthMeters, 0.001));
            break;
        }
      }
    });

    test('does not return reflections outside room bounds', () {
      const leftSpeaker = Speaker(
        channel: SpeakerChannel.left,
        position: RoomPosition(1.5, 1.5),
      );
      const rightSpeaker = Speaker(
        channel: SpeakerChannel.right,
        position: RoomPosition(4.5, 1.5),
      );
      const listener = ListeningPosition(
        position: RoomPosition(3.0, 5.0),
      );

      final reflections = calculator.calculateReflections(
        room: room,
        leftSpeaker: leftSpeaker,
        rightSpeaker: rightSpeaker,
        listeningPosition: listener,
      );

      for (final rp in reflections) {
        expect(rp.position.x, greaterThanOrEqualTo(0));
        expect(rp.position.x, lessThanOrEqualTo(room.widthMeters));
        expect(rp.position.y, greaterThanOrEqualTo(0));
        expect(rp.position.y, lessThanOrEqualTo(room.lengthMeters));
      }
    });

    test('returns multiple reflections', () {
      const leftSpeaker = Speaker(
        channel: SpeakerChannel.left,
        position: RoomPosition(1.5, 1.5),
      );
      const rightSpeaker = Speaker(
        channel: SpeakerChannel.right,
        position: RoomPosition(4.5, 1.5),
      );
      const listener = ListeningPosition(
        position: RoomPosition(3.0, 5.0),
      );

      final reflections = calculator.calculateReflections(
        room: room,
        leftSpeaker: leftSpeaker,
        rightSpeaker: rightSpeaker,
        listeningPosition: listener,
      );

      expect(reflections.length, greaterThan(2));
    });

    // A first-reflection point is fixed by geometry: mirror the speaker
    // through the wall and aim at the listener. Rotating the speaker on the
    // spot cannot move that point — it changes how much energy travels down
    // that path, which is exactly why toeing in tames side-wall reflections.
    test('toe-in changes reflection strength, not its position', () {
      const leftZero = Speaker(
        channel: SpeakerChannel.left,
        position: RoomPosition(1.5, 1.5),
        toeInDegrees: 0,
      );
      const rightZero = Speaker(
        channel: SpeakerChannel.right,
        position: RoomPosition(4.5, 1.5),
        toeInDegrees: 0,
      );
      final leftToeIn = leftZero.copyWith(toeInDegrees: 20);
      final rightToeIn = rightZero.copyWith(toeInDegrees: 20);
      const listener = ListeningPosition(
        position: RoomPosition(3.0, 5.0),
      );

      final base = calculator.calculateReflections(
        room: room,
        leftSpeaker: leftZero,
        rightSpeaker: rightZero,
        listeningPosition: listener,
      );
      final steered = calculator.calculateReflections(
        room: room,
        leftSpeaker: leftToeIn,
        rightSpeaker: rightToeIn,
        listeningPosition: listener,
      );

      expect(base, isNotEmpty);
      expect(steered, isNotEmpty);
      expect(base.length, equals(steered.length));

      for (var i = 0; i < base.length; i++) {
        expect(
          base[i].position.x,
          closeTo(steered[i].position.x, 0.001),
          reason: 'reflection geometry does not depend on toe-in',
        );
        expect(base[i].position.y, closeTo(steered[i].position.y, 0.001));
        expect(base[i].wall, equals(steered[i].wall));
      }

      final changed = <int>[];
      for (var i = 0; i < base.length; i++) {
        if ((base[i].strength - steered[i].strength).abs() > 0.001) {
          changed.add(i);
        }
      }
      expect(changed, isNotEmpty,
          reason: 'toeing the speakers in must change how hard they hit the walls');

      // Toeing in points the speakers away from the side walls, so the side
      // reflections should weaken rather than strengthen.
      final baseSide = base
          .where((r) =>
              r.wall == ReflectionWall.left || r.wall == ReflectionWall.right)
          .fold<double>(0, (sum, r) => sum + r.strength);
      final steeredSide = steered
          .where((r) =>
              r.wall == ReflectionWall.left || r.wall == ReflectionWall.right)
          .fold<double>(0, (sum, r) => sum + r.strength);
      expect(steeredSide, lessThan(baseSide),
          reason: 'toe-in should reduce side-wall energy');
    });
  });

  group('ReflectionPoint', () {
    test('wallLabel returns correct string', () {
      const rp = ReflectionPoint(
        wall: ReflectionWall.left,
        position: RoomPosition(0, 3),
        speakerPosition: RoomPosition(1.5, 1.5),
        listenerPosition: RoomPosition(3.0, 5.0),
      );
      expect(rp.wallLabel, equals('Left Wall'));
    });
  });
}
