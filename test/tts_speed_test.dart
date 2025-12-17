// TTS Speed Test for Windows SAPI
// Run with: dart run test/tts_speed_test.dart
//
// This test generates individual audio files for each unique announcement
// and measures the duration of each to ensure speech speed is fast enough.

import 'dart:io';
import 'dart:typed_data';

const int sampleRate = 22050;
const int channels = 1;
const int bitsPerSample = 16;

/// All unique announcement texts that will be used
final List<String> announcements = [
  // Stage titles (examples)
  'Stage One',
  'Stage Two',
  'Warm Up',
  'Main Exercise',
  'Cool Down',

  // Time announcements
  '5 minutes remaining',
  '4 minutes remaining',
  '3 minutes remaining',
  '2 minutes remaining',
  '1 minute remaining',
  '90 seconds',
  '60 seconds',
  '45 seconds',
  '30 seconds',
  '20 seconds',
  '15 seconds',

  // Countdown (fast speech)
  '10',
  '9',
  '8',
  '7',
  '6',
  '5',
  '4',
  '3',
  '2',
  '1',

  // End
  'Finished',
];

/// Check if text is a countdown number (needs fast speech)
bool isCountdownNumber(String text) {
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

/// Generate speech audio using Windows SAPI
Future<(String path, double duration)> generateSpeech(String text,
    {bool fast = false}) async {
  final outputDir = Directory('test_audio_output');
  if (!await outputDir.exists()) {
    await outputDir.create(recursive: true);
  }

  // Clean filename
  final cleanName = text
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .toLowerCase();

  final outputPath =
      '${outputDir.path}/${cleanName}_${fast ? "fast" : "normal"}.wav';

  // SAPI rate: 4 for normal, 10 for fast countdown
  final rate = fast ? 10 : 4;

  final escapedText = text.replaceAll("'", "''");

  final script = '''
Add-Type -AssemblyName System.Speech
\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
\$synth.Rate = $rate
\$synth.SetOutputToWaveFile("$outputPath")
\$synth.Speak("$escapedText")
\$synth.Dispose()
''';

  final result = await Process.run(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-Command', script],
  );

  if (result.exitCode != 0) {
    print('Error generating "$text": ${result.stderr}');
    return (outputPath, 0.0);
  }

  // Read WAV file and calculate duration
  final file = File(outputPath);
  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    if (bytes.length > 44) {
      // Parse WAV header for sample rate
      final byteData = ByteData.view(bytes.buffer);
      final fileSampleRate = byteData.getUint32(24, Endian.little);
      final dataSize = bytes.length - 44;
      final duration =
          dataSize / (fileSampleRate * channels * bitsPerSample / 8);
      return (outputPath, duration);
    }
  }

  return (outputPath, 0.0);
}

void main() async {
  print('TTS Speed Test - Windows SAPI');
  print('=' * 50);
  print('');

  if (!Platform.isWindows) {
    print('ERROR: This test only works on Windows.');
    exit(1);
  }

  final results = <String, double>{};
  var totalDuration = 0.0;

  for (final text in announcements) {
    final isFast = isCountdownNumber(text);
    final (path, duration) = await generateSpeech(text, fast: isFast);

    results[text] = duration;
    totalDuration += duration;

    final speedLabel = isFast ? '[FAST]' : '[NORMAL]';
    final durationStr = duration.toStringAsFixed(3);
    final status = duration < 1.0 ? '✓' : (duration < 2.0 ? '~' : '✗');

    print('$status $speedLabel "${text.padRight(25)}" -> ${durationStr}s');
  }

  print('');
  print('=' * 50);
  print('Total announcements: ${announcements.length}');
  print('Total audio duration: ${totalDuration.toStringAsFixed(2)}s');
  print(
      'Average duration: ${(totalDuration / announcements.length).toStringAsFixed(3)}s');
  print('');

  // Speed analysis
  final countdownTimes = results.entries
      .where((e) => isCountdownNumber(e.key))
      .map((e) => e.value)
      .toList();

  final normalTimes = results.entries
      .where((e) => !isCountdownNumber(e.key))
      .map((e) => e.value)
      .toList();

  if (countdownTimes.isNotEmpty) {
    final avgCountdown =
        countdownTimes.reduce((a, b) => a + b) / countdownTimes.length;
    print(
        'Countdown avg: ${avgCountdown.toStringAsFixed(3)}s (target: < 0.5s)');

    if (avgCountdown > 0.5) {
      print('⚠ WARNING: Countdown speech is too slow for 1-second intervals!');
    } else {
      print('✓ Countdown speed is good for 1-second intervals');
    }
  }

  if (normalTimes.isNotEmpty) {
    final avgNormal = normalTimes.reduce((a, b) => a + b) / normalTimes.length;
    print('Normal avg: ${avgNormal.toStringAsFixed(3)}s (target: < 2.0s)');
  }

  print('');
  print('Audio files saved to: test_audio_output/');
}
