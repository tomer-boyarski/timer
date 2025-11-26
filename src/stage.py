"""
Stage-based announcement configuration.

See copilot_compliance in the root for code standards.
"""

from dataclasses import dataclass
from typing import List, Tuple


@dataclass
class Stage:
    """
    Represents an announcement stage with timing and verbosity settings.

    See copilot_compliance in the root for code standards.

    Attributes:
        name: Identifier for the stage ("countdown", "one_minute", "everything")
        duration_threshold: Seconds threshold for this stage (10, 60, or 0)
        announcement_interval: Seconds between announcements in this stage
        verbosity: "low" (just numbers) or "high" (full phrases)
    """

    name: str
    duration_threshold: int
    announcement_interval: int
    verbosity: str

    def format_announcement(self, remaining_seconds: int) -> str:
        """
        Format an announcement based on verbosity setting.

        See copilot_compliance in the root for code standards.

        Args:
            remaining_seconds: Seconds remaining when announcement triggers

        Returns:
            Formatted announcement text
        """
        if self.verbosity == "low":
            return str(remaining_seconds)

        # High verbosity: full phrase with "remaining"
        if remaining_seconds >= 60:
            minutes = remaining_seconds // 60
            leftover = remaining_seconds % 60
            if leftover == 0:
                minute_word = "minute" if minutes == 1 else "minutes"
                return f"{minutes} {minute_word} remaining"
            else:
                minute_word = "minute" if minutes == 1 else "minutes"
                second_word = "second" if leftover == 1 else "seconds"
                return f"{minutes} {minute_word} {leftover} {second_word} remaining"
        else:
            second_word = "second" if remaining_seconds == 1 else "seconds"
            return f"{remaining_seconds} {second_word} remaining"


class StageConfig:
    """
    Manages stage-based announcement configuration and generation.

    See copilot_compliance in the root for code standards.
    """

    def __init__(self, stages: List[Stage]) -> None:
        """
        Initialize with list of stages.

        See copilot_compliance in the root for code standards.

        Args:
            stages: List of Stage objects, ordered by duration_threshold descending
        """
        # Sort stages by duration_threshold descending (countdown first, everything last)
        self.stages = sorted(stages, key=lambda s: s.duration_threshold, reverse=True)

    @classmethod
    def default(cls) -> "StageConfig":
        """
        Create default stage configuration.

        See copilot_compliance in the root for code standards.

        Default stages:
        - Countdown (last 10s): every 1s, low verbosity (just numbers)
        - One Minute (last 60s): every 10s, high verbosity
        - Everything (rest): every 60s, high verbosity

        Returns:
            StageConfig with default stages
        """
        stages = [
            Stage(
                name="countdown",
                duration_threshold=10,
                announcement_interval=1,
                verbosity="low",
            ),
            Stage(
                name="one_minute",
                duration_threshold=60,
                announcement_interval=10,
                verbosity="high",
            ),
            Stage(
                name="everything",
                duration_threshold=0,
                announcement_interval=60,
                verbosity="high",
            ),
        ]
        return cls(stages)

    def get_stage_for_time(self, remaining_seconds: int) -> Stage:
        """
        Get the appropriate stage for a given remaining time.

        See copilot_compliance in the root for code standards.

        Args:
            remaining_seconds: Seconds remaining on timer

        Returns:
            Stage that applies to this time
        """
        for stage in self.stages:
            if remaining_seconds <= stage.duration_threshold:
                return stage
        # Return the "everything" stage (threshold=0) as fallback
        return self.stages[-1]

    def generate_announcements(
        self, total_seconds: int
    ) -> List[Tuple[int, str]]:
        """
        Generate list of announcements for a timer duration.

        See copilot_compliance in the root for code standards.

        Args:
            total_seconds: Total timer duration in seconds

        Returns:
            List of (remaining_seconds, announcement_text) tuples,
            sorted by remaining_seconds descending (earliest first in time)
        """
        announcements: List[Tuple[int, str]] = []
        processed_times: set = set()

        # Process each stage
        for stage in self.stages:
            if stage.duration_threshold == 0:
                # "Everything" stage: from total_seconds down to next stage threshold
                next_threshold = self._get_next_threshold(stage)
                start = total_seconds
                end = next_threshold
            else:
                # Specific stage: from threshold down to next stage threshold
                start = min(stage.duration_threshold, total_seconds)
                end = self._get_next_threshold(stage)

            # Generate announcements at interval within this stage
            current = start
            while current > end:
                # Round to nearest interval
                announcement_time = (
                    (current // stage.announcement_interval)
                    * stage.announcement_interval
                )

                if (
                    announcement_time > end
                    and announcement_time <= total_seconds
                    and announcement_time not in processed_times
                    and announcement_time > 0
                ):
                    text = stage.format_announcement(announcement_time)
                    announcements.append((announcement_time, text))
                    processed_times.add(announcement_time)

                current -= stage.announcement_interval

        # Sort by remaining seconds descending (earliest announcements first in time)
        announcements.sort(key=lambda x: x[0], reverse=True)
        return announcements

    def _get_next_threshold(self, current_stage: Stage) -> int:
        """
        Get the threshold of the next more urgent stage.

        See copilot_compliance in the root for code standards.

        Args:
            current_stage: The current stage

        Returns:
            Threshold of next stage, or 0 if none
        """
        found_current = False
        for stage in self.stages:
            if found_current:
                return stage.duration_threshold
            if stage.name == current_stage.name:
                found_current = True
        return 0

    def to_dict(self) -> List[dict]:
        """
        Convert stages to dictionary format for JSON serialization.

        See copilot_compliance in the root for code standards.

        Returns:
            List of stage dictionaries
        """
        return [
            {
                "name": stage.name,
                "duration_threshold": stage.duration_threshold,
                "announcement_interval": stage.announcement_interval,
                "verbosity": stage.verbosity,
            }
            for stage in self.stages
        ]

    @classmethod
    def from_dict(cls, data: List[dict]) -> "StageConfig":
        """
        Create StageConfig from dictionary format.

        See copilot_compliance in the root for code standards.

        Args:
            data: List of stage dictionaries

        Returns:
            StageConfig instance
        """
        stages = [
            Stage(
                name=item["name"],
                duration_threshold=item["duration_threshold"],
                announcement_interval=item["announcement_interval"],
                verbosity=item["verbosity"],
            )
            for item in data
        ]
        return cls(stages)
