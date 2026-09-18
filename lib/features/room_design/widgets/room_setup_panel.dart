import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../acoustic/models/sweet_spot_result.dart';
import '../models/room.dart';
import '../models/room_state.dart';
import '../providers/room_provider.dart';

/// The inspector: everything you can set, grouped the way you think about it
/// — the room first, then where the speakers point, then what the geometry
/// works out to, then what is in the way.
///
/// Measurements are the content here, so they sit in a right-hand column
/// with tabular figures and line up down the panel.
class RoomSetupPanel extends ConsumerStatefulWidget {
  const RoomSetupPanel({super.key});

  @override
  ConsumerState<RoomSetupPanel> createState() => _RoomSetupPanelState();
}

class _RoomSetupPanelState extends ConsumerState<RoomSetupPanel> {
  final _widthController = TextEditingController();
  final _lengthController = TextEditingController();
  bool _initialized = false;
  Room? _lastSeenRoom;

  @override
  void dispose() {
    _widthController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  void _syncControllersFromRoom(Room room) {
    _widthController.text = room.widthMeters.toStringAsFixed(1);
    _lengthController.text = room.lengthMeters.toStringAsFixed(1);
    _lastSeenRoom = room;
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider);
    final sweetSpot = ref.watch(sweetSpotResultProvider);
    final room = roomState.room;

    if (!_initialized) {
      _syncControllersFromRoom(room);
      _initialized = true;
    } else if (_lastSeenRoom != null &&
        (_lastSeenRoom!.widthMeters != room.widthMeters ||
            _lastSeenRoom!.lengthMeters != room.lengthMeters) &&
        _widthController.text ==
            _lastSeenRoom!.widthMeters.toStringAsFixed(1) &&
        _lengthController.text ==
            _lastSeenRoom!.lengthMeters.toStringAsFixed(1)) {
      _syncControllersFromRoom(room);
    }

    return Container(
      color: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          _Score(result: sweetSpot),
          const SizedBox(height: 24),

          _Group(
            title: 'Room',
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DimensionField(
                      label: 'Width',
                      controller: _widthController,
                      onSubmitted: (value) => _applyDimension(room, width: value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DimensionField(
                      label: 'Length',
                      controller: _lengthController,
                      onSubmitted: (value) => _applyDimension(room, length: value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Reading(label: 'Floor area', value: '${room.area.toStringAsFixed(1)} m²'),
            ],
          ),

          _Group(
            title: 'Geometry',
            children: [
              _Reading(
                label: 'Speaker spacing',
                value: '${sweetSpot.speakerSpacing.toStringAsFixed(2)} m',
              ),
              _Reading(
                label: 'Listening distance',
                value: '${sweetSpot.listeningDistance.toStringAsFixed(2)} m',
              ),
              _Reading(
                label: 'Left to ear',
                value: '${sweetSpot.leftDistance.toStringAsFixed(2)} m',
              ),
              _Reading(
                label: 'Right to ear',
                value: '${sweetSpot.rightDistance.toStringAsFixed(2)} m',
              ),
              _Reading(
                label: 'Symmetry',
                value: '${(sweetSpot.symmetryRatio * 100).toStringAsFixed(0)}%',
                // Asymmetry pulls the stereo image off centre, so it is worth
                // flagging on its own rather than only inside the score.
                valueColor: sweetSpot.symmetryRatio >= 0.98
                    ? AppTheme.textPrimary
                    : AppTheme.warning,
              ),
            ],
          ),

          _ToeInGroup(roomState: roomState),

          _BlockerGroup(roomState: roomState),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => ref.read(roomProvider.notifier).resetToDefaults(),
              child: const Text('Reset room'),
            ),
          ),
        ],
      ),
    );
  }

  void _applyDimension(Room room, {String? width, String? length}) {
    final parsedWidth = double.tryParse((width ?? '').replaceAll(',', '.'));
    final parsedLength = double.tryParse((length ?? '').replaceAll(',', '.'));

    final next = room.copyWith(
      widthMeters: parsedWidth?.clamp(1.5, 20.0),
      lengthMeters: parsedLength?.clamp(1.5, 20.0),
    );
    ref.read(roomProvider.notifier).updateRoom(next);
    _syncControllersFromRoom(next);
  }
}

// ── Score ────────────────────────────────────────────────────────────────

/// The headline number, with the sentence that explains it. Both take the
/// same colour ramp as the plan, so nothing in the app contradicts itself.
class _Score extends StatelessWidget {
  final SweetSpotResult result;

  const _Score({required this.result});

