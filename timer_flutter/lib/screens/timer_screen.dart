import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/models.dart';
import '../services/audio_service.dart';

class TimerScreen extends StatefulWidget {
  final List<Stage> stages;

  const TimerScreen({super.key, required this.stages});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final AudioService _audioService = AudioService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isGeneratingAudio = false;
  bool _isRunning = false;
  bool _isPaused = false;
  String? _audioFilePath;

  // Timer state
  int _currentStageIndex = 0;
  int _stageElapsedSeconds = 0; // Elapsed seconds within current stage
  int _totalElapsedSeconds = 0;
  Timer? _timer;

  // Computed values
  int get _totalDurationSeconds =>
      widget.stages.fold(0, (sum, s) => sum + s.durationSeconds);
  Stage get _currentStage => widget.stages[_currentStageIndex];
  int get _stageRemainingSeconds =>
      _currentStage.durationSeconds - _stageElapsedSeconds;
  int get _totalRemainingSeconds =>
      _totalDurationSeconds - _totalElapsedSeconds;

  // Progress is now per-stage (0.0 to 1.0)
  double get _stageProgressPercent {
    if (_currentStage.durationSeconds == 0) return 0.0;
    return (_stageElapsedSeconds / _currentStage.durationSeconds)
        .clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _generateAudioAndStart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    // Clean up audio file
    if (_audioFilePath != null) {
      try {
        File(_audioFilePath!).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _generateAudioAndStart() async {
    setState(() {
      _isGeneratingAudio = true;
    });

    try {
      // Generate the audio file using Windows SAPI
      final audioPath = await _audioService.generateFullAudio(widget.stages);

      if (mounted) {
        _audioFilePath = audioPath;

        // Load and start playing
        await _audioPlayer.setFilePath(audioPath);
        await _audioPlayer.play();

        setState(() {
          _isGeneratingAudio = false;
          _isRunning = true;
        });

        _startTimer();
      } else if (mounted) {
        // Audio generation failed, but we can still run the timer silently
        setState(() {
          _isGeneratingAudio = false;
          _isRunning = true;
        });
        _startTimer();
      }
    } catch (e) {
      debugPrint('Error generating audio: $e');
      if (mounted) {
        // Start timer anyway without audio
        setState(() {
          _isGeneratingAudio = false;
          _isRunning = true;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused && mounted) {
        setState(() {
          _totalElapsedSeconds++;
          _stageElapsedSeconds++;

          // Check if current stage is complete
          if (_stageElapsedSeconds >= _currentStage.durationSeconds) {
            if (_currentStageIndex < widget.stages.length - 1) {
              // Move to next stage
              _currentStageIndex++;
              _stageElapsedSeconds = 0;
            } else {
              // Timer complete
              _timer?.cancel();
              _isRunning = false;
              _showCompletionDialog();
            }
          }
        });
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _stop() {
    _timer?.cancel();
    _audioPlayer.stop();
    Navigator.of(context).pop();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Timer Complete!'),
        content: const Text('All stages have been completed.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Return to config
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isGeneratingAudio) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Preparing Timer'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'Generating audio announcements...',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Allow user to skip audio generation
                  setState(() {
                    _isGeneratingAudio = false;
                    _isRunning = true;
                  });
                  _startTimer();
                },
                child: const Text('Skip (run without audio)'),
              ),
            ],
          ),
        ),
      );
    }

    final percentComplete = _stageProgressPercent * 100;

    return Scaffold(
      appBar: AppBar(
        title: Text('Stage ${_currentStageIndex + 1}: ${_currentStage.title}'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stage info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _currentStage.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stage ${_currentStageIndex + 1} of ${widget.stages.length}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Stage time remaining (large display)
            Center(
              child: Text(
                _formatTime(_stageRemainingSeconds),
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Total time remaining (smaller)
            Center(
              child: Text(
                'Total: ${_formatTime(_totalRemainingSeconds)}',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.grey[600],
                  fontFamily: 'monospace',
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Stage progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stage Progress: ${percentComplete.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _stageProgressPercent,
                    minHeight: 20,
                    backgroundColor: Colors.grey[300],
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _togglePause,
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(_isPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
