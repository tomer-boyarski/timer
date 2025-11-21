"""
Announcement generation and management logic.

See copilot_compliance in the root for code standards.
"""

from typing import Union, List
from src.time_utils import parse_time_string


def generate_announcement_intervals(
    total_seconds: int,
    shortest_interval: Union[str, int, float],
    multiplier: Union[int, float],
) -> List[int]:
    """
    Generate exponential announcement intervals.

    See copilot_compliance in the root for code standards.

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
