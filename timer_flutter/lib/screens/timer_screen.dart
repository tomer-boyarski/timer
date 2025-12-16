import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
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
  AudioPlayer? _audioPlayer; // Only used on Windows

  bool _isGeneratingAudio = false;
  bool _isRunning = false;
  bool _isPaused = false;
  String? _audioFilePath;

  // Timer state
  int _currentStageIndex = 0;
  int _stageElapsedTenths = 0; // Elapsed time in tenths of seconds
  int _totalElapsedTenths = 0; // Elapsed time in tenths of seconds
  Timer? _timer;

  // Platform checks
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  // Computed values
  int get _totalDurationSeconds =>
      widget.stages.fold(0, (sum, s) => sum + s.durationSeconds);
  Stage get _currentStage => widget.stages[_currentStageIndex];
  int get _stageRemainingTenths =>
      (_currentStage.durationSeconds * 10) - _stageElapsedTenths;
  int get _totalRemainingTenths =>
      (_totalDurationSeconds * 10) - _totalElapsedTenths;

  // Progress is now per-stage (0.0 to 1.0)
  double get _stageProgressPercent {
    if (_currentStage.durationSeconds == 0) return 0.0;
    return (_stageElapsedTenths / (_currentStage.durationSeconds * 10))
        .clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _startTimerWithAudio();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer?.dispose();
    _audioService.dispose();
    // Clean up audio file
    if (_audioFilePath != null && !kIsWeb) {
      try {
        File(_audioFilePath!).deleteSync();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _startTimerWithAudio() async {
    if (_isWindows) {
      // Windows: Pre-generate audio file first
      setState(() {
        _isGeneratingAudio = true;
      });

      try {
        final audioPath = await _audioService.startAnnouncementPlayback(
          widget.stages,
          Duration.zero, // No offset needed
          () {}, // Not used for Windows
        );

        if (audioPath != null && mounted) {
          _audioFilePath = audioPath;

          // Create audio player and start playback
          _audioPlayer = AudioPlayer();
          await _audioPlayer!.play(DeviceFileSource(audioPath));

          setState(() {
            _isGeneratingAudio = false;
            _isRunning = true;
          });

          // Start visual timer immediately with audio
          _startTimer();
        } else if (mounted) {
          // Audio generation failed, start timer without audio
          setState(() {
            _isGeneratingAudio = false;
            _isRunning = true;
          });
          _startTimer();
        }
      } catch (e) {
        debugPrint('Error generating audio: $e');
        if (mounted) {
          setState(() {
            _isGeneratingAudio = false;
            _isRunning = true;
          });
          _startTimer();
        }
      }
    } else {
      // Android/iOS/Web: Use real-time TTS with scheduled timers
      setState(() {
        _isRunning = true;
      });

      await _audioService.startAnnouncementPlayback(
        widget.stages,
        Duration.zero, // No offset needed for real-time TTS
        _startTimer,
      );
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_isPaused && mounted) {
        setState(() {
          _totalElapsedTenths++;
          _stageElapsedTenths++;

          // Check if current stage is complete (every 10 tenths = 1 second)
          if (_stageElapsedTenths >= _currentStage.durationSeconds * 10) {
            if (_currentStageIndex < widget.stages.length - 1) {
              // Move to next stage
              _currentStageIndex++;
              _stageElapsedTenths = 0;
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

    if (_isWindows && _audioPlayer != null) {
      if (_isPaused) {
        _audioPlayer!.pause();
      } else {
        _audioPlayer!.resume();
      }
    }
  }

  void _stop() {
    _timer?.cancel();
    _audioPlayer?.stop();
    _audioService.stop();
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

  String _formatTime(int totalTenths) {
    final totalSeconds = totalTenths ~/ 10;
    final tenths = totalTenths % 10;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
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
              child: Column(
                children: [
                  Text(
                    _formatTime(_stageRemainingTenths),
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${percentComplete.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Stage progress bar (3x thicker)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _stageProgressPercent,
                minHeight: 60,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[700]!
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
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
