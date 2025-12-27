import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Completion screen shown after timer finishes all stages.
/// Shows celebration, "Turn off EKG" announcement, and save options.
class CompletionScreen extends StatefulWidget {
  final List<Stage> stages;
  final AudioService audioService;

  const CompletionScreen({
    super.key,
    required this.stages,
    required this.audioService,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen>
    with SingleTickerProviderStateMixin {
  final ExcelService _excelService = ExcelService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Track which stages to save (only stages that save to Excel)
  late Map<String, bool> _stagesToSave;

  bool _isSaving = false;
  bool _saved = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();

    // Initialize save checkboxes - only for stages that save to Excel
    _stagesToSave = {};
    for (final stage in widget.stages) {
      if (stage.savesToExcel) {
        _stagesToSave[stage.id] = true; // Default all to checked
      }
    }

    // Setup celebration animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    // Start animation and announce
    _animationController.forward();
    _announceCompletion();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _announceCompletion() async {
    // Use TTS to announce "Turn off EKG"
    await widget.audioService.speak('Turn off EKG');
  }

  Future<void> _saveSession() async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      // Build durations map from selected stages
      final stageDurations = <String, int>{};

      for (final stage in widget.stages) {
        if (stage.savesToExcel && (_stagesToSave[stage.id] ?? false)) {
          stageDurations[stage.id] = stage.durationSeconds;
        }
      }

      if (stageDurations.isEmpty) {
        setState(() {
          _isSaving = false;
          _saveError = 'No stages selected to save';
        });
        return;
      }

      final success = await _excelService.appendSession(
        stageDurations: stageDurations,
      );

      setState(() {
        _isSaving = false;
        if (success) {
          _saved = true;
        } else {
          _saveError = 'Failed to save to Excel file';
        }
      });
    } catch (e) {
      setState(() {
        _isSaving = false;
        _saveError = 'Error: $e';
      });
    }
  }

  void _returnToConfig() {
    // Pop back to config screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // Celebration animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: const Column(
                  children: [
                    Icon(
                      Icons.celebration,
                      size: 80,
                      color: Colors.amber,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '🎉 Congratulations! 🎉',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'All stages completed!',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Turn off EKG reminder
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'TURN OFF EKG',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save options
              if (!_saved) ...[
                const Text(
                  'Select stages to save:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // Stage checkboxes
                Expanded(
                  child: ListView(
                    children: widget.stages
                        .where((s) => s.savesToExcel)
                        .map((stage) => CheckboxListTile(
                              title: Text(
                                stage.title,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                '${stage.durationSeconds}s (${stage.formattedDuration})',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              value: _stagesToSave[stage.id] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  _stagesToSave[stage.id] = value ?? false;
                                });
                              },
                              activeColor: Colors.green,
                              checkColor: Colors.white,
                            ))
                        .toList(),
                  ),
                ),

                if (_saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _saveError!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Save button
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSession,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save to Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                // Saved successfully
                const Spacer(),
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Session saved to Excel!',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
              ],

              const SizedBox(height: 16),

              // Done button
              ElevatedButton(
                onPressed: _returnToConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                  ),
                ),
                child: Text(_saved ? 'Done' : 'Skip & Return'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
