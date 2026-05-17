import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated waveform drawn from a rolling window of normalised amplitude values.
/// Feed it a stream of 0.0–1.0 amplitude values from [AudioRecorder.amplitudeStream].
class WaveformIndicator extends StatefulWidget {
  const WaveformIndicator({
    super.key,
    required this.amplitude,
    this.barCount = 24,
    this.color,
    this.height = 48,
  });

  /// Current normalised amplitude (0.0 – 1.0). Update this from the stream.
  final double amplitude;
  final int barCount;
  final Color? color;
  final double height;

  @override
  State<WaveformIndicator> createState() => _WaveformIndicatorState();
}

class _WaveformIndicatorState extends State<WaveformIndicator> {
  late final Queue<double> _history;

  @override
  void initState() {
    super.initState();
    _history = Queue.of(List.filled(widget.barCount, 0.0));
  }

  @override
  void didUpdateWidget(WaveformIndicator old) {
    super.didUpdateWidget(old);
    if (widget.amplitude != old.amplitude) {
      _history.removeFirst();
      _history.addLast(widget.amplitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _WaveformPainter(
          bars: _history.toList(),
          color: color,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({required this.bars, required this.color});

  final List<double> bars;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.fill;

    final barWidth = (size.width / bars.length) * 0.6;
    final gap      = (size.width / bars.length) * 0.4;
    final minHeight = 4.0;
    final maxHeight = size.height;

    for (int i = 0; i < bars.length; i++) {
      final amplitude = bars[i];
      final barHeight = math.max(minHeight, amplitude * maxHeight);
      final x = i * (barWidth + gap) + barWidth / 2;
      final top = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - barWidth / 2, top, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.bars != bars || old.color != color;
}
