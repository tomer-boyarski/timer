"""
Display and UI output functions for the timer.

See copilot_compliance in the root for code standards.
"""

from typing import Union, List
from src.time_utils import parse_time_string, format_time, format_time_announcement


def display_timer_info(
    total_seconds: int,
    announcement_intervals: List[int],
    shortest_interval: Union[str, int, float],
    multiplier: Union[int, float],
    offset: float,
) -> None:
    """
    Display timer initialization information.

    See copilot_compliance in the root for code standards.

    Args:
        total_seconds: Total timer duration in seconds
        announcement_intervals: List of announcement intervals in seconds
        shortest_interval: Shortest interval for announcements
        multiplier: Multiplier for exponential growth
        offset: Offset in seconds for early announcement
    """
    print("\n" + "=" * 60)
    print(" TIMER SETUP")
    print("=" * 60)
    print(f" Duration: {format_time(total_seconds)} ({total_seconds} seconds)")
    print(f" Shortest interval: {shortest_interval}")
    print(f" Multiplier: {multiplier}")
    print(f" Offset: {offset}s")
    print()

    if announcement_intervals:
        print(" Announcements scheduled:")
        for interval in announcement_intervals:
            announcement_text = format_time_announcement(interval)
            trigger_time = interval + offset
            print(f'   {format_time(trigger_time)} - "{announcement_text}"')
    elif total_seconds < parse_time_string(shortest_interval):
        announcement_text = format_time_announcement(total_seconds)
        trigger_time = offset
        print(" Single announcement at start:")
        print(f'   {format_time(trigger_time)} - "{announcement_text}"')
    else:
        print(" No announcements scheduled")

    print("=" * 60)
