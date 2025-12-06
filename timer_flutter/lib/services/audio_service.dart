import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stts/stts.dart';
import '../models/models.dart';

/// Represents an announcement to be made at a specific time.
class Announcement {
  /// Time from the start of all stages when announcement should play (seconds)
  final double timeFromStart;

  /// The text to announce
  final String text;

  /// Whether this is a stage title announcement
  final bool isStageTitle;

  /// Whether this is a countdown number (needs fast speech)
  final bool isCountdown;

  const Announcement({
    required this.timeFromStart,
    required this.text,
    this.isStageTitle = false,
    this.isCountdown = false,
  });
}

/// Audio service that pre-generates a single audio file for the entire timer.
/// On Windows, this solves hardware speaker delay issues by syncing audio
/// with a fixed offset before the visual timer starts.
class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Tts _tts = Tts();
  bool _isInitialized = false;
  String? _generatedAudioPath;
  final List<Timer> _scheduledTimers = [];

  /// Callback when an announcement is spoken
  Function(String text)? onAnnouncementSpoken;

  /// Audio sample parameters
  static const int sampleRate = 22050;
  static const int channels = 1;
  static const int bitsPerSample = 16;

  /// Initialize TTS engine (for non-Windows platforms)
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!_isWindows) {
      await _tts.setLanguage('en-US');
      await _tts.setRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    }

    _isInitialized = true;
  }

  bool get _isWindows => !kIsWeb && Platform.isWindows;

  /// Generate all announcements for the given stages with absolute timing
  List<Announcement> generateTimedAnnouncements(List<Stage> stages) {
    final announcements = <Announcement>[];
    var stageStartOffset = 0.0;

    for (final stage in stages) {
      final stageDuration = stage.durationSeconds.toDouble();

      // Stage title at start of stage (always announce)
      announcements.add(Announcement(
        timeFromStart: stageStartOffset,
        text: stage.title,
        isStageTitle: true,
      ));

      // Regular announcements from sub-stages
      final stageAnnouncements = stage.generateAnnouncements();
      for (final (remaining, text) in stageAnnouncements) {
        // Calculate absolute time from total start
        final absoluteTime = stageStartOffset + stageDuration - remaining;

        // Check if this is a countdown number (1-10)
        final isCountdown = _isCountdownNumber(text);

        announcements.add(Announcement(
          timeFromStart: absoluteTime,
          text: text,
          isCountdown: isCountdown,
        ));
      }

      stageStartOffset += stageDuration;
    }

    // Add "Finished" at the very end
    announcements.add(Announcement(
      timeFromStart: stageStartOffset,
      text: 'Finished',
    ));

    // Sort by time
    announcements.sort((a, b) => a.timeFromStart.compareTo(b.timeFromStart));
    return announcements;
  }

  bool _isCountdownNumber(String text) {
    final trimmed = text.trim().toLowerCase();
    final countdownWords = [
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10'
    ];
    return countdownWords.contains(trimmed);
  }

  /// Generate silence bytes
  Uint8List _generateSilence(double durationSeconds) {
    final numSamples = (durationSeconds * sampleRate).round();
    // 16-bit silence = 0
    final bytes = Uint8List(numSamples * 2);
    return bytes;
  }

  /// Generate WAV file header
  Uint8List _createWavHeader(int dataSize) {
    final header = ByteData(44);
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;

    // RIFF header
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little); // File size - 8
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little); // Chunk size
    header.setUint16(20, 1, Endian.little); // Audio format (PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    return header.buffer.asUint8List();
  }

  /// Generate speech audio using Windows SAPI via PowerShell
  Future<Uint8List> _generateSpeechWindows(String text,
      {bool fast = false}) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath =
        '${tempDir.path}/tts_temp_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Escape text for PowerShell
    final escapedText = text.replaceAll("'", "''");

    // Use faster rate for countdown numbers (rate 5-10 is fast, 0 is slow)
    // For ~0.5s per number, we need rate around 7-8
    final rate = fast ? 7 : 2;

    // PowerShell script to generate WAV using SAPI
    final script = '''
Add-Type -AssemblyName System.Speech
\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$synth.Rate = $rate
\$synth.SetOutputToWaveFile('$tempPath')
\$synth.Speak('$escapedText')
\$synth.Dispose()
''';

    try {
      final result = await Process.run(
        'powershell',
        ['-Command', script],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        debugPrint('PowerShell TTS error: ${result.stderr}');
        return _generateSilence(0.5);
      }

      // Read the generated WAV file
      final file = File(tempPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await file.delete();

        // Extract audio data (skip 44-byte header if present)
        if (bytes.length > 44) {
          // Resample to our target sample rate if needed
          return _extractAndResampleWav(bytes);
        }
      }
    } catch (e) {
      debugPrint('Error generating speech: $e');
    }

    return _generateSilence(0.5);
  }

  /// Extract audio data from WAV and resample to target sample rate
  Uint8List _extractAndResampleWav(Uint8List wavBytes) {
    if (wavBytes.length < 44) return _generateSilence(0.1);

    // Parse WAV header to get source sample rate
    final byteData = ByteData.view(wavBytes.buffer);
    final sourceSampleRate = byteData.getUint32(24, Endian.little);
    final dataStart = 44; // Standard WAV header size

    // Get audio data
    final audioData = wavBytes.sublist(dataStart);

    if (sourceSampleRate == sampleRate) {
      return audioData;
    }

    // Resample
    return _resample(audioData, sourceSampleRate, sampleRate);
  }

  /// Resample audio data using linear interpolation
  Uint8List _resample(Uint8List audioBytes, int fromRate, int toRate) {
    final numSamples = audioBytes.length ~/ 2;
    final samples = Int16List.view(audioBytes.buffer);

    final ratio = toRate / fromRate;
    final newLength = (numSamples * ratio).round();
    final resampled = Int16List(newLength);

    for (int i = 0; i < newLength; i++) {
      final srcIdx = i / ratio;
      final idxLow = srcIdx.floor();
      final idxHigh = (idxLow + 1).clamp(0, numSamples - 1);
      final frac = srcIdx - idxLow;

      if (idxLow < numSamples) {
        final sample =
            (samples[idxLow] * (1 - frac) + samples[idxHigh] * frac).round();
        resampled[i] = sample.clamp(-32768, 32767);
      }
    }

    return Uint8List.view(resampled.buffer);
  }

  /// Generate complete audio file for all stages (Windows only)
  Future<String> generateFullAudio(
    List<Stage> stages,
    int ttsRateNormal,
    int ttsRateCountdown,
  ) async {
    final announcements = generateTimedAnnouncements(stages);
    final totalDuration = stages.fold(0, (sum, s) => sum + s.durationSeconds);

    final audioChunks = <Uint8List>[];
    var currentPosition = 0.0;

    for (final announcement in announcements) {
      // Add silence up to this announcement
      final silenceDuration = announcement.timeFromStart - currentPosition;
      if (silenceDuration > 0.01) {
        audioChunks.add(_generateSilence(silenceDuration));
        currentPosition = announcement.timeFromStart;
      }

      // Generate speech
      final speechAudio = await _generateSpeechWindows(
        announcement.text,
        fast: announcement.isCountdown,
      );
      audioChunks.add(speechAudio);

      // Estimate speech duration based on audio length
      final speechDuration = speechAudio.length / (sampleRate * 2);
      currentPosition += speechDuration;

      // Notify about announcement
      onAnnouncementSpoken?.call(announcement.text);
    }

    // Add trailing silence
    final remainingSilence = totalDuration - currentPosition + 1.0;
    if (remainingSilence > 0) {
      audioChunks.add(_generateSilence(remainingSilence));
    }

    // Combine all audio chunks
    final totalBytes = audioChunks.fold(0, (sum, chunk) => sum + chunk.length);
    final combinedAudio = Uint8List(totalBytes);
    var offset = 0;
    for (final chunk in audioChunks) {
      combinedAudio.setAll(offset, chunk);
      offset += chunk.length;
    }

    // Create WAV file
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/timer_audio_${DateTime.now().millisecondsSinceEpoch}.wav';

    final header = _createWavHeader(combinedAudio.length);
    final wavFile = File(outputPath);
    await wavFile.writeAsBytes([...header, ...combinedAudio]);

    _generatedAudioPath = outputPath;
    return outputPath;
  }

  /// Start audio playback (returns when audio starts)
  Future<void> startAudioPlayback(String audioPath) async {
    await _audioPlayer.setFilePath(audioPath);
    await _audioPlayer.play();
  }

  /// Speak text immediately using real-time TTS (non-Windows)
  Future<void> speak(String text) async {
    await initialize();
    if (_isWindows) {
      // On Windows, use PowerShell for immediate TTS
      final script = '''
Add-Type -AssemblyName System.Speech
\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$synth.Rate = 2
\$synth.Speak('${text.replaceAll("'", "''")}')
\$synth.Dispose()
''';
      await Process.run('powershell', ['-Command', script], runInShell: true);
    } else {
      await _tts.start(text);
    }
    onAnnouncementSpoken?.call(text);
  }

  /// Start announcement playback synchronized with timer
  /// On Windows: Pre-generates audio file, plays it, then calls onTimerStart after offset
  /// On other platforms: Schedules TTS announcements with timers
  Future<void> startAnnouncementPlayback(
    List<Stage> stages,
    Duration audioOffset,
    VoidCallback onTimerStart,
  ) async {
    await initialize();

    if (_isWindows) {
      // Windows: Generate audio file first
      final audioPath = await generateFullAudio(stages, 180, 250);

      // Start audio playback
      await startAudioPlayback(audioPath);

      // After offset, start the visual timer
      await Future.delayed(audioOffset);
      onTimerStart();
    } else {
      // Other platforms: Use real-time TTS with scheduled timers
      onTimerStart();

      final announcements = generateTimedAnnouncements(stages);

      for (final announcement in announcements) {
        final delay = Duration(
              milliseconds: (announcement.timeFromStart * 1000).round(),
            ) +
            audioOffset;

        if (delay.isNegative) {
          speak(announcement.text);
        } else {
          final timer = Timer(delay, () => speak(announcement.text));
          _scheduledTimers.add(timer);
        }
      }
    }
  }

  /// Stop all audio and scheduled announcements
  Future<void> stop() async {
    await _audioPlayer.stop();
    for (final timer in _scheduledTimers) {
      timer.cancel();
    }
    _scheduledTimers.clear();
    await _tts.stop();
  }

  /// Dispose resources
  void dispose() {
    stop();
    _audioPlayer.dispose();
    _tts.dispose();

    // Clean up generated audio file
    if (_generatedAudioPath != null) {
      try {
        final file = File(_generatedAudioPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }
}
