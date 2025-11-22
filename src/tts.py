"""
Text-to-speech functionality for timer announcements.

See copilot_compliance in the root for code standards.
"""

import time
import pyttsx3


def speak_with_pyttsx3(text: str, start_time: float, num_repetitions: int = 4) -> float:
    """
    Create fresh pyttsx3 engine for each call to avoid connection issues.

    See copilot_compliance in the root for code standards.

    Args:
        text: Text to be spoken
        start_time: Start time for duration calculation
        num_repetitions: Number of times to repeat text (default: 4)

    Returns:
        Time taken to speak
    """
    fresh_engine = pyttsx3.init()  # type: ignore

    voices = fresh_engine.getProperty("voices")  # type: ignore
    if voices and len(voices) > 1:  # type: ignore
        fresh_engine.setProperty("voice", voices[1].id)  # type: ignore

    fresh_engine.setProperty("rate", 180)  # type: ignore
    fresh_engine.setProperty("volume", 1.0)  # type: ignore

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


def speak_text(text: str, num_repetitions: int = 1) -> float:
    """
    Use text-to-speech to announce the given text with proper engine management.

    See copilot_compliance in the root for code standards.

    Args:
        text: Text to be spoken
        num_repetitions: Number of times to repeat text (default: 1)

    Returns:
        Time taken to speak
    """
    start_time = time.time()
    print()
    print(f" SPEAKING: {text}")
    print("-" * 60)

    try:
        return speak_with_pyttsx3(text, start_time, num_repetitions)
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
