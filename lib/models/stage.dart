import 'sub_stage.dart';

/// Stage model representing a timed segment with title and sub-stages.
///
/// Each stage has a title (announced at start), duration, and sub-stages
/// that control announcement frequency and verbosity.
class Stage {
  /// Unique identifier for the stage
  final String id;

  /// Title of the stage (announced at start via TTS)
  final String title;

  /// Duration of the stage in seconds
  final int durationSeconds;

  /// Sub-stages for announcement configuration
  final List<SubStage> subStages;

  const Stage({
    required this.id,
    required this.title,
    required this.durationSeconds,
    required this.subStages,
  });

  /// Create from JSON map
  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: json['id'] as String,
      title: json['title'] as String,
      durationSeconds: json['duration_seconds'] as int,
      subStages: (json['sub_stages'] as List<dynamic>)
          .map((e) => SubStage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'duration_seconds': durationSeconds,
      'sub_stages': subStages.map((s) => s.toJson()).toList(),
    };
  }

  /// Create a copy with modified fields
  Stage copyWith({
    String? id,
    String? title,
    int? durationSeconds,
    List<SubStage>? subStages,
  }) {
    return Stage(
      id: id ?? this.id,
      title: title ?? this.title,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      subStages: subStages ?? this.subStages,
    );
  }

  /// Format duration as MM:SS string
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Parse duration from MM:SS string
  static int parseDuration(String duration) {
    final parts = duration.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return minutes * 60 + seconds;
    }
    return 0;
  }

  /// Get the sub-stage for a given remaining time
  SubStage getSubStageForTime(int remainingSeconds) {
    // Sort sub-stages by threshold descending (highest first)
    final sorted = List<SubStage>.from(subStages)
      ..sort((a, b) => b.durationThreshold.compareTo(a.durationThreshold));

    for (final subStage in sorted) {
      if (remainingSeconds <= subStage.durationThreshold) {
        return subStage;
      }
    }

    // Return "everything" sub-stage (threshold = 0) as fallback
    return sorted.lastWhere(
      (s) => s.durationThreshold == 0,
      orElse: () => sorted.last,
    );
  }

  /// Generate announcements for this stage
  /// Returns list of (remainingSeconds, text) pairs
  List<(int, String)> generateAnnouncements() {
    final announcements = <(int, String)>[];
    final processedTimes = <int>{};

    // Sort sub-stages by threshold descending
    final sorted = List<SubStage>.from(subStages)
      ..sort((a, b) => b.durationThreshold.compareTo(a.durationThreshold));

    for (int i = 0; i < sorted.length; i++) {
      final subStage = sorted[i];
      final int start;
      final int end;

      if (subStage.durationThreshold == 0) {
        // "Everything" sub-stage: from total duration down to next threshold
        start = durationSeconds;
        end = i > 0 ? sorted[i - 1].durationThreshold : 0;
      } else {
        // Specific sub-stage
        start = subStage.durationThreshold < durationSeconds
            ? subStage.durationThreshold
            : durationSeconds;
        end = i + 1 < sorted.length ? sorted[i + 1].durationThreshold : 0;
      }

      // Generate announcements at interval
      int current = start;
      while (current > end) {
        final announcementTime = (current ~/ subStage.announcementInterval) *
            subStage.announcementInterval;

        if (announcementTime > end &&
            announcementTime <= durationSeconds &&
            !processedTimes.contains(announcementTime) &&
            announcementTime > 0) {
          final text = subStage.formatAnnouncement(announcementTime);
          announcements.add((announcementTime, text));
          processedTimes.add(announcementTime);
        }

        current -= subStage.announcementInterval;
      }
    }

    // Sort by remaining seconds descending (earliest announcements first)
    announcements.sort((a, b) => b.$1.compareTo(a.$1));
    return announcements;
  }

  /// Default stages configuration
  static List<Stage> defaultStages() {
    final defaultSubStages = SubStage.defaultSubStages();
    return [
      Stage(
        id: 'preparation',
        title: 'Preparation',
        durationSeconds: 30,
        subStages: defaultSubStages,
      ),
      Stage(
        id: 'start',
        title: 'Start',
        durationSeconds: 3,
        subStages: defaultSubStages,
      ),
      Stage(
        id: 'go',
        title: 'Go',
        durationSeconds: 455, // 7 minutes 35 seconds
        subStages: defaultSubStages,
      ),
      Stage(
        id: 'cooldown',
        title: 'Cool Down',
        durationSeconds: 120, // 2 minutes
        subStages: defaultSubStages,
      ),
    ];
  }
}
