"""
Main entry point for the timer application.

See copilot_compliance in the root for code standards.
"""

import time
from typing import Union

from src.tts import speak_text, test_tts_availability
from src.time_utils import parse_time_string, format_time, format_time_announcement
from src.announcements import generate_announcement_intervals
from src.display import display_timer_info


def timer(
    total_duration: Union[str, int, float],
    shortest_interval: Union[str, int, float] = "15s",
    multiplier: Union[int, float] = 2,
    offset: float = 1,
    num_repetitions: int = 4,
) -> None:
    """
    Run a customizable timer with exponential text-to-speech announcements.

    See copilot_compliance in the root for code standards.

    Args:
        total_duration: Total timer duration (e.g., "6m55s", "30s", or 360)
        shortest_interval: Shortest announcement interval (default: "15s")
        multiplier: Exponential multiplier for intervals (default: 2)
        offset: Seconds to announce early (default: 2.5, includes 2s silence prefix)
        num_repetitions: Number of times to repeat announcements (default: 4)

    Example:
        timer("6m55s")
        timer("10m", shortest_interval="30s", multiplier=3, offset=1.0)
    """
    total_seconds = parse_time_string(total_duration)
    shortest_seconds = parse_time_string(shortest_interval)

    announcement_intervals = generate_announcement_intervals(
        total_seconds, shortest_interval, multiplier
    )

    announced = {interval: False for interval in announcement_intervals}

    display_timer_info(
        total_seconds, announcement_intervals, shortest_interval, multiplier, offset
    )

    test_tts_availability()

    print()
    print(f" STARTING {format_time(total_seconds)} TIMER")
    print("=" * 60)

    start_time = time.time()

    short_timer_announced = False

    while True:
        elapsed_time = time.time() - start_time
        remaining_seconds = max(0, total_seconds - elapsed_time)

        if remaining_seconds <= 0:
            break

        print(
            f" Time remaining: {format_time(remaining_seconds)} ({remaining_seconds:.1f}s)",
            end="\r",
        )

        if total_seconds < shortest_seconds and not short_timer_announced:
            if elapsed_time >= offset:
                announcement_text = format_time_announcement(total_seconds)
                speak_text(announcement_text)
                short_timer_announced = True
        else:
            for interval in announcement_intervals:
                trigger_time = interval + offset
                if not announced[interval] and remaining_seconds <= trigger_time:
                    announcement_text = format_time_announcement(interval)
                    speak_text(announcement_text)
                    announced[interval] = True

        time.sleep(0.1)

    print()
    print("=" * 60)
    print(" TIMER COMPLETED!")
    print("=" * 60)
    speak_text("Finished")


def main() -> None:
    """
    Main function to run the default timer.

    See copilot_compliance in the root for code standards.
    """
    # timer("6m55s")
    timer("25s", shortest_interval="15s", multiplier=2)


if __name__ == "__main__":
    main()
