import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart' show Amplitude;

import '../../data/audio/audio_recorder.dart';
import '../../data/audio/recording_state.dart';
import '../../domain/usecases/start_recording.dart';
import '../../domain/usecases/stop_and_process.dart';

// ── State ────────────────────────────────────────────────────────────────────

class MeetingState {
  const MeetingState({
    this.recordingState = const Idle(),
    this.draftId,
    this.audioPath,
    this.folderId,
    this.result,
  });

  final RecordingState recordingState;
  final String? draftId;
  final String? audioPath;
  final String? folderId;
  final RecordingResult? result; // set after a successful stop

  MeetingState copyWith({
    RecordingState? recordingState,
    String? draftId,
    String? audioPath,
    String? folderId,
    RecordingResult? result,
  }) =>
      MeetingState(
        recordingState: recordingState ?? this.recordingState,
        draftId: draftId ?? this.draftId,
        audioPath: audioPath ?? this.audioPath,
        folderId: folderId ?? this.folderId,
        result: result ?? this.result,
      );
}

// ── Controller ───────────────────────────────────────────────────────────────

class MeetingController extends Notifier<MeetingState> {
  static const _startUC = StartRecording();
  static const _stopUC  = StopAndProcess();

  late final AudioRecorder _recorder;
  Timer? _ticker;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Duration _elapsed = Duration.zero;

  @override
  MeetingState build() {
    _recorder = AudioRecorder();
    // Keep alive while recording or processing so the notifier
    // is not disposed mid-session (architecture §9c risk note [IP-0017]).
    ref.keepAlive();
    ref.onDispose(() {
      _ticker?.cancel();
      _amplitudeSub?.cancel();
      _recorder.dispose();
    });
    return const MeetingState();
  }

  // ── Public API ─────────────────────────────────────────────────────────

  Future<void> startRecording({String? folderId}) async {
    final draftId = _startUC();
    _elapsed = Duration.zero;

    final path = await _recorder.start(draftId);
    state = state.copyWith(
      recordingState: const Recording(elapsed: Duration.zero, amplitude: 0),
      draftId: draftId,
      audioPath: path,
      folderId: folderId,
    );

    // Elapsed timer — ticks every second.
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      final current = state.recordingState;
      if (current is Recording) {
        state = state.copyWith(
          recordingState: Recording(
            elapsed: _elapsed,
            amplitude: current.amplitude,
          ),
        );
      }
    });

    // Amplitude stream — 60 ms cadence.
    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder.amplitudeStream.listen((amp) {
      final current = state.recordingState;
      if (current is Recording) {
        state = state.copyWith(
          recordingState: Recording(
            elapsed: current.elapsed,
            amplitude: AudioRecorder.normalise(amp.current),
          ),
        );
      }
    });
  }

  Future<void> pauseRecording() async {
    await _recorder.pause();
    _ticker?.cancel();
    state = state.copyWith(
      recordingState: Paused(elapsed: _elapsed),
    );
  }

  Future<void> resumeRecording() async {
    await _recorder.resume();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      final current = state.recordingState;
      if (current is Recording) {
        state = state.copyWith(
          recordingState: Recording(
            elapsed: _elapsed,
            amplitude: current.amplitude,
          ),
        );
      }
    });
    state = state.copyWith(
      recordingState: Recording(elapsed: _elapsed, amplitude: 0),
    );
  }

  /// Stops recording and packages the result. Returns the [RecordingResult]
  /// so the UI can navigate to /processing/:draftId, or null on failure.
  Future<RecordingResult?> stopAndProcess() async {
    _ticker?.cancel();
    _amplitudeSub?.cancel();

    final File? file = await _recorder.stop();
    final result = _stopUC(
      draftId: state.draftId ?? '',
      audioFile: file,
      elapsed: _elapsed,
      folderId: state.folderId,
    );

    if (result == null) {
      state = state.copyWith(
        recordingState: const RecordingError('Enregistrement trop court ou manquant.'),
      );
      return null;
    }

    state = state.copyWith(
      recordingState: const Idle(),
      result: result,
    );
    return result;
  }

  void clearError() {
    if (state.recordingState is RecordingError) {
      state = state.copyWith(recordingState: const Idle());
    }
  }
}

final meetingControllerProvider =
    NotifierProvider<MeetingController, MeetingState>(MeetingController.new);
