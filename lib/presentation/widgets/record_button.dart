import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';

/// Large circular record/stop button with two animation modes:
///   • Idle  — slow scale bob 1.0↔1.04 every 2.2 s (architecture §9b).
///   • Active — pulsing red ring that expands and fades while the button
///              displays a stop icon and the gradient shifts to red.
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
    this.size = 88,
  });

  final bool isRecording;
  final VoidCallback onTap;
  final double size;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isRecording) _pulseCtrl.repeat();
  }

  @override
  void didUpdateWidget(RecordButton old) {
    super.didUpdateWidget(old);
    if (widget.isRecording && !old.isRecording) {
      _pulseCtrl.repeat();
    } else if (!widget.isRecording && old.isRecording) {
      _pulseCtrl.stop();
      _pulseCtrl.reset();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.of(context).disableAnimations;
    final size = widget.size;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: size + 48, // room for pulse rings
        height: size + 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Pulse rings (active only) ──────────────────────────────
            if (widget.isRecording && !disableMotion) ...[
              _PulseRing(controller: _pulseCtrl, delay: 0.0, size: size),
              _PulseRing(controller: _pulseCtrl, delay: 0.4, size: size),
            ],

            // ── Main button ───────────────────────────────────────────
            _ButtonFace(
              isRecording: widget.isRecording,
              size: size,
              disableMotion: disableMotion,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pulse ring ────────────────────────────────────────────────────────────────

class _PulseRing extends StatelessWidget {
  const _PulseRing({
    required this.controller,
    required this.delay,
    required this.size,
  });

  final AnimationController controller;
  final double delay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final delayed = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, 1.0, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: delayed,
      builder: (_, __) {
        final v = delayed.value;
        return Container(
          width: size + v * 40,
          height: size + v * 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.recording.withValues(alpha: (1 - v) * 0.5),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

// ── Button face ───────────────────────────────────────────────────────────────

class _ButtonFace extends StatelessWidget {
  const _ButtonFace({
    required this.isRecording,
    required this.size,
    required this.disableMotion,
  });

  final bool isRecording;
  final double size;
  final bool disableMotion;

  @override
  Widget build(BuildContext context) {
    final gradient = isRecording
        ? const LinearGradient(
            colors: [AppColors.recording, Color(0xFFFF6B6B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [AppColors.primarySeed, Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    Widget face = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: (isRecording ? AppColors.recording : AppColors.primarySeed)
                .withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isRecording ? Icons.stop_rounded : Icons.mic_rounded,
          key: ValueKey(isRecording),
          color: Colors.white,
          size: size * 0.42,
        ),
      ),
    );

    // Idle bob animation — only when not recording and motion is enabled.
    if (!isRecording && !disableMotion) {
      face = face
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.04, 1.04),
            duration: 2200.ms,
            curve: Curves.easeInOut,
          );
    }

    return face;
  }
}
