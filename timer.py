"""
Simple Customized Timer with Text-to-Speech Announcements
========================================================

A flexible timer that announces custom messages at specified intervals using text-to-speech.

Total timer duration and announcements are configurable.
"""

import time
import pyttsx3
import winsound  # Windows built-in sound support
import re


def speak_with_pyttsx3(text, start_time):
    """
    Method 1: Create fresh pyttsx3 engine for each call to avoid connection issues.

    Args:
        text (str): Text to be spoken
        start_time (float): Start time for duration calculation

    Returns:
        float: Time taken to speak
    """
    # Create a new engine instance for each call
    fresh_engine = pyttsx3.init()

    # Configure the fresh engine
    voices = fresh_engine.getProperty("voices")
    if voices and len(voices) > 1:
        # Use Zira (female voice) if available
        fresh_engine.setProperty("voice", voices[1].id)

    # Set standard speech settings
    fresh_engine.setProperty(
        "rate", 180
    )  # Faster speech: default ~200, range usually 50-400
    fresh_engine.setProperty("volume", 1.0)  # Maximum volume: range 0.0 to 1.0

    # Add pauses for better pronunciation
    enhanced_text = text
    if text.isdigit():
        enhanced_text = f". {text} ."
    elif "minutes" in text or "seconds" in text:
        enhanced_text = text.replace(" left", ", left")

    # Speak and wait for completion
    fresh_engine.say(enhanced_text)
    fresh_engine.runAndWait()

    # Properly cleanup the engine
    try:
        fresh_engine.stop()
        del fresh_engine
    except:
        pass

    speech_duration = time.time() - start_time
    time.sleep(0.1)  # Brief pause after speech
    return speech_duration


def speak_with_sapi(text, start_time):
    """
    Method 2: Try Windows SAPI with proper cleanup.

    Args:
        text (str): Text to be spoken
        start_time (float): Start time for duration calculation

    Returns:
        float: Time taken to speak
    """
    import win32com.client

    speaker = win32com.client.Dispatch("SAPI.SpVoice")

    # Configure voice
    voices = speaker.GetVoices()
    if voices.Count > 1:
        speaker.Voice = voices.Item(1)  # Use Zira

    # Set standard speech settings
    speaker.Rate = (
        3  # Faster speech: range -10 to +10 (0 = normal, +3 = noticeably faster)
    )
    speaker.Volume = 100  # Maximum volume: range 0 to 100

    # Synchronous speech with proper cleanup
    speaker.Speak(text, 0)  # 0 = synchronous (wait for completion)

    # Cleanup
    speaker = None
    speech_duration = time.time() - start_time
    time.sleep(0.1)
    return speech_duration


def parse_time_string(time_str):
    """
    Parse user-friendly time strings into seconds.

    Examples:
        "4m" -> 240 seconds
        "30s" -> 30 seconds
        "2m30s" -> 150 seconds
        "1h30m" -> 5400 seconds

    Args:
        time_str (str): Time string like "4m", "30s", "2m30s"

    Returns:
        int: Time in seconds
    """
    if isinstance(time_str, (int, float)):
        return int(time_str)  # Already in seconds

    # Remove spaces and convert to lowercase
    time_str = time_str.replace(" ", "").lower()

    # Parse hours, minutes, seconds
    total_seconds = 0

    # Find hours
    hours_match = re.search(r"(\d+)h", time_str)
    if hours_match:
        total_seconds += int(hours_match.group(1)) * 3600

    # Find minutes
    minutes_match = re.search(r"(\d+)m", time_str)
    if minutes_match:
        total_seconds += int(minutes_match.group(1)) * 60

    # Find seconds
    seconds_match = re.search(r"(\d+)s", time_str)
    if seconds_match:
        total_seconds += int(seconds_match.group(1))

    # If no units found, assume it's seconds
    if total_seconds == 0:
        try:
            total_seconds = int(time_str)
        except ValueError:
            raise ValueError(f"Invalid time format: {time_str}")

    return total_seconds


