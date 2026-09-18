import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/editable_distance_target.dart';
import '../models/room_position.dart';
import '../models/room_state.dart';
import '../painters/room_painter.dart';
import '../providers/room_provider.dart';

class RoomCanvas extends ConsumerStatefulWidget {
  const RoomCanvas({super.key});

  @override
  ConsumerState<RoomCanvas> createState() => _RoomCanvasState();
}

class _RoomCanvasState extends ConsumerState<RoomCanvas>
    with SingleTickerProviderStateMixin {
  _DragTarget? _activeDrag;

  /// Where inside the marker it was grabbed, so it doesn't jump to the cursor.
  Offset _grabOffset = Offset.zero;

  /// Needed to turn a global pointer position into canvas coordinates before
  /// the gesture is claimed.
  final GlobalKey _planKey = GlobalKey();
  bool _hoveringMarker = false;

  bool _showGrid = true;
  bool _showReflections = true;
  bool _showTriangle = true;
  bool _showMeasurements = true;
  bool _drawBlockersMode = false;

  Offset? _blockerStartPx;
  Offset? _blockerCurrentPx;
  int? _activeBlockerDragId;
  Offset? _activeBlockerDragStartPx;
  RoomPosition? _activeBlockerOriginalTopLeft;

  late final AnimationController _introController;
  bool _introCompleted = false;

  static const double _hitRadius = 20.0;
  static const double _measurementHitPadding = 6.0;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_introCompleted && mounted) {
        setState(() => _introCompleted = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _introController.forward();
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final sweetSpotResult = ref.watch(sweetSpotResultProvider);
    final reflections = ref.watch(reflectionPointsProvider);
    final recommendedAimingPoint = ref.watch(recommendedAimingPointProvider);
    final hoveredBlockerId = ref.watch(hoveredBlockerIdProvider);

    final room = roomState.room;

    return AnimatedBuilder(
      animation: _introController,
      builder: (context, _) {
        final rawProgress = _introCompleted
            ? 1.0
            : Curves.easeOutCubic.transform(
                _introController.value.clamp(0.0, 1.0),
              );
        final introProgress = rawProgress >= 0.995 ? 1.0 : rawProgress;

        return Column(
          children: [
            _buildToolbar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Fill the available box, leaving a uniform padding inset.
                  const padding = 24.0;
                  final availableWidth = constraints.maxWidth - padding * 2;
                  final availableHeight = constraints.maxHeight - padding * 2;

                  final scaleX = availableWidth / room.widthMeters;
                  final scaleY = availableHeight / room.lengthMeters;
                  final scale = math.min(scaleX, scaleY);

                  final canvasWidth = room.widthMeters * scale;
                  final canvasHeight = room.lengthMeters * scale;

                  final roomPainter = RoomPainter(
                    roomState: roomState,
                    sweetSpotResult: sweetSpotResult,
                    reflectionPoints: reflections,
                    recommendedAimingPoint: recommendedAimingPoint,
                    scale: scale,
                    showGrid: _showGrid,
                    showReflections: _showReflections,
                    showTriangle: _showTriangle,
                    showMeasurements: _showMeasurements,
                    hoveredBlockerId: hoveredBlockerId,
                    introProgress: introProgress,
                  );

                  return Container(
                    color: AppTheme.canvasField,
                    child: InteractiveViewer(
                      constrained: false,
                      minScale: 0.5,
                      maxScale: 5.0,
                      // Without slack the view is pinned at 1x and panning does
                      // nothing, which made every drag feel dead.
                      boundaryMargin: const EdgeInsets.all(240),
                      child: Padding(
                        padding: const EdgeInsets.all(padding),
                        child: Center(
                          child: MouseRegion(
                            // Say what is draggable before it is grabbed.
                            cursor: _drawBlockersMode
                                ? SystemMouseCursors.precise
                                : _hoveringMarker
                                    ? SystemMouseCursors.grab
                                    : MouseCursor.defer,
                            onHover: (event) => _onCanvasHover(
                              event.localPosition,
                              roomState,
                              canvasWidth,
                            ),
                            onExit: (_) {
                              if (_activeBlockerDragId == null) {
                                ref
                                    .read(hoveredBlockerIdProvider.notifier)
                                    .state = null;
                              }
                              if (_hoveringMarker) {
                                setState(() => _hoveringMarker = false);
                              }
                            },
                            child: RawGestureDetector(
                              gestures: {
                                _MarkerDragRecognizer:
                                    GestureRecognizerFactoryWithHandlers<
                                        _MarkerDragRecognizer>(
                                  () => _MarkerDragRecognizer(),
                                  (recognizer) {
                                    recognizer.shouldClaim = (globalPosition) {
                                      return _shouldClaimDrag(
                                        globalPosition,
                                        roomState,
                                        canvasWidth,
                                      );
                                    };
                                    recognizer.onStart = (details) {
                                      _handleDragStart(
                                        details,
                                        roomState,
                                        canvasWidth,
                                        canvasHeight,
                                      );
                                    };
                                    recognizer.onUpdate = (details) {
                                      _handleDragUpdate(
                                        details,
                                        roomState,
                                        canvasWidth,
                                        canvasHeight,
                                      );
                                    };
                                    recognizer.onEnd = (_) {
                                      _handleDragEnd(
                                        roomState,
                                        canvasWidth,
                                        canvasHeight,
                                      );
                                    };
                                  },
                                ),
                              },
                              child: GestureDetector(
                                onTapUp: (details) =>
                                    _onTapUp(details, roomState, roomPainter),
                                child: SizedBox(
                                  key: _planKey,
                                  width: canvasWidth,
                                  height: canvasHeight,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: CustomPaint(painter: roomPainter),
                                      ),
                                      if (_blockerPreviewRect != null)
                                        Positioned.fromRect(
                                          rect: _blockerPreviewRect!,
                                          child: IgnorePointer(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppTheme.blockerFill,
                                                border: Border.all(
                                                  color: AppTheme.accent,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Turns a global pointer position into coordinates on the plan.
  Offset _toPlanLocal(Offset globalPosition) {
    final box = _planKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return globalPosition;
    return box.globalToLocal(globalPosition);
  }

  /// Only take the gesture when there is something under the pointer to move.
  /// Anything else is left to InteractiveViewer so the plan can still be
  /// panned and zoomed.
  bool _shouldClaimDrag(
    Offset globalPosition,
    RoomState roomState,
    double canvasWidth,
  ) {
    if (_drawBlockersMode) return true;
    return _markerAt(_toPlanLocal(globalPosition), roomState, canvasWidth) !=
        null;
  }

  /// The draggable marker under a point on the plan, if any.
  _DragTarget? _markerAt(
    Offset localPosition,
    RoomState roomState,
    double canvasWidth,
  ) {
    final scale = canvasWidth / roomState.room.widthMeters;

    final candidates = <_DragTarget, Offset>{
      _DragTarget.leftSpeaker: Offset(
        roomState.leftSpeaker.position.x * scale,
        roomState.leftSpeaker.position.y * scale,
      ),
      _DragTarget.rightSpeaker: Offset(
        roomState.rightSpeaker.position.x * scale,
        roomState.rightSpeaker.position.y * scale,
      ),
      _DragTarget.listeningPosition: Offset(
        roomState.listeningPosition.position.x * scale,
        roomState.listeningPosition.position.y * scale,
      ),
    };

    _DragTarget? best;
    var bestDistance = double.infinity;
    for (final entry in candidates.entries) {
      final distance = _distancePx(localPosition, entry.value);
      if (distance <= _hitRadius && distance < bestDistance) {
        best = entry.key;
        bestDistance = distance;
      }
    }
    return best;
  }

  void _handleDragStart(
    DragStartDetails details,
    RoomState roomState,
    double canvasWidth,
    double canvasHeight,
  ) {
    final local = _toPlanLocal(details.globalPosition);

    if (_drawBlockersMode) {
      _onBlockerPanStart(
        DragStartDetails(
          localPosition: local,
          globalPosition: details.globalPosition,
        ),
        roomState,
        canvasWidth,
        canvasHeight,
      );
      return;
    }

    final target = _markerAt(local, roomState, canvasWidth);
    if (target == null) return;

    final scale = canvasWidth / roomState.room.widthMeters;
    final centre = switch (target) {
      _DragTarget.leftSpeaker => Offset(
          roomState.leftSpeaker.position.x * scale,
          roomState.leftSpeaker.position.y * scale,
        ),
      _DragTarget.rightSpeaker => Offset(
          roomState.rightSpeaker.position.x * scale,
          roomState.rightSpeaker.position.y * scale,
        ),
      _DragTarget.listeningPosition => Offset(
          roomState.listeningPosition.position.x * scale,
          roomState.listeningPosition.position.y * scale,
        ),
    };

    setState(() {
      _activeDrag = target;
      // Keep hold of where inside the marker it was grabbed, so it travels
      // with the pointer instead of snapping its centre under the cursor.
      _grabOffset = centre - local;
    });
  }

  void _handleDragUpdate(
    DragUpdateDetails details,
    RoomState roomState,
    double canvasWidth,
    double canvasHeight,
  ) {
    final local = _toPlanLocal(details.globalPosition);

    if (_drawBlockersMode) {
      _onBlockerPanUpdate(
        DragUpdateDetails(
          localPosition: local,
          globalPosition: details.globalPosition,
          delta: details.delta,
        ),
        roomState,
        canvasWidth,
        canvasHeight,
      );
      return;
    }

    if (_activeDrag == null) return;

    final scale = canvasWidth / roomState.room.widthMeters;
    final adjusted = _clampToCanvas(local + _grabOffset, canvasWidth, canvasHeight);
    final roomPos = RoomPosition(adjusted.dx / scale, adjusted.dy / scale);

    final notifier = ref.read(roomProvider.notifier);
    switch (_activeDrag!) {
      case _DragTarget.leftSpeaker:
        notifier.updateLeftSpeakerPosition(roomPos);
        break;
      case _DragTarget.rightSpeaker:
        notifier.updateRightSpeakerPosition(roomPos);
        break;
      case _DragTarget.listeningPosition:
        notifier.updateListeningPosition(roomPos);
        break;
    }
  }

  void _handleDragEnd(
    RoomState roomState,
    double canvasWidth,
    double canvasHeight,
  ) {
    if (_drawBlockersMode) {
      _onBlockerPanEnd(roomState, canvasWidth, canvasHeight);
      return;
    }
    if (_activeDrag != null) {
      setState(() {
        _activeDrag = null;
        _grabOffset = Offset.zero;
      });
    }
  }

  Rect? get _blockerPreviewRect {
    if (_activeBlockerDragId != null) return null;
    if (_blockerStartPx == null || _blockerCurrentPx == null) return null;
    return Rect.fromPoints(_blockerStartPx!, _blockerCurrentPx!);
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.borderSoft, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // What the plan shows, grouped as one control because these
            // options belong to the same question.
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  _ToolbarToggle(
                    icon: Icons.grid_4x4_rounded,
                    label: 'Grid',
                    active: _showGrid,
                    onTap: () => setState(() => _showGrid = !_showGrid),
                  ),
                  _ToolbarToggle(
                    icon: Icons.change_history_rounded,
                    label: 'Triangle',
                    active: _showTriangle,
                    onTap: () => setState(() => _showTriangle = !_showTriangle),
                  ),
                  _ToolbarToggle(
                    icon: Icons.spoke_rounded,
                    label: 'Reflections',
                    active: _showReflections,
                    onTap: () =>
                        setState(() => _showReflections = !_showReflections),
                  ),
                  _ToolbarToggle(
                    icon: Icons.straighten_rounded,
                    label: 'Measurements',
                    active: _showMeasurements,
                    onTap: () =>
                        setState(() => _showMeasurements = !_showMeasurements),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Drawing obstacles is a mode, not a view option, so it sits
            // apart from the group above.
            _ModeButton(
              icon: Icons.crop_free_rounded,
              label: 'Blockers',
              active: _drawBlockersMode,
              onTap: () => setState(() {
                _drawBlockersMode = !_drawBlockersMode;
                if (!_drawBlockersMode) {
                  _blockerStartPx = null;
                  _blockerCurrentPx = null;
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _onTapUp(
    TapUpDetails details,
    RoomState roomState,
    RoomPainter painter,
  ) {
    if (!_showMeasurements) return;

    final tapPos = details.localPosition;
    final hit = painter
        .measurementHitTargets()
        .where((target) =>
            target.rect.inflate(_measurementHitPadding).contains(tapPos))
        .fold<MeasurementHitTarget?>(
      null,
      (best, current) {
        if (best == null) return current;
        final bestDist = _distanceToRectCenter(tapPos, best.rect);
        final currentDist = _distanceToRectCenter(tapPos, current.rect);
        return currentDist < bestDist ? current : best;
      },
    );

    if (hit == null) return;
    _showMeasurementInputDialog(roomState, hit);
  }

  Future<void> _showMeasurementInputDialog(
    RoomState roomState,
    MeasurementHitTarget hit,
  ) async {
    final maxDistance = _maxDistanceForWall(roomState, hit.target.wall);
    final label = _distanceLabel(hit.target);
    final controller =
        TextEditingController(text: hit.distanceMeters.toStringAsFixed(2));

    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set $label distance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Enter distance in meters (0.00 - ${maxDistance.toStringAsFixed(2)}).'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Distance (m)',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                onSubmitted: (_) {
                  final parsed = double.tryParse(controller.text.trim());
                  Navigator.of(context).pop(parsed);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );

    if (value == null) return;
    if (value.isNaN || value.isInfinite || value < 0 || value > maxDistance) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Distance must be between 0 and ${maxDistance.toStringAsFixed(2)} m.',
          ),
        ),
      );
      return;
    }

    ref.read(roomProvider.notifier).setDistanceToWall(
          entity: hit.target.entity,
          wall: hit.target.wall,
          distanceMeters: value,
        );
  }

  String _distanceLabel(EditableDistanceTarget target) {
    final entity = switch (target.entity) {
      MeasuredEntity.focus => 'Focus',
      MeasuredEntity.leftSpeaker => 'Left speaker',
      MeasuredEntity.rightSpeaker => 'Right speaker',
    };

    final wall = switch (target.wall) {
      RoomWall.left => 'left wall',
      RoomWall.right => 'right wall',
      RoomWall.front => 'front wall',
      RoomWall.back => 'back wall',
    };

    return '$entity to $wall';
  }

  double _maxDistanceForWall(RoomState roomState, RoomWall wall) {
    switch (wall) {
      case RoomWall.left:
      case RoomWall.right:
        return roomState.room.widthMeters;
      case RoomWall.front:
      case RoomWall.back:
        return roomState.room.lengthMeters;
    }
  }

  double _distanceToRectCenter(Offset point, Rect rect) {
    return _distancePx(point, rect.center);
  }

  double _distancePx(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _onBlockerPanStart(
    DragStartDetails details,
    RoomState roomState,
    double canvasWidth,
    double canvasHeight,
  ) {
    final clamped =
        _clampToCanvas(details.localPosition, canvasWidth, canvasHeight);
    final scale = canvasWidth / roomState.room.widthMeters;
    final hitId = _blockerIdAt(clamped, roomState, scale);

    if (hitId != null) {
      final zone = roomState.blockerZones.firstWhere((z) => z.id == hitId);
      _activeBlockerDragId = hitId;
      _activeBlockerDragStartPx = clamped;
      _activeBlockerOriginalTopLeft = RoomPosition(zone.x, zone.y);
      ref.read(hoveredBlockerIdProvider.notifier).state = hitId;
      return;
    }

    setState(() {
      _blockerStartPx = clamped;
      _blockerCurrentPx = _blockerStartPx;
      _activeBlockerDragId = null;
      _activeBlockerDragStartPx = null;
      _activeBlockerOriginalTopLeft = null;
    });
  }

  void _onBlockerPanUpdate(
    DragUpdateDetails details,
    RoomState roomState,
    double canvasWidth,
    double canvasHeight,
  ) {
    final clamped =
        _clampToCanvas(details.localPosition, canvasWidth, canvasHeight);

    if (_activeBlockerDragId != null &&
        _activeBlockerDragStartPx != null &&
        _activeBlockerOriginalTopLeft != null) {
      final scale = canvasWidth / roomState.room.widthMeters;
      final dxMeters = (clamped.dx - _activeBlockerDragStartPx!.dx) / scale;
      final dyMeters = (clamped.dy - _activeBlockerDragStartPx!.dy) / scale;
      ref.read(roomProvider.notifier).moveBlockedZone(
            zoneId: _activeBlockerDragId!,
            topLeft: RoomPosition(
              _activeBlockerOriginalTopLeft!.x + dxMeters,
              _activeBlockerOriginalTopLeft!.y + dyMeters,
            ),
          );
      return;
    }

    if (_blockerStartPx == null) return;
    setState(() {
      _blockerCurrentPx = clamped;
    });
  }

  void _onBlockerPanEnd(
    RoomState roomState,
    double canvasWidth,
    double canvasHeight,
  ) {
    if (_activeBlockerDragId != null) {
      _activeBlockerDragId = null;
      _activeBlockerDragStartPx = null;
      _activeBlockerOriginalTopLeft = null;
      return;
    }

    final start = _blockerStartPx;
    final end = _blockerCurrentPx;

    if (start != null && end != null) {
      final scale = canvasWidth / roomState.room.widthMeters;
      ref.read(roomProvider.notifier).addBlockedZoneFromPoints(
            RoomPosition(start.dx / scale, start.dy / scale),
            RoomPosition(end.dx / scale, end.dy / scale),
          );
    }

    setState(() {
      _blockerStartPx = null;
      _blockerCurrentPx = null;
    });
  }

  void _onCanvasHover(
    Offset localPosition,
    RoomState roomState,
    double canvasWidth,
  ) {
    final scale = canvasWidth / roomState.room.widthMeters;
    final id = _blockerIdAt(localPosition, roomState, scale);
    if (ref.read(hoveredBlockerIdProvider) != id) {
      ref.read(hoveredBlockerIdProvider.notifier).state = id;
    }

    final overMarker =
        _markerAt(localPosition, roomState, canvasWidth) != null;
    if (overMarker != _hoveringMarker) {
      setState(() => _hoveringMarker = overMarker);
    }
  }

  int? _blockerIdAt(Offset localPosition, RoomState roomState, double scale) {
    final roomPos =
        RoomPosition(localPosition.dx / scale, localPosition.dy / scale);
    for (final zone in roomState.blockerZones.reversed) {
      if (zone.contains(roomPos)) {
        return zone.id;
      }
    }
    return null;
  }

  Offset _clampToCanvas(Offset pos, double canvasWidth, double canvasHeight) {
    return Offset(
      pos.dx.clamp(0.0, canvasWidth).toDouble(),
      pos.dy.clamp(0.0, canvasHeight).toDouble(),
    );
  }
}

enum _DragTarget { leftSpeaker, rightSpeaker, listeningPosition }

class _ToolbarToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToolbarToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: AppTheme.easeStandard,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppTheme.border : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall - 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: -0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A mode you switch on, so it takes the interactive colour when active.
class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.motionFast,
          curve: AppTheme.easeStandard,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppTheme.accent : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: active ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pan that only enters the gesture arena when the pointer actually starts
/// on something draggable.
///
/// The plan lives inside an [InteractiveViewer], whose scale recognizer wins
/// against an ordinary pan. Staying out of the arena unless there is a marker
/// under the pointer lets both work: grab a marker and you move it, drag
/// anywhere else and the view pans.
class _MarkerDragRecognizer extends PanGestureRecognizer {
  /// Whether a pointer going down here should begin a drag.
  bool Function(Offset globalPosition)? shouldClaim;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (shouldClaim?.call(event.position) != true) {
      // Not ours — never join the arena, so InteractiveViewer takes it.
      return;
    }
    super.addAllowedPointer(event);
    // Claim it straight away, otherwise the enclosing scale recognizer wins
    // the moment the pointer moves.
    resolve(GestureDisposition.accepted);
  }
}