  @override
  Widget build(BuildContext context) {
    final percent = (result.triangleAccuracy * 100).round();
    final color = AppTheme.quality(result.triangleAccuracy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Placement quality',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            letterSpacing: -0.05,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent.toDouble()),
              duration: AppTheme.motionMedium,
              curve: AppTheme.easeStandard,
              builder: (context, value, _) => Text(
                value.round().toString(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1.2,
                  height: 1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Text(
              '/100',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: result.triangleAccuracy.clamp(0.0, 1.0)),
            duration: AppTheme.motionMedium,
            curve: AppTheme.easeStandard,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: AppTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          result.feedback,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.45,
            letterSpacing: -0.05,
          ),
        ),
      ],
    );
  }
}

// ── Building blocks ──────────────────────────────────────────────────────

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _Group({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The sidebar is resizable, so the header has to survive being
          // narrowed rather than overflow at the minimum width.
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (trailing != null)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing!,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label left, figure right, tabular so a column of them aligns.
class _Reading extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Reading({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                letterSpacing: -0.05,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  const _DimensionField({
    required this.label,
    required this.controller,
    required this.onSubmitted,
  });

  @override
  State<_DimensionField> createState() => _DimensionFieldState();
}

class _DimensionFieldState extends State<_DimensionField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Commit when the field loses focus, so clicking away keeps what was
    // typed. Tying this to focus rather than to any tap elsewhere matters:
    // an unfocused field must not re-apply itself every time the canvas is
    // dragged.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        widget.onSubmitted(widget.controller.text);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: const InputDecoration(
            suffixText: 'm',
            suffixStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            isDense: true,
          ),
          onSubmitted: (value) {
            widget.onSubmitted(value);
            _focusNode.unfocus();
          },
        ),
      ],
    );
  }
}

// ── Toe-in ───────────────────────────────────────────────────────────────

class _ToeInGroup extends ConsumerWidget {
  final RoomState roomState;

  const _ToeInGroup({required this.roomState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendedLeft = ref.watch(recommendedLeftToeInProvider);
    final recommendedRight = ref.watch(recommendedRightToeInProvider);
    final notifier = ref.read(roomProvider.notifier);

    final matchesRecommendation =
        (roomState.leftSpeaker.toeInDegrees - recommendedLeft).abs() < 0.5 &&
            (roomState.rightSpeaker.toeInDegrees - recommendedRight).abs() < 0.5;

    return _Group(
      title: 'Toe-in',
      trailing: matchesRecommendation
          ? const Text(
              'Recommended',
              style: TextStyle(color: AppTheme.success, fontSize: 12),
            )
          : TextButton(
              onPressed: () {
                notifier.updateLeftSpeakerToeIn(recommendedLeft);
                notifier.updateRightSpeakerToeIn(recommendedRight);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Recommend'),
            ),
      children: [
        _ToeInSlider(
          channel: 'Left',
          value: roomState.leftSpeaker.toeInDegrees,
          recommended: recommendedLeft,
          onChanged: notifier.updateLeftSpeakerToeIn,
        ),
        const SizedBox(height: 6),
        _ToeInSlider(
          channel: 'Right',
          value: roomState.rightSpeaker.toeInDegrees,
          recommended: recommendedRight,
          onChanged: notifier.updateRightSpeakerToeIn,
        ),
      ],
    );
  }
}

class _ToeInSlider extends StatelessWidget {
  final String channel;
  final double value;
  final double recommended;
  final ValueChanged<double> onChanged;

  const _ToeInSlider({
    required this.channel,
    required this.value,
    required this.recommended,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                channel,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  letterSpacing: -0.05,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}°',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'rec ${recommended.toStringAsFixed(0)}°',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value.clamp(0.0, 45.0),
            min: 0,
            max: 45,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// ── Blockers ─────────────────────────────────────────────────────────────

class _BlockerGroup extends ConsumerWidget {
  final RoomState roomState;

  const _BlockerGroup({required this.roomState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = roomState.blockerZones;
    final notifier = ref.read(roomProvider.notifier);

    return _Group(
      title: 'Obstacles',
      trailing: zones.isEmpty
          ? null
          : TextButton(
              onPressed: notifier.clearBlockedZones,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Clear all'),
            ),
      children: [
        if (zones.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 2),
            child: Text(
              'Turn on Blockers in the view bar, then drag over anything the '
              'speakers cannot be placed on.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
                letterSpacing: -0.05,
              ),
            ),
          )
        else
          ...zones.map(
            (zone) => MouseRegion(
              onEnter: (_) =>
                  ref.read(hoveredBlockerIdProvider.notifier).state = zone.id,
              onExit: (_) =>
                  ref.read(hoveredBlockerIdProvider.notifier).state = null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${zone.width.toStringAsFixed(2)} × '
                        '${zone.height.toStringAsFixed(2)} m',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 15),
                      color: AppTheme.textTertiary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      splashRadius: 14,
                      tooltip: 'Remove',
                      onPressed: () => notifier.removeBlockedZone(zone.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
