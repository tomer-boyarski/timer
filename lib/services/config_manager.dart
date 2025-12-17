import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

/// Configuration for the timer application.
class TimerConfig {
  /// List of stages in order
  final List<Stage> stages;

  /// Audio offset in seconds (delay between audio start and timer start)
  /// Windows: 1.0, other platforms: 0.0
  final double audioOffset;

  /// TTS rate for normal announcements
  final int ttsRateNormal;

  /// TTS rate for countdown (faster)
  final int ttsRateCountdown;

  const TimerConfig({
    required this.stages,
    required this.audioOffset,
    required this.ttsRateNormal,
    required this.ttsRateCountdown,
  });

  /// Create from JSON map
  factory TimerConfig.fromJson(Map<String, dynamic> json) {
    return TimerConfig(
      stages: (json['stages'] as List<dynamic>)
          .map((e) => Stage.fromJson(e as Map<String, dynamic>))
          .toList(),
      audioOffset: (json['audio_offset'] as num).toDouble(),
      ttsRateNormal: json['tts_rate_normal'] as int,
      ttsRateCountdown: json['tts_rate_countdown'] as int,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'stages': stages.map((s) => s.toJson()).toList(),
      'audio_offset': audioOffset,
      'tts_rate_normal': ttsRateNormal,
      'tts_rate_countdown': ttsRateCountdown,
    };
  }

  /// Create a copy with modified fields
  TimerConfig copyWith({
    List<Stage>? stages,
    double? audioOffset,
    int? ttsRateNormal,
    int? ttsRateCountdown,
  }) {
    return TimerConfig(
      stages: stages ?? this.stages,
      audioOffset: audioOffset ?? this.audioOffset,
      ttsRateNormal: ttsRateNormal ?? this.ttsRateNormal,
      ttsRateCountdown: ttsRateCountdown ?? this.ttsRateCountdown,
    );
  }

  /// Get platform-specific audio offset
  static double getPlatformAudioOffset() {
    if (kIsWeb) {
      return 0.0;
    }
    if (Platform.isWindows) {
      return 1.0;
    }
    return 0.0;
  }

  /// Default configuration
  static TimerConfig defaultConfig() {
    return TimerConfig(
      stages: Stage.defaultStages(),
      audioOffset: getPlatformAudioOffset(),
      ttsRateNormal: 180,
      ttsRateCountdown: 250,
    );
  }

  /// Calculate total duration of all stages
  int get totalDurationSeconds {
    return stages.fold(0, (sum, stage) => sum + stage.durationSeconds);
  }
}

/// Manages saving and loading of timer configuration.
class ConfigManager {
  static const String _configFileName = 'timer_config.json';

  /// Get the config file path
  Future<File> _getConfigFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_configFileName');
  }

  /// Load configuration from file
  Future<TimerConfig> loadConfig() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final json = jsonDecode(contents) as Map<String, dynamic>;
        return TimerConfig.fromJson(json);
      }
    } catch (e) {
      debugPrint('Error loading config: $e');
    }
    // Return default config if file doesn't exist or error occurs
    return TimerConfig.defaultConfig();
  }

  /// Save configuration to file
  Future<void> saveConfig(TimerConfig config) async {
    try {
      final file = await _getConfigFile();
      final json = jsonEncode(config.toJson());
      await file.writeAsString(json);
    } catch (e) {
      debugPrint('Error saving config: $e');
    }
  }

  /// Reset to default configuration
  Future<TimerConfig> resetToDefault() async {
    final config = TimerConfig.defaultConfig();
    await saveConfig(config);
    return config;
  }
}
