import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../config/audio_config.dart';

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

/// Audio service that handles TTS announcements.
///
/// Platform-specific behavior:
/// - Windows: Pre-generates a single WAV file with all announcements timed correctly.
///   This is because the Windows PC uses external speakers with hardware delay.
///   Reusable announcements (countdown numbers) are cached in memory AND persisted to disk.
///   Disk cache significantly improves startup time on subsequent runs.
/// - Android/iOS/Web: Uses real-time TTS with scheduled timers. No pre-generation needed.
class AudioService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  String? _generatedAudioPath;
  final List<Timer> _scheduledTimers = [];

  /// Memory cache for pre-generated audio segments (Windows only)
  /// Key is the announcement text, value is (audioBytes, duration)
  final Map<String, (Uint8List, double)> _audioCache = {};

  /// Directory for persistent audio cache
  Directory? _audioCacheDir;

  /// Callback when an announcement is spoken
  Function(String text)? onAnnouncementSpoken;

  /// Audio sample parameters for Windows WAV generation
  static const int sampleRate = AudioConfig.sampleRate;
  static const int channels = AudioConfig.channels;
  static const int bitsPerSample = AudioConfig.bitsPerSample;

  /// Platform checks
  bool get _isWindows => !kIsWeb && Platform.isWindows;
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isWeb => kIsWeb;

  /// Initialize TTS engine (for non-Windows platforms)
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!_isWindows) {
      try {
        // For Web and mobile platforms, use flutter_tts package
        await _tts.setLanguage('en-US');
        // Fast speech rate (0.0 to 1.0 for flutter_tts, where 0.5 is normal)
        await _tts
            .setSpeechRate(_isWeb ? 0.6 : 0.55); // Slightly faster than normal
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);
        debugPrint('TTS initialized for ${_isWeb ? "Web" : "Mobile"}');
      } catch (e) {
        debugPrint('TTS initialization error: $e');
      }
    }

    _isInitialized = true;
  }

  /// Generate all announcements for the given stages with absolute timing
  /// Skips countdown for stages less than 10 seconds
  /// Filters out announcements that would overlap with stage title duration
  List<Announcement> generateTimedAnnouncements(List<Stage> stages) {
    final announcements = <Announcement>[];
    var stageStartOffset = 0.0;

    for (final stage in stages) {
      final stageDuration = stage.durationSeconds.toDouble();

      // Stage title at start of stage (always announce)
      final stageTitleAnnouncement = Announcement(
        timeFromStart: stageStartOffset,
        text: stage.title,
        isStageTitle: true,
      );
      announcements.add(stageTitleAnnouncement);

      // Only add regular announcements if stage is >= 10 seconds
      if (stage.durationSeconds >= 10) {
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

  /// Get unique announcement texts that need to be generated
  /// Stage titles are unique per stage; everything else can be reused
  Set<String> _getUniqueAnnouncementTexts(List<Announcement> announcements) {
    return announcements.map((a) => a.text).toSet();
  }

  /// Initialize audio cache directory (Windows only)
  Future<void> _initAudioCacheDir() async {
    if (_audioCacheDir != null) return;

    final appDir = await getApplicationDocumentsDirectory();
    _audioCacheDir = Directory('${appDir.path}/timer_audio_cache');

    if (!await _audioCacheDir!.exists()) {
      await _audioCacheDir!.create(recursive: true);
      debugPrint('Created audio cache directory: ${_audioCacheDir!.path}');
    }
  }

  /// Generate a cache filename from announcement text
  /// Uses MD5 hash to create valid filename from any text
  String _getCacheFilename(String text) {
    final hash = md5.convert(utf8.encode(text)).toString();
    return '$hash.wav';
  }

  /// Load audio from disk cache if available
  Future<(Uint8List, double)?> _loadFromDiskCache(String text) async {
    if (_audioCacheDir == null) return null;

    final filename = _getCacheFilename(text);
    final file = File('${_audioCacheDir!.path}/$filename');

    if (await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.length > 44) {
          final audioData = _extractAndResampleWav(bytes);
          final duration = audioData.length / (sampleRate * 2);
          debugPrint(
              'Loaded from disk cache: "$text" (${duration.toStringAsFixed(2)}s)');
          return (audioData, duration);
        }
      } catch (e) {
        debugPrint('Error loading from disk cache: $e');
      }
    }

    return null;
  }

  /// Save audio to disk cache
  Future<void> _saveToDiskCache(String text, Uint8List audioData) async {
    if (_audioCacheDir == null) return;

    final filename = _getCacheFilename(text);
    final file = File('${_audioCacheDir!.path}/$filename');

    try {
      // Create WAV file with header
      final header = _createWavHeader(audioData.length);
      await file.writeAsBytes([...header, ...audioData]);
      debugPrint('Saved to disk cache: "$text"');
    } catch (e) {
      debugPrint('Error saving to disk cache: $e');
    }
  }

  /// Pre-generate all unique audio segments (Windows only)
  /// Loads from disk cache if available, generates and saves if not
  Future<void> _preGenerateAudioSegments(
      List<Announcement> announcements) async {
    final uniqueTexts = _getUniqueAnnouncementTexts(announcements);

    debugPrint('Pre-generating ${uniqueTexts.length} unique audio segments...');

    // Initialize disk cache
    await _initAudioCacheDir();

    int diskHits = 0;
    int generated = 0;

    for (final text in uniqueTexts) {
      if (!_audioCache.containsKey(text)) {
        // Try loading from disk cache first
        var result = await _loadFromDiskCache(text);

        if (result != null) {
          // Cache hit - use existing file
          _audioCache[text] = result;
          diskHits++;
        } else {
          // Cache miss - generate and save
          final (audio, duration) = await _generateSpeechWindows(text);
          _audioCache[text] = (audio, duration);
          await _saveToDiskCache(text, audio);
          generated++;
          debugPrint('Generated: "$text" (${duration.toStringAsFixed(2)}s)');
        }
      }
    }

    debugPrint(
        'Audio cache ready: ${_audioCache.length} segments ($diskHits from disk, $generated generated)');
  }

  /// Filter out announcements that would overlap with previous announcements
  /// This prevents rapid-fire announcements when stage titles are long
  List<Announcement> _filterOverlappingAnnouncements(
      List<Announcement> announcements) {
    final filtered = <Announcement>[];
    double nextAvailableTime = 0.0;

    for (final announcement in announcements) {
      // Get the duration of this announcement from cache
      final cached = _audioCache[announcement.text];
      if (cached == null) {
        // If not cached, skip it (shouldn't happen)
        continue;
      }

      final (_, duration) = cached;

      // Check if this announcement would start before the previous one ends
      if (announcement.timeFromStart >= nextAvailableTime) {
        // No overlap - include this announcement
        filtered.add(announcement);
        nextAvailableTime = announcement.timeFromStart + duration;

        // Add a small buffer (0.05s) between announcements
        nextAvailableTime += 0.05;
      } else {
        // Overlap detected - skip this announcement
        debugPrint(
            'Skipping overlapping announcement: "${announcement.text}" at ${announcement.timeFromStart.toStringAsFixed(2)}s (previous ends at ${nextAvailableTime.toStringAsFixed(2)}s)');
      }
    }

    return filtered;
  }

  /// Generate silence bytes
  Uint8List _generateSilence(double durationSeconds) {
    final numSamples = (durationSeconds * sampleRate).round();
    // 16-bit silence = 0
    return Uint8List(numSamples * 2);
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
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
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
  /// Uses uniform speech rate from AudioConfig for all announcements
  Future<(Uint8List, double)> _generateSpeechWindows(String text) async {
    final tempDir = await getTemporaryDirectory();
    // Use forward slashes for path (works on Windows too)
    final tempPath =
        '${tempDir.path}/tts_temp_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Escape text for PowerShell
    final escapedText =
        text.replaceAll("'", "''").replaceAll('\n', ' ').replaceAll('\r', ' ');

    // Use uniform rate from AudioConfig for all announcements
    // This ensures countdown numbers take ~0.9s each while keeping speech natural
    final rate = AudioConfig.sapiRate;

    final script = '''
Add-Type -AssemblyName System.Speech
\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$synth.Rate = $rate
\$synth.SetOutputToWaveFile("$tempPath")
\$synth.Speak("$escapedText")
\$synth.Dispose()
''';

    try {
      debugPrint('Generating TTS for: "$text" (rate=$rate)');

      final result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', script],
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('TTS generation timed out for: "$text"');
        return ProcessResult(0, 1, '', 'Timeout');
      });

      if (result.exitCode != 0) {
        debugPrint('PowerShell TTS error: ${result.stderr}');
        return (_generateSilence(0.3), 0.3);
      }

      // Read the generated WAV file
      final file = File(tempPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();

        // Clean up temp file
        try {
          await file.delete();
        } catch (_) {}

        // Extract audio data and calculate duration
        if (bytes.length > 44) {
          final audioData = _extractAndResampleWav(bytes);
          final duration = audioData.length / (sampleRate * 2);
          debugPrint(
              'Generated ${duration.toStringAsFixed(2)}s audio for "$text"');
          return (audioData, duration);
        }
      }
    } catch (e) {
      debugPrint('Error generating speech: $e');
    }

    return (_generateSilence(0.3), 0.3);
  }

  /// Extract audio data from WAV and resample to target sample rate
  Uint8List _extractAndResampleWav(Uint8List wavBytes) {
    if (wavBytes.length < 44) return _generateSilence(0.1);

    final byteData = ByteData.view(wavBytes.buffer);
    final sourceSampleRate = byteData.getUint32(24, Endian.little);
    final dataStart = 44;

    final audioData = wavBytes.sublist(dataStart);

    if (sourceSampleRate == sampleRate) {
      return audioData;
    }

    return _resample(audioData, sourceSampleRate, sampleRate);
  }

  /// Resample audio data using linear interpolation
  Uint8List _resample(Uint8List audioBytes, int fromRate, int toRate) {
    final numSamples = audioBytes.length ~/ 2;
    if (numSamples == 0) return Uint8List(0);

    final samples = Int16List.view(audioBytes.buffer);
    final ratio = toRate / fromRate;
    final newLength = (numSamples * ratio).round();
    if (newLength == 0) return Uint8List(0);

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
  /// Uses cached audio segments for efficiency
  Future<String> generateFullAudio(List<Stage> stages) async {
    debugPrint('Starting audio generation for ${stages.length} stages');

    final announcements = generateTimedAnnouncements(stages);
    final totalDuration = stages.fold(0, (sum, s) => sum + s.durationSeconds);

    debugPrint('Total announcements: ${announcements.length}');
    debugPrint('Total duration: ${totalDuration}s');

    // Pre-generate all unique audio segments (uses cache)
    await _preGenerateAudioSegments(announcements);

    // Filter out announcements that overlap with previous ones
    final filteredAnnouncements =
        _filterOverlappingAnnouncements(announcements);
    debugPrint(
        'Filtered announcements: ${filteredAnnouncements.length} (removed ${announcements.length - filteredAnnouncements.length} overlapping)');

    final audioChunks = <Uint8List>[];
    var currentPosition = 0.0;

    for (int i = 0; i < filteredAnnouncements.length; i++) {
      final announcement = filteredAnnouncements[i];

      // Add silence up to this announcement
      final silenceDuration = announcement.timeFromStart - currentPosition;
      if (silenceDuration > 0.01) {
        audioChunks.add(_generateSilence(silenceDuration));
        currentPosition = announcement.timeFromStart;
      }

      // Get cached audio
      final cached = _audioCache[announcement.text];
      if (cached != null) {
        final (speechAudio, speechDuration) = cached;
        audioChunks.add(speechAudio);
        currentPosition += speechDuration;
      }

      onAnnouncementSpoken?.call(announcement.text);
    }

    // Add trailing silence
    final remainingSilence = totalDuration - currentPosition + 1.0;
    if (remainingSilence > 0) {
      audioChunks.add(_generateSilence(remainingSilence));
    }

    // Combine all audio chunks
    final totalBytes = audioChunks.fold(0, (sum, chunk) => sum + chunk.length);
    debugPrint('Total audio bytes: $totalBytes');

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

    debugPrint('Audio file saved to: $outputPath');
    _generatedAudioPath = outputPath;
    return outputPath;
  }

  /// Speak text immediately using real-time TTS
  Future<void> speak(String text) async {
    await initialize();

    debugPrint(
        'Speaking: "$text" (platform: ${_isWindows ? "Windows" : (_isWeb ? "Web" : "Mobile")})');

    if (_isWindows) {
      // On Windows, use PowerShell for immediate TTS
      final script = '''
Add-Type -AssemblyName System.Speech
\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$synth.Rate = 4
\$synth.Speak("${text.replaceAll('"', '`"')}")
\$synth.Dispose()
''';
      await Process.run('powershell.exe',
          ['-NoProfile', '-NonInteractive', '-Command', script]);
    } else {
      // Android/iOS/Web: use flutter_tts package
      try {
        debugPrint('Using flutter_tts.speak() for: "$text"');
        await _tts.speak(text);
        debugPrint('flutter_tts.speak() completed for: "$text"');
      } catch (e) {
        debugPrint('TTS speak error: $e');
      }
    }

    onAnnouncementSpoken?.call(text);
  }

  /// Start announcement playback synchronized with timer
  /// On Windows: Pre-generates audio file, returns path for external player
  /// On other platforms: Schedules TTS announcements with timers
  Future<String?> startAnnouncementPlayback(
    List<Stage> stages,
    Duration audioOffset,
    VoidCallback onTimerStart,
  ) async {
    await initialize();

    if (_isWindows) {
      try {
        // Windows: Generate audio file first
        debugPrint('Windows mode: generating audio file...');
        final audioPath = await generateFullAudio(stages);
        debugPrint('Audio generated: $audioPath');

        // Return the path - timer screen will handle playback
        return audioPath;
      } catch (e) {
        debugPrint('Error in Windows audio generation: $e');
        return null;
      }
    } else {
      // Android/iOS/Web: Use real-time TTS with scheduled timers
      // Start timer immediately
      onTimerStart();

      final announcements = generateTimedAnnouncements(stages);

      for (final announcement in announcements) {
        final delay = Duration(
          milliseconds: (announcement.timeFromStart * 1000).round(),
        );

        if (delay.inMilliseconds <= 0) {
          speak(announcement.text);
        } else {
          final timer = Timer(delay, () => speak(announcement.text));
          _scheduledTimers.add(timer);
        }
      }

      return null; // No audio file for non-Windows
    }
  }

  /// Stop all audio and scheduled announcements
  Future<void> stop() async {
    for (final timer in _scheduledTimers) {
      timer.cancel();
    }
    _scheduledTimers.clear();

    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Dispose resources
  void dispose() {
    stop();
    _audioCache.clear();

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
