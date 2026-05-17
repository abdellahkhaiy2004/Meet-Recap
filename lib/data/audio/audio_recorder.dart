import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as pkg;

/// Wraps the `record` package (v5.x) for the app's specific needs:
/// AAC-LC, mono, 16 kHz, stored at `<appDocs>/audio/<id>.m4a`.
class AudioRecorder {
  AudioRecorder() : _recorder = pkg.AudioRecorder();

  final pkg.AudioRecorder _recorder;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Amplitude updates every 60 ms while recording.
  /// Values are raw `pkg.Amplitude`; callers normalise via [normalise].
  Stream<pkg.Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 60));

  /// Starts recording to `<appDocs>/audio/<id>.m4a`.
  /// Returns the full file path so callers can track the draft.
  Future<String> start(String id) async {
    final path = await _buildPath(id);
    await _recorder.start(
      const pkg.RecordConfig(
        encoder: pkg.AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    return path;
  }

  /// Stops recording and returns the saved file, or null if nothing was recorded.
  Future<File?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  Future<void> pause() => _recorder.pause();
  Future<void> resume() => _recorder.resume();

  Future<bool> get isRecording => _recorder.isRecording();
  Future<bool> get isPaused => _recorder.isPaused();

  Future<void> dispose() => _recorder.dispose();

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Converts a dBFS amplitude value to a 0.0–1.0 range suitable for UI.
  static double normalise(double dbfs) {
    // dbfs is typically in [-160, 0]. Map [-60, 0] linearly to [0, 1].
    const floor = -60.0;
    if (dbfs <= floor) return 0.0;
    if (dbfs >= 0) return 1.0;
    return (dbfs - floor) / (-floor);
  }

  static Future<String> _buildPath(String id) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/audio');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return '${dir.path}/$id.m4a';
  }
}
