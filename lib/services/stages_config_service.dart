import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/sub_stage.dart';
import '../models/stage.dart';

/// Configuration for a secondary stage (not saved to Excel)
class SecondaryStageConfig {
  final String id;
  final String title;
  final int durationSeconds;
  final String position; // e.g., "before_prep_treadmill", "after_run"
  final int order; // Order within the same position

  const SecondaryStageConfig({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.position,
    required this.order,
  });

  factory SecondaryStageConfig.fromJson(Map<String, dynamic> json) {
    return SecondaryStageConfig(
      id: json['id'] as String,
      title: json['title'] as String,
      durationSeconds: json['duration_seconds'] as int,
      position: json['position'] as String,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration_seconds': durationSeconds,
      'position': position,
      'order': order,
    };
  }

  SecondaryStageConfig copyWith({
    String? id,
    String? title,
    int? durationSeconds,
    String? position,
    int? order,
  }) {
    return SecondaryStageConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      position: position ?? this.position,
      order: order ?? this.order,
    );
  }

  /// Convert to a Stage object
  Stage toStage() {
    return Stage(
      id: id,
      title: title,
      durationSeconds: durationSeconds,
      subStages: SubStage.defaultSubStages(),
      savesToExcel: false, // Secondary stages are not saved to Excel
    );
  }
}

/// Full stages configuration including secondary stages
class StagesConfig {
  final int version;
  final String description;
  final List<SecondaryStageConfig> secondaryStages;
  final List<String> primaryStagesOrder;
  final DateTime? lastUpdated;

  const StagesConfig({
    required this.version,
    required this.description,
    required this.secondaryStages,
    required this.primaryStagesOrder,
    this.lastUpdated,
  });

