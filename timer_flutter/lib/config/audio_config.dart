/// Audio configuration settings for TTS generation
///
/// Windows SAPI rate scale: -10 (slowest) to +10 (fastest), 0 is normal
///
/// To adjust TTS speed manually:
/// - Increase sapiRate for faster speech
/// - Decrease sapiRate for slower speech
/// - Current setting (rate 2) produces ~0.9s duration for countdown numbers
/// - Rate 4 produces ~0.5s (too fast)
/// - Rate 0 produces ~1.2s (too slow)
///
/// Target: All announcements should be fast enough that countdown numbers
/// (10, 9, 8, etc.) take less than 1 second each, ideally around 0.9s.
class AudioConfig {
  /// Windows SAPI speech rate for all announcements
  /// Range: -10 to +10, where 0 is normal speed
  /// Current: 2 (slightly faster than normal, ~0.9s for countdown numbers)
  static const int sapiRate = 4;

  /// Audio sample rate for generated WAV files
  static const int sampleRate = 22050;

  /// Number of audio channels (1 = mono, 2 = stereo)
  static const int channels = 1;

  /// Bits per sample for audio quality
  static const int bitsPerSample = 16;
}
