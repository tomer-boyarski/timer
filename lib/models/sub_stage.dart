/// SubStage model for announcement configuration within a stage.
///
///
/// Each stage can have multiple sub-stages with different announcement
/// frequencies and verbosity settings.
class SubStage {
  /// Name of the sub-stage (e.g., "countdown", "one_minute", "everything")
  final String name;

  /// Duration threshold in seconds (time remaining when this sub-stage applies)
  /// Use 0 for "rest of stage" (default sub-stage)
  final int durationThreshold;

  /// Interval between announcements in seconds
  final int announcementInterval;

  /// Verbosity level: "low" (just numbers) or "high" (full phrases)
  final String verbosity;

  const SubStage({
    required this.name,
    required this.durationThreshold,
    required this.announcementInterval,
    required this.verbosity,
  });

  /// Create from JSON map
  factory SubStage.fromJson(Map<String, dynamic> json) {
    return SubStage(
      name: json['name'] as String,
      durationThreshold: json['duration_threshold'] as int,
      announcementInterval: json['announcement_interval'] as int,
      verbosity: json['verbosity'] as String,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'duration_threshold': durationThreshold,
      'announcement_interval': announcementInterval,
      'verbosity': verbosity,
    };
  }

  /// Create a copy with modified fields
  SubStage copyWith({
    String? name,
    int? durationThreshold,
    int? announcementInterval,
    String? verbosity,
  }) {
    return SubStage(
      name: name ?? this.name,
      durationThreshold: durationThreshold ?? this.durationThreshold,
      announcementInterval: announcementInterval ?? this.announcementInterval,
      verbosity: verbosity ?? this.verbosity,
    );
  }

  /// Format announcement text based on verbosity
  String formatAnnouncement(int remainingSeconds) {
    if (verbosity == 'low') {
      return remainingSeconds.toString();
    }

    // High verbosity: full phrase with "remaining"
    if (remainingSeconds >= 60) {
      final minutes = remainingSeconds ~/ 60;
      final seconds = remainingSeconds % 60;
      if (seconds == 0) {
        final minuteWord = minutes == 1 ? 'minute' : 'minutes';
        return '$minutes $minuteWord remaining';
      } else {
        final minuteWord = minutes == 1 ? 'minute' : 'minutes';
        final secondWord = seconds == 1 ? 'second' : 'seconds';
        return '$minutes $minuteWord $seconds $secondWord remaining';
      }
    } else {
      final secondWord = remainingSeconds == 1 ? 'second' : 'seconds';
      return '$remainingSeconds $secondWord remaining';
    }
  }

  /// Default sub-stages configuration
  static List<SubStage> defaultSubStages() {
    return const [
      SubStage(
        name: 'countdown',
        durationThreshold: 10,
        announcementInterval: 1,
        verbosity: 'low',
      ),
      SubStage(
        name: 'one_minute',
        durationThreshold: 60,
        announcementInterval: 10,
        verbosity: 'high',
      ),
      SubStage(
        name: 'everything',
        durationThreshold: 0,
        announcementInterval: 60,
        verbosity: 'high',
      ),
    ];
  }
}
