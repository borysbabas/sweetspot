import 'dart:math' as math;

import '../../room_design/models/listening_position.dart';
import '../../room_design/models/room.dart';
import '../../room_design/models/room_position.dart';
import '../../room_design/models/speaker.dart';
import '../models/reflection_point.dart';

/// Works out where sound bounces off each wall on its way to the listener.
///
/// Uses the image-source method: mirror the speaker through a wall, draw a
/// straight line from that mirrored source to the listener, and wherever it
/// crosses the wall is the point the real sound reflects from. For a
/// rectangular room the first-order points are exactly the ones worth
/// treating, because they arrive soon enough after the direct sound to smear
/// the stereo image.
class ReflectionCalculator {
  const ReflectionCalculator();

  /// How much of the sound survives a bounce. Real rooms vary enormously;
  /// these are mid-range values for typical domestic surfaces, and high
  /// frequencies are absorbed more than low ones.
  static const double _hfReflectance = 0.55;
  static const double _lfReflectance = 0.85;

  List<ReflectionPoint> calculateReflections({
    required Room room,
    required Speaker leftSpeaker,
    required Speaker rightSpeaker,
    required ListeningPosition listeningPosition,
  }) {
    final listener = listeningPosition.position;

    return [
      for (final speaker in [leftSpeaker, rightSpeaker])
        for (final wall in ReflectionWall.values)
          ..._reflectionFor(
            room: room,
            speaker: speaker,
            listener: listener,
            wall: wall,
          ),
    ];
  }

  /// Zero or one point per speaker per wall — none when the bounce would land
  /// off the end of the wall, which means that path never reaches the ear.
  Iterable<ReflectionPoint> _reflectionFor({
    required Room room,
    required Speaker speaker,
    required RoomPosition listener,
    required ReflectionWall wall,
  }) sync* {
    final source = speaker.position;
    final image = _mirror(source, room, wall);

    // Where the line from the mirrored source to the listener meets the wall.
    final crossing = _wallCrossing(image, listener, room, wall);
    if (crossing == null) return;

    // A path is only real if the wall lies between the two points.
    if (!_withinWall(crossing, room, wall)) return;

    final directDistance = _distance(source, listener);
    final pathLength = _distance(image, listener);
    if (pathLength <= 0) return;

    // Inverse-distance law: the longer way round arrives quieter. Expressed
    // relative to the direct sound, which is what actually matters for how
    // audible the reflection is.
    final relative = directDistance <= 0
        ? 0.0
        : (directDistance / pathLength).clamp(0.0, 1.0);

    // A speaker pointed away from a wall throws less energy at it.
    final aim = _aimFactor(speaker, crossing);

    yield ReflectionPoint(
      wall: wall,
      position: crossing,
      speakerPosition: source,
      listenerPosition: listener,
      strength: (relative * aim).clamp(0.0, 1.0),
      highFrequencyStrength: (relative * aim * _hfReflectance).clamp(0.0, 1.0),
      lowFrequencyStrength: (relative * aim * _lfReflectance).clamp(0.0, 1.0),
    );
  }

  /// The speaker mirrored through the given wall.
  RoomPosition _mirror(RoomPosition p, Room room, ReflectionWall wall) {
    switch (wall) {
      case ReflectionWall.left:
        return RoomPosition(-p.x, p.y);
      case ReflectionWall.right:
        return RoomPosition(2 * room.widthMeters - p.x, p.y);
      case ReflectionWall.front:
        return RoomPosition(p.x, -p.y);
      case ReflectionWall.back:
        return RoomPosition(p.x, 2 * room.lengthMeters - p.y);
    }
  }

  /// Intersection of the image-source line with the wall's plane.
  RoomPosition? _wallCrossing(
    RoomPosition image,
    RoomPosition listener,
    Room room,
    ReflectionWall wall,
  ) {
    switch (wall) {
      case ReflectionWall.left:
      case ReflectionWall.right:
        final target = wall == ReflectionWall.left ? 0.0 : room.widthMeters;
        final span = listener.x - image.x;
        if (span.abs() < 1e-9) return null;
        final t = (target - image.x) / span;
        if (t <= 0 || t >= 1) return null;
        return RoomPosition(target, image.y + t * (listener.y - image.y));

      case ReflectionWall.front:
      case ReflectionWall.back:
        final target = wall == ReflectionWall.front ? 0.0 : room.lengthMeters;
        final span = listener.y - image.y;
        if (span.abs() < 1e-9) return null;
        final t = (target - image.y) / span;
        if (t <= 0 || t >= 1) return null;
        return RoomPosition(image.x + t * (listener.x - image.x), target);
    }
  }

  /// Walls are finite, so a crossing past the corner is not a real bounce.
  bool _withinWall(RoomPosition p, Room room, ReflectionWall wall) {
    const tolerance = 1e-6;
    switch (wall) {
      case ReflectionWall.left:
      case ReflectionWall.right:
        return p.y >= -tolerance && p.y <= room.lengthMeters + tolerance;
      case ReflectionWall.front:
      case ReflectionWall.back:
        return p.x >= -tolerance && p.x <= room.widthMeters + tolerance;
    }
  }

  /// 1.0 straight ahead, tapering off-axis. Toe-in genuinely changes how much
  /// energy reaches a side wall, which is why toeing speakers in tames the
  /// side-wall reflection.
  double _aimFactor(Speaker speaker, RoomPosition target) {
    final forward = speakerForwardAxis(speaker);
    final dx = target.x - speaker.position.x;
    final dy = target.y - speaker.position.y;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length < 1e-9) return 1.0;

    final cosAngle = (forward.$1 * dx + forward.$2 * dy) / length;
    if (cosAngle <= 0) return 0.08; // behind the baffle, but never silent
    // A gentle taper rather than a cliff — real dispersion is broad.
    return (0.25 + 0.75 * cosAngle).clamp(0.0, 1.0);
  }

  double _distance(RoomPosition a, RoomPosition b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Unit vector the speaker points along, given its toe-in.
  static (double, double) speakerForwardAxis(Speaker speaker) {
    final toeInRad = speaker.toeInDegrees * math.pi / 180;
    final xSign = speaker.channel == SpeakerChannel.left ? 1.0 : -1.0;
    final fx = math.sin(toeInRad) * xSign;
    final fy = math.cos(toeInRad);
    final len = math.sqrt(fx * fx + fy * fy);
    if (len < 1e-9) return (0.0, 1.0);
    return (fx / len, fy / len);
  }
}
