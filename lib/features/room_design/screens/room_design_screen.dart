import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../acoustic/models/optimization_result.dart';
import '../../acoustic/models/sweet_spot_result.dart';
import '../providers/room_provider.dart';
import '../widgets/room_canvas.dart';
import '../widgets/room_setup_panel.dart';

/// The app is one window: chrome on top, an inspector on the left, the room
/// plan filling everything else, and — the change that matters most — the
/// single most useful instruction pinned along the bottom.
///
/// The whole point of the app is answering "what should I move?", and that
/// answer used to be buried three sections down a scrolling sidebar.
class RoomDesignScreen extends ConsumerWidget {
  const RoomDesignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width > 820;
    final sweetSpot = ref.watch(sweetSpotResultProvider);
    final optimization = ref.watch(optimizationResultProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _Toolbar(result: sweetSpot),
          Expanded(
            child: isWide
                ? const _WideLayout()
                : const _NarrowLayout(),
          ),
          _AdviceBar(optimization: optimization),
        ],
      ),
    );
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final SweetSpotResult result;

  const _Toolbar({required this.result});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.82),
            border: const Border(
              bottom: BorderSide(color: AppTheme.borderSoft, width: 1),
            ),
          ),
          child: Row(
            children: [
              const Text(
                'Sweetspot',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Room optimiser',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              ),
              const Spacer(),
              _QualityBadge(result: result),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                color: AppTheme.textSecondary,
                onPressed: () => _showHelp(context),
                tooltip: 'How to use',
                splashRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        title: const Text(
          'How to use',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        content: const SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _HelpItem(
                  title: 'Drag to place',
                  description:
                      'Drag L, R or the listening marker to move them around the room.',
                ),
                _HelpItem(
                  title: 'Type an exact distance',
                  description:
                      'Click any measurement label to enter a precise figure instead of dragging.',
                ),
                _HelpItem(
                  title: 'Read the triangle',
                  description:
                      'The dashed triangle is your stereo geometry. Equilateral gives the sharpest image.',
                ),
                _HelpItem(
                  title: 'Mark what is in the way',
                  description:
                      'Turn on Blockers in the view bar and drag over furniture so the optimiser avoids it.',
                ),
                _HelpItem(
                  title: 'Follow the advice bar',
                  description:
                      'The bar along the bottom always shows the one change that would help most.',
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 20, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// The score, in the colour it earns. Same ramp as the plan marker, so the
/// badge and the drawing never disagree.
class _QualityBadge extends StatelessWidget {
  final SweetSpotResult result;

  const _QualityBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final percent = (result.triangleAccuracy * 100).round();
    final color = AppTheme.quality(result.triangleAccuracy);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          const Text(
            'Placement',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 7),
          AnimatedDefaultTextStyle(
            duration: AppTheme.motionFast,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            child: Text('$percent'),
          ),
        ],
      ),
    );
  }
}

// ── Advice bar ───────────────────────────────────────────────────────────

/// One line: the most valuable change you could make, and a way to make it.
class _AdviceBar extends ConsumerWidget {
  final OptimizationResult optimization;

  const _AdviceBar({required this.optimization});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settled = !optimization.hasMeaningfulImprovement ||
        optimization.instructions.isEmpty;
    final gain = (optimization.scoreDelta * 100).round();

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.borderSoft, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: settled ? AppTheme.success : AppTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppTheme.motionMedium,
              switchInCurve: AppTheme.easeStandard,
              child: Text(
                settled
                    ? 'This placement is about as good as the room allows.'
                    : optimization.instructions.first.text,
                key: ValueKey(
                  settled ? 'settled' : optimization.instructions.first.text,
                ),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  letterSpacing: -0.1,
                  height: 1.3,
                ),
              ),
            ),
          ),
          if (!settled) ...[
            const SizedBox(width: 16),
            Text(
              '+$gain',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => ref
                  .read(roomProvider.notifier)
                  .applyOptimizedPlacement(optimization.optimizedState),
              child: const Text('Apply'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Layouts ──────────────────────────────────────────────────────────────

class _WideLayout extends StatefulWidget {
  const _WideLayout();

  @override
  State<_WideLayout> createState() => _WideLayoutState();
}

class _WideLayoutState extends State<_WideLayout> {
  double _sidebarWidth = 282;
  static const double _minWidth = 240;
  static const double _maxWidth = 460;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: _sidebarWidth, child: const RoomSetupPanel()),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragStart: (_) => setState(() => _isDragging = true),
            onHorizontalDragUpdate: (d) => setState(() {
              _sidebarWidth =
                  (_sidebarWidth + d.delta.dx).clamp(_minWidth, _maxWidth);
            }),
            onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
            child: AnimatedContainer(
              duration: AppTheme.motionFast,
              width: 1,
              color: _isDragging ? AppTheme.accent : AppTheme.borderSoft,
            ),
          ),
        ),
        const Expanded(child: RoomCanvas()),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(flex: 58, child: RoomCanvas()),
        Divider(height: 1, thickness: 1, color: AppTheme.borderSoft),
        Expanded(flex: 42, child: RoomSetupPanel()),
      ],
    );
  }
}

// ── Help ─────────────────────────────────────────────────────────────────

class _HelpItem extends StatelessWidget {
  final String title;
  final String description;

  const _HelpItem({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
