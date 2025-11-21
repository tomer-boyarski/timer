"""
Time parsing and formatting utilities.

See copilot_compliance in the root for code standards.
"""

import re
from typing import Union


def parse_time_string(time_str: Union[str, int, float]) -> int:
    """
    Parse user-friendly time strings into seconds.

    See copilot_compliance in the root for code standards.

    Examples:
        "4m" -> 240 seconds
        "30s" -> 30 seconds
        "2m30s" -> 150 seconds
        "1h30m" -> 5400 seconds

    Args:
        time_str: Time string like "4m", "30s", "2m30s"

    Returns:
        Time in seconds
    """
    if isinstance(time_str, (int, float)):
        return int(time_str)

    time_str = str(time_str).replace(" ", "").lower()

    total_seconds = 0

    hours_match = re.search(r"(\d+)h", time_str)
    if hours_match:
        total_seconds += int(hours_match.group(1)) * 3600

    minutes_match = re.search(r"(\d+)m", time_str)
    if minutes_match:
        total_seconds += int(minutes_match.group(1)) * 60

    seconds_match = re.search(r"(\d+)s", time_str)
    if seconds_match:
        total_seconds += int(seconds_match.group(1))

    if total_seconds == 0:
        try:
            total_seconds = int(time_str)
        except ValueError:
            raise ValueError(f"Invalid time format: {time_str}")

    return total_seconds


def format_time(seconds: Union[int, float]) -> str:
    """
    Format seconds into MM:SS format.

    See copilot_compliance in the root for code standards.

    Args:
        seconds: Number of seconds

    Returns:
        Formatted time string
    """
    minutes = int(seconds) // 60
    secs = int(seconds) % 60
    return f"{minutes:02d}:{secs:02d}"


def format_time_announcement(seconds: Union[int, float]) -> str:
    """
    Format seconds into a human-readable announcement string.

    See copilot_compliance in the root for code standards.

    Args:
        seconds: Number of seconds

    Returns:
        Formatted announcement string like "2 minutes" or "30 seconds"
    """
    total_seconds = int(seconds)

    if total_seconds >= 60:
        minutes = total_seconds // 60
        leftover_seconds = total_seconds % 60

        if leftover_seconds == 0:
            minute_word = "minute" if minutes == 1 else "minutes"
            return f"{minutes} {minute_word}"
        else:
            minute_word = "minute" if minutes == 1 else "minutes"
            second_word = "second" if leftover_seconds == 1 else "seconds"
            return f"{minutes} {minute_word} {leftover_seconds} {second_word}"
    else:
        second_word = "second" if total_seconds == 1 else "seconds"
        return f"{total_seconds} {second_word}"
