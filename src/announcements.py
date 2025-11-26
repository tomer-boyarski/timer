"""
Announcement generation and management logic.

See copilot_compliance in the root for code standards.

NOTE: This module contains legacy exponential interval generation.
The new stage-based announcement system is in src/stage.py.
This file is kept for backwards compatibility but may be removed in future.
"""

from typing import Union, List
from src.time_utils import parse_time_string


def generate_announcement_intervals(
    total_seconds: int,
    shortest_interval: Union[str, int, float],
    multiplier: Union[int, float],
) -> List[int]:
    """
    Generate exponential announcement intervals (LEGACY).

    See copilot_compliance in the root for code standards.

    NOTE: This function is deprecated. Use StageConfig from src/stage.py instead.

    Args:
        total_seconds: Total timer duration in seconds
        shortest_interval: Shortest interval for announcements
        multiplier: Multiplier for exponential growth

    Returns:
        List of announcement times in seconds, sorted descending
    """
    shortest_seconds = parse_time_string(shortest_interval)

    if total_seconds < shortest_seconds:
        return []

    intervals = []
    current = shortest_seconds

    while current < total_seconds:
        intervals.append(current)  # type: ignore
        current = int(current * multiplier)

    return sorted(intervals, reverse=True)  # type: ignore
