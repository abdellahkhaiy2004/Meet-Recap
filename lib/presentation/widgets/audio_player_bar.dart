import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/audio_player.dart';

/// Sticky bottom bar shown on MeetingDetailPage ([IP-0028]).
///
/// Shows play/pause, a debounced seek slider, elapsed/total time, and a
/// 4-button speed selector (0.75× / 1× / 1.5× / 2×).
class AudioPlayerBar extends ConsumerStatefulWidget {
  const AudioPlayerBar({super.key});

  @override
  ConsumerState<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends ConsumerState<AudioPlayerBar> {
  // Debounce timer so rapid slider drags don't fire a seek per frame.
  Timer? _seekDebounce;
  // Local slider value while the user is dragging (avoids jitter).
  double? _draggingValue;

  @override
  void dispose() {
    _seekDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final totalSecs = state.duration.inSeconds.clamp(1, double.maxFinite).toDouble();
    final posSecs = state.position.inSeconds.toDouble().clamp(0, totalSecs);
    final sliderValue = _draggingValue ?? posSecs;

    return Material(
      elevation: 8,
      color: colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Seek slider ───────────────────────────────────────────────
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: sliderValue.clamp(0, totalSecs),
                  min: 0,
                  max: totalSecs,
                  onChanged: state.isLoading
                      ? null
                      : (v) {
                          setState(() => _draggingValue = v);
                          _seekDebounce?.cancel();
                          _seekDebounce = Timer(
                            const Duration(milliseconds: 30),
                            () {
                              notifier.seek(
                                Duration(milliseconds: (v * 1000).round()),
                              );
                              setState(() => _draggingValue = null);
                            },
                          );
                        },
                ),
              ),
              // ── Time labels ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Text(
                      _format(state.position),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const Spacer(),
                    Text(
                      _format(state.duration),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // ── Controls row ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Speed selector
                  _SpeedSelector(
                    current: state.speed,
                    onSelect: notifier.setSpeed,
                  ),
                  // Play / Pause
                  _PlayPauseButton(
                    isPlaying: state.isPlaying,
                    isLoading: state.isLoading,
                    hasError: state.hasError,
                    onPressed: () {
                      if (state.isPlaying) {
                        notifier.pause();
                      } else {
                        notifier.play();
                      }
                    },
                  ),
                  // Skip ±15 s buttons
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_15_rounded),
                        onPressed: state.isLoading
                            ? null
                            : () => notifier.seek(
                                  (state.position - const Duration(seconds: 15))
                                      .clamp(Duration.zero, state.duration),
                                ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_15_rounded),
                        onPressed: state.isLoading
                            ? null
                            : () => notifier.seek(
                                  (state.position + const Duration(seconds: 15))
                                      .clamp(Duration.zero, state.duration),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Play / Pause button ────────────────────────────────────────────────────────

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isLoading,
    required this.hasError,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (hasError) {
      return IconButton.filled(
        icon: const Icon(Icons.error_outline_rounded),
        onPressed: null,
        tooltip: 'Fichier audio indisponible',
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: IconButton.filled(
        key: ValueKey(isPlaying),
        icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
        iconSize: 32,
        onPressed: onPressed,
      ),
    );
  }
}

// ── Speed selector ─────────────────────────────────────────────────────────────

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.current, required this.onSelect});

  final double current;
  final void Function(double) onSelect;

  static const _speeds = [0.75, 1.0, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: _speeds.map((s) {
        final selected = (s - current).abs() < 0.01;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: GestureDetector(
            onTap: () => onSelect(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                border: selected
                    ? null
                    : Border.all(color: colorScheme.outlineVariant),
              ),
              child: Text(
                '${s == 1.0 ? '1' : s}×',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