  factory StagesConfig.fromJson(Map<String, dynamic> json) {
    return StagesConfig(
      version: json['version'] as int? ?? 1,
      description: json['description'] as String? ?? '',
      secondaryStages: (json['secondary_stages'] as List<dynamic>?)
              ?.map((e) =>
                  SecondaryStageConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      primaryStagesOrder: (json['primary_stages_order'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['prep_treadmill', 'run', 'walk'],
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'description': description,
      'secondary_stages': secondaryStages.map((s) => s.toJson()).toList(),
      'primary_stages_order': primaryStagesOrder,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }

  StagesConfig copyWith({
    int? version,
    String? description,
    List<SecondaryStageConfig>? secondaryStages,
    List<String>? primaryStagesOrder,
    DateTime? lastUpdated,
  }) {
    return StagesConfig(
      version: version ?? this.version,
      description: description ?? this.description,
      secondaryStages: secondaryStages ?? this.secondaryStages,
      primaryStagesOrder: primaryStagesOrder ?? this.primaryStagesOrder,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get secondary stages for a specific position
  List<SecondaryStageConfig> getStagesAtPosition(String position) {
    return secondaryStages
        .where((s) => s.position == position)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Default configuration
  static StagesConfig defaultConfig() {
    return const StagesConfig(
      version: 1,
      description:
          'Secondary stages configuration. Primary stages (prep_treadmill, run, walk) are loaded from Excel.',
      secondaryStages: [
        SecondaryStageConfig(
          id: 'initialization',
          title: 'Initialization',
          durationSeconds: 3,
          position: 'before_prep_treadmill',
          order: 0,
        ),
        SecondaryStageConfig(
          id: 'prep_ekg',
          title: 'Prepare to turn on EKG',
          durationSeconds: 5,
          position: 'before_prep_treadmill',
          order: 1,
        ),
        SecondaryStageConfig(
          id: 'treadmill_countdown',
          title: 'Treadmill countdown',
          durationSeconds: 5,
          position: 'after_prep_treadmill',
          order: 0,
        ),
        SecondaryStageConfig(
          id: 'accelerate',
          title: 'Accelerate',
          durationSeconds: 15,
          position: 'after_treadmill_countdown',
          order: 0,
        ),
        SecondaryStageConfig(
          id: 'decelerate',
          title: 'Decelerate',
          durationSeconds: 12,
          position: 'after_run',
          order: 0,
        ),
      ],
      primaryStagesOrder: ['prep_treadmill', 'run', 'walk'],
    );
  }
}

/// Service for managing secondary stages configuration
class StagesConfigService {
  /// Path to the stages config file in the project directory
  static String get configPath {
    if (!kIsWeb && Platform.isWindows) {
      // Use the project directory for the config file
      // This works for both debug and release builds
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent.path;

      // Check if we're in a release build (exe in Release folder)
      if (exeDir.contains('Release') || exeDir.contains('Debug')) {
        // Go up to find the project root
        var dir = Directory(exeDir);
        for (var i = 0; i < 7; i++) {
          final testPath = '${dir.path}\\stages_config.json';
          if (File(testPath).existsSync()) {
            return testPath;
          }
          final parent = dir.parent;
          if (parent.path == dir.path) break;
          dir = parent;
        }
      }

      // Try current working directory (for debug builds from IDE)
      final cwdPath = '${Directory.current.path}\\stages_config.json';
      if (File(cwdPath).existsSync()) {
        return cwdPath;
      }

      // Default to project root
      return r'C:\projects\timer\stages_config.json';
    }
    return 'stages_config.json';
  }

  /// Load the stages configuration from file
  Future<StagesConfig> loadConfig() async {
    try {
      final file = File(configPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        debugPrint('Loaded stages config from: $configPath');
        return StagesConfig.fromJson(json);
      }
    } catch (e) {
      debugPrint('Error loading stages config: $e');
    }

    debugPrint('Using default stages config');
    return StagesConfig.defaultConfig();
  }

  /// Save the stages configuration to file
  Future<bool> saveConfig(StagesConfig config) async {
    try {
      final file = File(configPath);

      // Update the last_updated timestamp
      final updatedConfig = config.copyWith(lastUpdated: DateTime.now());

      final jsonStr =
          const JsonEncoder.withIndent('  ').convert(updatedConfig.toJson());
      await file.writeAsString(jsonStr);

      debugPrint('Saved stages config to: $configPath');
      debugPrint(
          'Last updated: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(updatedConfig.lastUpdated!)}');
      return true;
    } catch (e) {
      debugPrint('Error saving stages config: $e');
      return false;
    }
  }

  /// Update secondary stages from a list of Stage objects
  /// This extracts the secondary stages from the full stage list and saves them
  Future<bool> saveFromStages(List<Stage> stages) async {
    try {
      final config = await loadConfig();

      // Extract secondary stages (those that don't save to Excel)
      final secondaryStages = <SecondaryStageConfig>[];
      var stageIndex = 0;

      for (final stage in stages) {
        if (!stage.savesToExcel) {
          // Determine position based on surrounding stages
          String position = _determinePosition(stages, stageIndex);

          // Find order within position
          final existingAtPosition =
              secondaryStages.where((s) => s.position == position).length;

          secondaryStages.add(SecondaryStageConfig(
            id: stage.id,
            title: stage.title,
            durationSeconds: stage.durationSeconds,
            position: position,
            order: existingAtPosition,
          ));
        }
        stageIndex++;
      }

      final updatedConfig = config.copyWith(
        secondaryStages: secondaryStages,
      );

      return await saveConfig(updatedConfig);
    } catch (e) {
      debugPrint('Error saving stages to config: $e');
      return false;
    }
  }

  /// Determine the position of a secondary stage based on surrounding primary stages
  String _determinePosition(List<Stage> stages, int index) {
    // Look for the next primary stage
    for (var i = index + 1; i < stages.length; i++) {
      if (stages[i].savesToExcel) {
        return 'before_${stages[i].id}';
      }
    }

    // Look for the previous primary stage
    for (var i = index - 1; i >= 0; i--) {
      if (stages[i].savesToExcel) {
        return 'after_${stages[i].id}';
      }
    }

    // Default position
    return 'before_prep_treadmill';
  }

  /// Build the complete stage list by merging primary stages (from Excel)
  /// with secondary stages (from config)
  List<Stage> buildStageList(
    Map<String, int> primaryDurations,
    StagesConfig config,
  ) {
    final stages = <Stage>[];
    final defaultSubStages = SubStage.defaultSubStages();

    // Add stages before prep_treadmill
    stages.addAll(config
        .getStagesAtPosition('before_prep_treadmill')
        .map((s) => s.toStage()));

    // Add prep_treadmill (primary)
    stages.add(Stage(
      id: 'prep_treadmill',
      title: 'Prepare to turn on treadmill',
      durationSeconds: primaryDurations['prep_treadmill'] ?? 10,
      subStages: defaultSubStages,
      savesToExcel: true,
    ));

    // Add stages after prep_treadmill
    stages.addAll(config
        .getStagesAtPosition('after_prep_treadmill')
        .map((s) => s.toStage()));

    // Add stages after treadmill_countdown (like accelerate)
    stages.addAll(config
        .getStagesAtPosition('after_treadmill_countdown')
        .map((s) => s.toStage()));

    // Add run (primary)
    stages.add(Stage(
      id: 'run',
      title: 'Run',
      durationSeconds: primaryDurations['run'] ?? 300,
      subStages: defaultSubStages,
      savesToExcel: true,
    ));

    // Add stages after run (like decelerate)
    stages.addAll(
        config.getStagesAtPosition('after_run').map((s) => s.toStage()));

    // Add walk (primary)
    stages.add(Stage(
      id: 'walk',
      title: 'Walk',
      durationSeconds: primaryDurations['walk'] ?? 180,
      subStages: defaultSubStages,
      savesToExcel: true,
    ));

    // Add stages after walk
    stages.addAll(
        config.getStagesAtPosition('after_walk').map((s) => s.toStage()));

    return stages;
  }
}
