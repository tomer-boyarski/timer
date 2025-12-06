import 'dart:async';
import 'package:flutter/material.dart';
import '../services/services.dart';

/// Timer display screen showing countdown with large text and progress bar.
class TimerScreen extends StatefulWidget {
  final TimerConfig config;

  const TimerScreen({super.key, required this.config});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final AudioService _audioService = AudioService();
  Timer? _timer;
  DateTime? _startTime;
  int _currentStageIndex = 0;
  int _currentStageRemaining = 0;
  bool _isFinished = false;
  bool _isGeneratingAudio = true;
  String? _lastAnnouncement;

  // Total elapsed time in seconds (for progress bar)
  double _totalElapsedSeconds = 0.0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() async {
    await _audioService.initialize();

    // Set up announcement callback
    _audioService.onAnnouncementSpoken = (text) {
      if (!mounted) return;
      setState(() {
        _lastAnnouncement = text;
      });
      // Clear after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _lastAnnouncement == text) {
          setState(() {
            _lastAnnouncement = null;
          });
        }
      });
    };

    // Initialize timer state
    _currentStageIndex = 0;
    _currentStageRemaining = widget.config.stages[0].durationSeconds;

    // Start audio announcements with platform-specific offset
    // On Windows, this generates the audio file first, then calls the callback
    await _audioService.startAnnouncementPlayback(
      widget.config.stages,
      Duration(milliseconds: (widget.config.audioOffset * 1000).round()),
      () {
        // This callback is called when the visual timer should start
        if (!mounted) return;
        setState(() {
          _isGeneratingAudio = false;
        });
        _startTime = DateTime.now();

        // Update display every 100ms
        _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          _updateTimer();
        });
      },
    );
  }

  void _updateTimer() {
    if (_startTime == null || _isFinished) return;

    final elapsed = DateTime.now().difference(_startTime!);
    final totalElapsedSeconds = elapsed.inMilliseconds / 1000;

    setState(() {
      _totalElapsedSeconds = totalElapsedSeconds;
    });

    // Find current stage and remaining time
    var stageStartOffset = 0;
    for (int i = 0; i < widget.config.stages.length; i++) {
      final stage = widget.config.stages[i];
      final stageEnd = stageStartOffset + stage.durationSeconds;

      if (totalElapsedSeconds < stageEnd) {
        final stageElapsed = totalElapsedSeconds - stageStartOffset;
        final remaining = stage.durationSeconds - stageElapsed;

        setState(() {
          _currentStageIndex = i;
          _currentStageRemaining = remaining.ceil();
        });
        return;
      }

      stageStartOffset = stageEnd;
    }

    // All stages complete
    setState(() {
      _isFinished = true;
      _currentStageRemaining = 0;
    });
    _timer?.cancel();
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  int get _totalDurationSeconds {
    return widget.config.stages
        .fold(0, (sum, stage) => sum + stage.durationSeconds);
  }

  double get _progressPercent {
    if (_totalDurationSeconds == 0) return 0.0;
    return (_totalElapsedSeconds / _totalDurationSeconds).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final fontSize = screenSize.shortestSide * 0.35;

    // Show loading screen while generating audio on Windows
    if (_isGeneratingAudio) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'Generating audio...',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isFinished) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'FINISHED',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenSize.shortestSide * 0.12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final currentStage = _currentStageIndex < widget.config.stages.length
        ? widget.config.stages[_currentStageIndex]
        : null;

    // Calculate progress bar dimensions based on timer text size
    final timerTextHeight = fontSize * 0.8; // Approximate text height
    final progressBarHeight = timerTextHeight * 0.5;
    final progressBarBorderWidth = fontSize * 0.05;

    // Calculate progress percentages
    final percentComplete = _progressPercent * 100;
    final percentRemaining = (1 - _progressPercent) * 100;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main timer display
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Stage title
                  if (currentStage != null)
                    Text(
                      currentStage.title,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Time remaining
                  Text(
                    _formatTime(_currentStageRemaining),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Progress bar with percentage labels
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.1,
                    ),
                    child: _buildProgressBar(
                      progressBarHeight: progressBarHeight,
                      borderWidth: progressBarBorderWidth,
                      percentComplete: percentComplete,
                      percentRemaining: percentRemaining,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Stage progress indicator (dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.config.stages.length,
                      (index) => Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _currentStageIndex
                              ? Colors.green
                              : index == _currentStageIndex
                                  ? Colors.white
                                  : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Announcement overlay
            if (_lastAnnouncement != null)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _lastAnnouncement!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // Back button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  _timer?.cancel();
                  _audioService.stop();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the progress bar with percentage labels
  Widget _buildProgressBar({
    required double progressBarHeight,
    required double borderWidth,
    required double percentComplete,
    required double percentRemaining,
  }) {
    return Row(
      children: [
        // Left percentage (completed - black text on left)
        SizedBox(
          width: 70,
          child: Text(
            '${percentComplete.toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Progress bar
        Expanded(
          child: Container(
            height: progressBarHeight,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white,
                width: borderWidth,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  // Black background
                  Container(color: Colors.black),
                  // White fill (progress from left to right)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressPercent,
                    child: Container(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Right percentage (remaining - white text on right)
        SizedBox(
          width: 70,
          child: Text(
            '${percentRemaining.toStringAsFixed(1)}%',
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
