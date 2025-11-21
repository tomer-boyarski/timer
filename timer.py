"""
Simple Customized Timer with Text-to-Speech Announcements.

A flexible timer that announces custom messages at exponential intervals using text-to-speech.

See copilot_compliance in the root for code standards.
"""

import time
import pyttsx3
import re
from typing import Union, List


def speak_with_pyttsx3(text: str, start_time: float, num_repetitions: int = 4) -> float:
    """
    Create fresh pyttsx3 engine for each call to avoid connection issues.

    See copilot_compliance in the root for code standards.

    Args:
        text: Text to be spoken
        start_time: Start time for duration calculation

    Returns:
        Time taken to speak
    """
    fresh_engine = pyttsx3.init()  # type: ignore

    voices = fresh_engine.getProperty("voices")  # type: ignore
    if voices and len(voices) > 1:  # type: ignore
        fresh_engine.setProperty("voice", voices[1].id)  # type: ignore

    fresh_engine.setProperty("rate", 180)  # type: ignore
    fresh_engine.setProperty("volume", 1.0)  # type: ignore

    # silence_prefix = ". " * 40
    # full_text = silence_prefix + text
    full_text = " ".join([text] * num_repetitions)
    fresh_engine.say(full_text)  # type: ignore
    fresh_engine.runAndWait()  # type: ignore

    try:
        fresh_engine.stop()  # type: ignore
        del fresh_engine
    except:
        pass

    speech_duration = time.time() - start_time
    time.sleep(0.1)
    return speech_duration


def speak_with_sapi(text: str, start_time: float) -> float:
    """
    Try Windows SAPI with proper cleanup.

    See copilot_compliance in the root for code standards.

    Args:
        text: Text to be spoken
        start_time: Start time for duration calculation

    Returns:
        Time taken to speak
    """
    import win32com.client

    speaker = win32com.client.Dispatch("SAPI.SpVoice")  # type: ignore

    voices = speaker.GetVoices()  # type: ignore
    if voices.Count > 1:  # type: ignore
        speaker.Voice = voices.Item(1)  # type: ignore

    speaker.Rate = 3
    speaker.Volume = 100

    silence_prefix = ". " * 20
    full_text = silence_prefix + text

    speaker.Speak(full_text, 0)  # type: ignore

    speaker = None
    speech_duration = time.time() - start_time
    time.sleep(0.1)
    return speech_duration


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


def speak_text(text: str) -> float:
    """
    Use text-to-speech to announce the given text with proper engine management.

    See copilot_compliance in the root for code standards.

    Args:
        text: Text to be spoken

    Returns:
        Time taken to speak
    """
    start_time = time.time()
    print()
    print(f" SPEAKING: {text}")
    print("-" * 60)

    try:
        return speak_with_pyttsx3(text, start_time)
    except Exception as e:
        print(f"  Fresh pyttsx3 failed: {e}")

    try:
        return speak_with_sapi(text, start_time)
    except ImportError:
        print("  win32com not available")
    except Exception as e:
        print(f"  SAPI failed: {e}")

    print(f"  All TTS methods failed for: {text}")
    return time.time() - start_time


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


def test_tts_availability() -> None:
    """
    Test text-to-speech availability and display results.

    See copilot_compliance in the root for code standards.
    """
    print()
    print(" TEXT-TO-SPEECH STATUS")
    print("-" * 60)
    try:
        test_engine = pyttsx3.init()  # type: ignore
        voices = test_engine.getProperty("voices")  # type: ignore
        if voices:  # type: ignore
            print(f" Found {len(voices)} TTS voices available")  # type: ignore
        else:
            print(" No TTS voices found")
        test_engine.stop()  # type: ignore
        del test_engine
    except Exception as e:
        print(f" TTS test failed: {e}")
    print("-" * 60)


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


def timer(
    total_duration: Union[str, int, float],
    shortest_interval: Union[str, int, float] = "15s",
    multiplier: Union[int, float] = 2,
    offset: float = 2.5,
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
    speak_text(" ".join(["Finished"] * 2))


def main() -> None:
    """
    Main function to run the default timer.

    See copilot_compliance in the root for code standards.
    """
    # timer("6m55s")
    timer("5s", shortest_interval="5s", multiplier=2, offset=2.5)


if __name__ == "__main__":
    main()
