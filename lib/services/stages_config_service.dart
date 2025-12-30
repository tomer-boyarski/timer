import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/sub_stage.dart';
import '../models/stage.dart';
import 'excel_service.dart';

/// Simple stages configuration - stores the complete stage list
class StagesConfig {
  final int version;
  final List<Stage> stages;
  final DateTime? lastUpdated;
  final bool hasBeenCustomized; // True after user saves for the first time

  const StagesConfig({
    required this.version,
    required this.stages,
    this.lastUpdated,
    this.hasBeenCustomized = false,
  });

  factory StagesConfig.fromJson(Map<String, dynamic> json) {
    return StagesConfig(
      version: json['version'] as int? ?? 1,
      stages: (json['stages'] as List<dynamic>?)
              ?.map((e) => Stage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
      hasBeenCustomized: json['has_been_customized'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'stages': stages.map((s) => s.toJson()).toList(),
      'last_updated': lastUpdated?.toIso8601String(),
      'has_been_customized': hasBeenCustomized,
    };
  }

  StagesConfig copyWith({
    int? version,
    List<Stage>? stages,
    DateTime? lastUpdated,
    bool? hasBeenCustomized,
  }) {
    return StagesConfig(
      version: version ?? this.version,
      stages: stages ?? this.stages,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      hasBeenCustomized: hasBeenCustomized ?? this.hasBeenCustomized,
    );
  }

  /// Check if config has valid stages
  bool get hasStages => stages.isNotEmpty;
}

/// Service for managing the complete stages configuration
class StagesConfigService {
  /// Fixed path to the stages config file in the project directory
  static const String _configPath = r'C:\projects\timer\stages_config.json';

  /// Get the config file path
  String get configPath => _configPath;

  /// Load the stages configuration from file
  /// Returns null if file doesn't exist or is invalid
  Future<StagesConfig?> loadConfig() async {
    try {
      final file = File(_configPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final config = StagesConfig.fromJson(json);

        if (config.hasStages) {
          debugPrint(
              'Loaded ${config.stages.length} stages from: $_configPath');
          debugPrint(
              'Last updated: ${config.lastUpdated != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(config.lastUpdated!) : 'never'}');
          return config;
        }
      }
    } catch (e) {
      debugPrint('Error loading stages config: $e');
    }

    debugPrint('No valid stages config found at: $_configPath');
    return null;
  }

  /// Save the complete stages list to the config file
  Future<bool> saveStages(List<Stage> stages) async {
    try {
      final file = File(_configPath);

      final config = StagesConfig(
        version: 1,
        stages: stages,
        lastUpdated: DateTime.now(),
        hasBeenCustomized: true,
      );

      final jsonStr =
          const JsonEncoder.withIndent('  ').convert(config.toJson());
      await file.writeAsString(jsonStr);

      debugPrint('Saved ${stages.length} stages to: $_configPath');
      debugPrint(
          'Stages: ${stages.map((s) => '${s.title} (${s.durationSeconds}s)').join(', ')}');
      return true;
    } catch (e) {
      debugPrint('Error saving stages config: $e');
      return false;
    }
  }

  /// Create initial stages by merging Excel data with defaults
  /// This is called only on first launch when no config exists
  Future<List<Stage>> createInitialStages() async {
    debugPrint('Creating initial stages from Excel + defaults...');

    final excelService = ExcelService();
    final excelSession = await excelService.readLastSession();

    final defaultSubStages = SubStage.defaultSubStages();

    if (excelSession != null) {
      // Apply +5s run bonus
      final durations = ExcelService.addRunBonus(excelSession.stageDurations);
      debugPrint('Excel durations with bonus: $durations');

      return [
        Stage(
          id: 'initialization',
          title: 'Initialization',
          durationSeconds: 3,
          subStages: defaultSubStages,
          savesToExcel: false,
        ),
        Stage(
          id: 'prep_ekg',
          title: 'Prepare to turn on EKG',
          durationSeconds: 5,
          subStages: defaultSubStages,
          savesToExcel: false,
        ),
        Stage(
          id: 'prep_treadmill',
          title: 'Prepare to turn on treadmill',
          durationSeconds: durations['prep_treadmill'] ?? 10,
          subStages: defaultSubStages,
          savesToExcel: true,
        ),
        Stage(
          id: 'treadmill_countdown',
          title: 'Treadmill countdown',
          durationSeconds: 3,
          subStages: defaultSubStages,
          savesToExcel: false,
        ),
        Stage(
          id: 'accelerate',
          title: 'Accelerate',
          durationSeconds: 15,
          subStages: defaultSubStages,
          savesToExcel: false,
        ),
        Stage(
          id: 'run',
          title: 'Run',
          durationSeconds: durations['run'] ?? 300,
          subStages: defaultSubStages,
          savesToExcel: true,
        ),
        Stage(
          id: 'decelerate',
          title: 'Decelerate',
          durationSeconds: 12,
          subStages: defaultSubStages,
          savesToExcel: false,
        ),
        Stage(
          id: 'walk',
          title: 'Walk',
          durationSeconds: durations['walk'] ?? 180,
          subStages: defaultSubStages,
          savesToExcel: true,
        ),
      ];
    } else {
      // No Excel data, use pure defaults
      debugPrint('No Excel data found, using defaults');
      return Stage.defaultStages();
    }
  }

  /// Load stages - from config if exists, otherwise create initial stages
  /// Always refreshes primary stage durations from Excel with +5s run bonus
  Future<List<Stage>> loadStages() async {
    // First try to load from config file (for secondary stages structure)
    final config = await loadConfig();

    if (config != null && config.hasStages) {
      // Config exists - refresh primary stages from Excel with +5s bonus
      final refreshedStages = await refreshFromExcel(config.stages);
      return refreshedStages;
    }

    // No config exists, create initial stages from Excel + defaults
    final stages = await createInitialStages();

    // Save the initial stages so they persist
    await saveStages(stages);

    return stages;
  }

  /// Update stages with fresh Excel data (for primary stages only)
  /// Keeps secondary stages from current config, updates primary stages from Excel
  Future<List<Stage>> refreshFromExcel(List<Stage> currentStages) async {
    final excelService = ExcelService();
    final excelSession = await excelService.readLastSession();

    if (excelSession == null) {
      debugPrint('No Excel data to refresh from');
      return currentStages;
    }

    final durations = ExcelService.addRunBonus(excelSession.stageDurations);
    debugPrint('Refreshing from Excel with durations: $durations');

    // Update only the primary stages (those that save to Excel)
    return currentStages.map((stage) {
      if (stage.savesToExcel && durations.containsKey(stage.id)) {
        return stage.copyWith(durationSeconds: durations[stage.id]);
      }
      return stage;
    }).toList();
  }
}
