import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as ja;

// ── State ─────────────────────────────────────────────────────────────────────

class AudioPlayerState {
  const AudioPlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage = '',
    this.isCompleted = false,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final bool isCompleted;

  AudioPlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    double? speed,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    bool? isCompleted,
  }) =>
      AudioPlayerState(
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        speed: speed ?? this.speed,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
        errorMessage: errorMessage ?? this.errorMessage,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AudioPlayerNotifier extends AutoDisposeNotifier<AudioPlayerState> {
  late final ja.AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<ja.PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  AudioPlayerState build() {
    _player = ja.AudioPlayer();

    _durationSub = _player.durationStream.listen((d) {
      if (d != null) state = state.copyWith(duration: d);
    });

    _positionSub = _player.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _stateSub = _player.playerStateStream.listen((ps) {
      final completed =
          ps.processingState == ja.ProcessingState.completed && !ps.playing;
      state = state.copyWith(
        isPlaying: ps.playing,
        isCompleted: completed,
      );
      // Auto-seek to 0 after playback completes so the bar resets cleanly.
      if (completed) _player.seek(Duration.zero);
    });

    ref.onDispose(() {
      _positionSub?.cancel();
      _stateSub?.cancel();
      _durationSub?.cancel();
      _player.dispose();
    });

    return const AudioPlayerState();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> load(String filePath) async {
    state = state.copyWith(isLoading: true, hasError: false, errorMessage: '');
    try {
      final duration = await _player.setFilePath(filePath);
      state = state.copyWith(
        isLoading: false,
        duration: duration ?? Duration.zero,
        position: Duration.zero,
        isCompleted: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    state = state.copyWith(speed: speed);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// AutoDispose: one player instance per page lifetime.
/// Keyed by meetingId so navigating between detail pages does not share state.
final audioPlayerProvider =
    AutoDisposeNotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
  AudioPlayerNotifier.new,
);