def speak_text(text):
    """
    Use text-to-speech to announce the given text with proper engine management.

    Args:
        text (str): Text to be spoken

    Returns:
        float: Time taken to speak (for timing adjustments)
    """
    start_time = time.time()
    print()
    print(f" SPEAKING: {text}")
    print("-" * 60)

    # Method 1: Create fresh pyttsx3 engine for each call to avoid connection issues
    try:
        return speak_with_pyttsx3(text, start_time)
    except Exception as e:
        print(f"  Fresh pyttsx3 failed: {e}")

    # Method 2: Try Windows SAPI with proper cleanup
    try:
        return speak_with_sapi(text, start_time)
    except ImportError:
        print("  win32com not available")
    except Exception as e:
        print(f"  SAPI failed: {e}")

    # All TTS methods failed
    print(f"  All TTS methods failed for: {text}")
    return time.time() - start_time


def play_beep_sound():
    """
    Play a beep sound using Windows built-in sound.
    """
    winsound.Beep(1000, 200)  # Frequency: 1000Hz, Duration: 200ms (shorter beep)
    print("    BEEP!")


def make_audio_announcement(announcement_type, content=None):
    """
    Unified audio output function for both speech and beep announcements.

    Args:
        announcement_type (str): "speech" or "beep"
        content (str, optional): Text to speak (for speech type) or countdown number (for beep type)
    """
    if announcement_type == "speech":
        speak_text(content)
    elif announcement_type == "beep":
        print(f"    {content}")
        play_beep_sound()


def format_time(seconds):
    """
    Format seconds into MM:SS format.

    Args:
        seconds (int): Number of seconds

    Returns:
        str: Formatted time string
    """
    minutes = int(seconds) // 60
    seconds = int(seconds) % 60
    return f"{minutes:02d}:{seconds:02d}"


def test_tts_availability():
    """
    Test text-to-speech availability and display results.
    """
    print()
    print(" TEXT-TO-SPEECH STATUS")
    print("-" * 60)
    try:
        test_engine = pyttsx3.init()
        voices = test_engine.getProperty("voices")
        if voices:
            print(f" Found {len(voices)} TTS voices available")
        else:
            print(" No TTS voices found")
        test_engine.stop()
        del test_engine
    except Exception as e:
        print(f" TTS test failed: {e}")
    print("-" * 60)


def display_timer_info(total_seconds, parsed_announcements, final_countdown_from):
    """
    Display timer initialization information.

    Args:
        total_seconds (int): Total timer duration in seconds
        parsed_announcements (dict): Dictionary of announcements
        final_countdown_from (int): Final countdown start number
    """
    print("\n" + "=" * 60)
    print(f" TIMER SETUP")
    print("=" * 60)
    print(f" Duration: {format_time(total_seconds)} ({total_seconds} seconds)")
    print()
    print(" Announcements scheduled:")
    for seconds, text in sorted(parsed_announcements.items(), reverse=True):
        print(f'   {format_time(seconds)} - "{text}"')
    print()
    print(f" Final countdown from: {final_countdown_from}")
    print("=" * 60)


def start_timer_announcement(total_seconds):
    """
    Display timer start message and announce it via TTS.

    Args:
        total_seconds (int): Total timer duration in seconds
    """
    print()
    print(f" STARTING {format_time(total_seconds)} TIMER")
    print("=" * 60)


def parse_announcements(announcements):
    """
    Parse announcement times and convert them to seconds.

    Args:
        announcements (dict): Dictionary of announcements where values are time strings

    Returns:
        dict: Dictionary with time in seconds as keys and text as values
    """
    # Parse announcement times and sort them
    parsed_announcements = {}
    for text, when in announcements.items():
        when_seconds = parse_time_string(when)
        parsed_announcements[when_seconds] = text
    return parsed_announcements


