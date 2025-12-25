import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/widgets.dart';
import 'timer_screen.dart';

/// Configuration screen for setting up timer stages.
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final ConfigManager _configManager = ConfigManager();
  final ExcelService _excelService = ExcelService();
  TimerConfig? _config;
  bool _isLoading = true;
  String? _loadSource; // Track where config was loaded from

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    // First try to load from Excel
    final excelSession = await _excelService.readLastSession();

    if (excelSession != null) {
      // Create stages from Excel data with +5s run bonus
      final stages = Stage.fromExcelSession(excelSession);
      setState(() {
        _config = TimerConfig(
          stages: stages,
          audioOffset: TimerConfig.getPlatformAudioOffset(),
          ttsRateNormal: 180,
          ttsRateCountdown: 250,
        );
        _loadSource = 'Excel (last session + 5s run)';
        _isLoading = false;
      });
    } else {
      // Fall back to saved config or defaults
      final config = await _configManager.loadConfig();
      setState(() {
        _config = config;
        _loadSource = 'Default configuration';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAndStart() async {
    if (_config == null) return;

    // Save configuration
    await _configManager.saveConfig(_config!);

    // Navigate to timer screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => TimerScreen(stages: _config!.stages),
        ),
      );
    }
  }

  void _addStage() {
    if (_config == null) return;

    const uuid = Uuid();
    final newStage = Stage(
      id: uuid.v4(),
      title: 'Stage ${_config!.stages.length + 1}',
      durationSeconds: 60,
      subStages: SubStage.defaultSubStages(),
    );

    setState(() {
      _config = _config!.copyWith(
        stages: [..._config!.stages, newStage],
      );
    });
  }

  void _removeStage(int index) {
    if (_config == null || _config!.stages.length <= 1) return;

    setState(() {
      final stages = List<Stage>.from(_config!.stages)..removeAt(index);
      _config = _config!.copyWith(stages: stages);
    });
  }

  void _updateStage(int index, Stage stage) {
    if (_config == null) return;

    setState(() {
      final stages = List<Stage>.from(_config!.stages);
      stages[index] = stage;
      _config = _config!.copyWith(stages: stages);
    });
  }

  void _reorderStages(int oldIndex, int newIndex) {
    if (_config == null) return;

    setState(() {
      final stages = List<Stage>.from(_config!.stages);
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final stage = stages.removeAt(oldIndex);
      stages.insert(newIndex, stage);
      _config = _config!.copyWith(stages: stages);
    });
  }

  Future<void> _resetToDefault() async {
    final config = await _configManager.resetToDefault();
    setState(() {
      _config = config;
    });
  }

  String _formatTotalDuration() {
    if (_config == null) return '00:00';
    final total = _config!.totalDurationSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _config == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Timer Configuration'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to Default',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: Column(
        children: [
          // Total duration header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Duration: ${_formatTotalDuration()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_config!.stages.length} stage${_config!.stages.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (_loadSource != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Loaded from: $_loadSource',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Stages list
          Expanded(
            child: ReorderableListView.builder(
              itemCount: _config!.stages.length,
              onReorder: _reorderStages,
              itemBuilder: (context, index) {
                final stage = _config!.stages[index];
                return StageEditor(
                  key: ValueKey(stage.id),
                  stage: stage,
                  index: index,
                  canRemove: _config!.stages.length > 1,
                  onChanged: (updated) => _updateStage(index, updated),
                  onRemove: () => _removeStage(index),
                );
              },
            ),
          ),
          // Add stage button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _addStage,
              icon: const Icon(Icons.add),
              label: const Text('Add Stage'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
          // Start button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _saveAndStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('START'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
