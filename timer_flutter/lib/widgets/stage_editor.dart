import 'package:flutter/material.dart';
import '../models/models.dart';

/// Widget for editing a sub-stage configuration.
class SubStageEditor extends StatelessWidget {
  final SubStage subStage;
  final ValueChanged<SubStage> onChanged;
  final VoidCallback? onRemove;
  final bool canRemove;

  const SubStageEditor({
    super.key,
    required this.subStage,
    required this.onChanged,
    this.onRemove,
    this.canRemove = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Duration threshold
            Expanded(
              child: _DurationInput(
                label: 'Threshold',
                seconds: subStage.durationThreshold,
                onChanged: (value) {
                  onChanged(subStage.copyWith(durationThreshold: value));
                },
              ),
            ),
            const SizedBox(width: 8),
            // Interval
            Expanded(
              child: _DurationInput(
                label: 'Interval',
                seconds: subStage.announcementInterval,
                onChanged: (value) {
                  onChanged(subStage.copyWith(announcementInterval: value));
                },
              ),
            ),
            const SizedBox(width: 8),
            // Verbosity dropdown
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verbosity',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  DropdownButton<String>(
                    value: subStage.verbosity,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(subStage.copyWith(verbosity: value));
                      }
                    },
                  ),
                ],
              ),
            ),
            if (canRemove && onRemove != null)
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

/// Duration input widget (MM:SS format)
class _DurationInput extends StatefulWidget {
  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  const _DurationInput({
    required this.label,
    required this.seconds,
    required this.onChanged,
  });

  @override
  State<_DurationInput> createState() => _DurationInputState();
}

class _DurationInputState extends State<_DurationInput> {
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(_DurationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    final minutes = widget.seconds ~/ 60;
    final seconds = widget.seconds % 60;
    _minutesController = TextEditingController(text: minutes.toString());
    _secondsController = TextEditingController(
      text: seconds.toString().padLeft(2, '0'),
    );
  }

  void _onChanged() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    widget.onChanged(minutes * 60 + seconds);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Row(
          children: [
            SizedBox(
              width: 30,
              child: TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (_) => _onChanged(),
              ),
            ),
            const Text(':'),
            SizedBox(
              width: 30,
              child: TextField(
                controller: _secondsController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (_) => _onChanged(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }
}

/// Widget for editing a stage configuration.
class StageEditor extends StatelessWidget {
  final Stage stage;
  final int index;
  final ValueChanged<Stage> onChanged;
  final VoidCallback onRemove;
  final bool canRemove;

  const StageEditor({
    super.key,
    required this.stage,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    this.canRemove = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text('${index + 1}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: stage.title),
                decoration: const InputDecoration(
                  labelText: 'Stage Title',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  onChanged(stage.copyWith(title: value));
                },
              ),
            ),
            const SizedBox(width: 12),
            _StageDurationInput(
              seconds: stage.durationSeconds,
              onChanged: (value) {
                onChanged(stage.copyWith(durationSeconds: value));
              },
            ),
            if (canRemove)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onRemove,
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sub-stages',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Sub-stage'),
                      onPressed: () {
                        final newSubStages =
                            List<SubStage>.from(stage.subStages)
                              ..add(SubStage(
                                name: 'custom_${stage.subStages.length}',
                                durationThreshold: 30,
                                announcementInterval: 10,
                                verbosity: 'high',
                              ));
                        onChanged(stage.copyWith(subStages: newSubStages));
                      },
                    ),
                  ],
                ),
                const Divider(),
                // Header row
                const Row(
                  children: [
                    Expanded(
                        child:
                            Text('Threshold', style: TextStyle(fontSize: 11))),
                    SizedBox(width: 8),
                    Expanded(
                        child:
                            Text('Interval', style: TextStyle(fontSize: 11))),
                    SizedBox(width: 8),
                    Expanded(
                        child:
                            Text('Verbosity', style: TextStyle(fontSize: 11))),
                    SizedBox(width: 48),
                  ],
                ),
                ...stage.subStages.asMap().entries.map((entry) {
                  return SubStageEditor(
                    subStage: entry.value,
                    canRemove: stage.subStages.length > 1,
                    onChanged: (updated) {
                      final newSubStages = List<SubStage>.from(stage.subStages);
                      newSubStages[entry.key] = updated;
                      onChanged(stage.copyWith(subStages: newSubStages));
                    },
                    onRemove: () {
                      final newSubStages = List<SubStage>.from(stage.subStages)
                        ..removeAt(entry.key);
                      onChanged(stage.copyWith(subStages: newSubStages));
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Duration input for stage (larger format)
class _StageDurationInput extends StatefulWidget {
  final int seconds;
  final ValueChanged<int> onChanged;

  const _StageDurationInput({
    required this.seconds,
    required this.onChanged,
  });

  @override
  State<_StageDurationInput> createState() => _StageDurationInputState();
}

class _StageDurationInputState extends State<_StageDurationInput> {
  late TextEditingController _minutesController;
  late TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(_StageDurationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    final minutes = widget.seconds ~/ 60;
    final seconds = widget.seconds % 60;
    _minutesController = TextEditingController(text: minutes.toString());
    _secondsController = TextEditingController(
      text: seconds.toString().padLeft(2, '0'),
    );
  }

  void _onChanged() {
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    widget.onChanged(minutes * 60 + seconds);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            child: TextField(
              controller: _minutesController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              onChanged: (_) => _onChanged(),
            ),
          ),
          const Text(':',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(
            width: 40,
            child: TextField(
              controller: _secondsController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              onChanged: (_) => _onChanged(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }
}