def initialize_timer(total_duration, announcements, final_countdown_from):
    """
    Initialize timer by parsing duration, announcements, and setting up displays.

    Args:
        total_duration (str or int): Total timer duration
        announcements (dict): Dictionary of announcements
        final_countdown_from (int): Final countdown start number

    Returns:
        tuple: (total_seconds, parsed_announcements, announced, start_time)
    """
    # Parse total duration
    total_seconds = parse_time_string(total_duration)

    # Parse announcement times
    parsed_announcements = parse_announcements(announcements)

    # Track which announcements have been made
    announced = {seconds: False for seconds in parsed_announcements.keys()}

    display_timer_info(total_seconds, parsed_announcements, final_countdown_from)

    test_tts_availability()

    start_timer_announcement(total_seconds)

    # Record start time for accurate timing
    start_time = time.time()

    return total_seconds, parsed_announcements, announced, start_time


def timer(total_duration, announcements, final_countdown_from=10):
    """
    Run a customizable timer with text-to-speech announcements.

    Args:
        total_duration (str or int): Total timer duration (e.g., "6m", "30s", "2m30s", or 360)
        announcements (dict): Dictionary of announcements where:
                             - keys are the text to speak (e.g., "4 minutes left")
                             - values are when to speak them (e.g., "4m", "30s", 240)
        final_countdown_from (int): Start final countdown from this number (default: 10)

    Example:
        timer("6m", {
            "4 minutes left": "4m",
            "2 minutes left": "2m",
            "1 minute left": "1m",
            "30 seconds left": "30s",
            "20 seconds left": "20s"
        })
    """
    # Initialize timer and get all necessary variables
    total_seconds, parsed_announcements, announced, start_time = initialize_timer(
        total_duration, announcements, final_countdown_from
    )

    # Track if we've entered final countdown phase and last beep number
    final_countdown_started = False
    last_beep_number = None

    while True:
        # Calculate actual elapsed time
        elapsed_time = time.time() - start_time
        remaining_seconds = max(0, total_seconds - elapsed_time)

        # Check if timer is completely finished
        if remaining_seconds <= 0:
            break

        # Display current time (unified for both phases)
        print(
            f" Time remaining: {format_time(remaining_seconds)} ({remaining_seconds:.1f}s)",
            end="\r",
        )

        # Check if we've entered the final countdown phase
        if remaining_seconds <= final_countdown_from and not final_countdown_started:
            final_countdown_started = True
            if final_countdown_from > 0:
                print()
                print()
                print(" FINAL COUNTDOWN")
                print("=" * 60)

        # Determine which phase we're in and make appropriate announcements
        if final_countdown_started:
            # Final countdown phase - use beeps
            countdown_number = int(remaining_seconds) + 1
            if countdown_number <= final_countdown_from and countdown_number > 0:
                # Only beep once per countdown number
                if countdown_number != last_beep_number:
                    make_audio_announcement("beep", countdown_number)
                    last_beep_number = countdown_number
        else:
            # Regular timer phase - check for speech announcements
            for threshold_seconds, text in parsed_announcements.items():
                if (
                    not announced[threshold_seconds]
                    and remaining_seconds <= threshold_seconds
                ):
                    make_audio_announcement("speech", text)
                    announced[threshold_seconds] = True

        # Small sleep to avoid busy waiting (unified timing)
        time.sleep(0.1)

    # Timer finished
    print()
    print("=" * 60)
    print(" TIMER COMPLETED!")
    print("=" * 60)
    speak_text("Finished")


def main():
    """
    Main function to run the default 30-second timer.
    """
    # default_announcements_6_minutes = {
    #     "4 minutes left": "4m",
    #     "2 minutes left": "2m",
    #     "1 minute left": "1m",
    #     "30 seconds left": "30s",
    #     "20 seconds left": "20s"
    # }

    default_announcements_25_s = {"20 seconds remaining": "20s"}
    timer("25s", default_announcements_25_s, final_countdown_from=10)


if __name__ == "__main__":
    main()
