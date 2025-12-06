import 'dart:async';

import 'package:stts/stts.dart';
import '../models/models.dart';

/// Represents an announcement to be made at a specific time.
class Announcement {
  /// Time remaining when announcement should trigger (seconds from stage end)
  final int remainingSeconds;

  /// The text to announce
  final String text;

  /// Whether this is a stage title announcement
  final bool isStageTitle;

  /// The stage this announcement belongs to
  final String stageId;

  const Announcement({
    required this.remainingSeconds,
    required this.text,
    required this.stageId,
    this.isStageTitle = false,
  });
}

/// Audio generator and player for timer announcements.
class AudioService {
  final Tts _tts = Tts();
  bool _isInitialized = false;
  Timer? _announcementTimer;

  /// Callback when an announcement is spoken
  Function(String text)? onAnnouncementSpoken;

  /// Initialize TTS engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setLanguage('en-US');
    await _tts.setRate(0.5); // Normal rate
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _isInitialized = true;
  }

  /// Set speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    await _tts.setRate(rate);
  }

  /// Speak text immediately
  Future<void> speak(String text) async {
    await initialize();
    await _tts.start(text);
    onAnnouncementSpoken?.call(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
    _announcementTimer?.cancel();
  }

  /// Generate all announcements for the given stages
  List<Announcement> generateAnnouncements(List<Stage> stages) {
    final announcements = <Announcement>[];

    for (final stage in stages) {
      // Add stage title announcement (at start of stage, i.e., full duration remaining)
      announcements.add(Announcement(
        remainingSeconds: stage.durationSeconds,
        text: stage.title,
        stageId: stage.id,
        isStageTitle: true,
      ));

      // Add regular announcements from stage
      final stageAnnouncements = stage.generateAnnouncements();
      for (final (remaining, text) in stageAnnouncements) {
        announcements.add(Announcement(
          remainingSeconds: remaining,
          text: text,
          stageId: stage.id,
        ));
      }
    }

    return announcements;
  }

  /// Generate all announcements with absolute timing (from total start)
  List<(Duration, Announcement)> generateTimedAnnouncements(
    List<Stage> stages,
  ) {
    final timedAnnouncements = <(Duration, Announcement)>[];
    var stageStartOffset = Duration.zero;

    for (final stage in stages) {
      final stageDuration = Duration(seconds: stage.durationSeconds);

      // Stage title at start of stage
      timedAnnouncements.add((
        stageStartOffset,
        Announcement(
          remainingSeconds: stage.durationSeconds,
          text: stage.title,
          stageId: stage.id,
          isStageTitle: true,
        ),
      ));

      // Regular announcements
      final stageAnnouncements = stage.generateAnnouncements();
      for (final (remaining, text) in stageAnnouncements) {
        // Calculate absolute time from total start
        final absoluteTime =
            stageStartOffset + stageDuration - Duration(seconds: remaining);
        timedAnnouncements.add((
          absoluteTime,
          Announcement(
            remainingSeconds: remaining,
            text: text,
            stageId: stage.id,
          ),
        ));
      }

      stageStartOffset += stageDuration;
    }

    // Add "Finished" at the very end
    timedAnnouncements.add((
      stageStartOffset,
      const Announcement(
        remainingSeconds: 0,
        text: 'Finished',
        stageId: 'finished',
        isStageTitle: false,
      ),
    ));

    // Sort by time
    timedAnnouncements.sort((a, b) => a.$1.compareTo(b.$1));
    return timedAnnouncements;
  }

  /// Start announcement playback synchronized with timer
  void startAnnouncementPlayback(
    List<Stage> stages,
    Duration audioOffset,
  ) {
    final timedAnnouncements = generateTimedAnnouncements(stages);

    // Schedule all announcements
    for (final (time, announcement) in timedAnnouncements) {
      final adjustedTime = time + audioOffset;
      if (adjustedTime.isNegative) {
        // Play immediately if offset pushes it before start
        speak(announcement.text);
      } else {
        Timer(adjustedTime, () {
          speak(announcement.text);
        });
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _announcementTimer?.cancel();
    _tts.stop();
    _tts.dispose();
  }
}
