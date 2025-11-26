"""
Script to calibrate TTS speech rate for final countdown.

See copilot_compliance in the root for code standards.

This script tests different speech rates to find the optimal speed
for the final countdown (10, 9, 8, ...) where each word must take
less than 1 second to speak.
"""

import pyttsx3
import time
import wave
import io
import os
import tempfile
from typing import List, Tuple


def measure_speech_duration(text: str, rate: int) -> float:
    """
    Measure how long it takes to speak text at given rate.

    See copilot_compliance in the root for code standards.

    Args:
        text: Text to speak
        rate: Speech rate (words per minute)

    Returns:
        Duration in seconds
    """
    engine = pyttsx3.init()  # type: ignore
    engine.setProperty("rate", rate)  # type: ignore

    start = time.time()
    engine.say(text)  # type: ignore
    engine.runAndWait()  # type: ignore
    duration = time.time() - start

    try:
        engine.stop()  # type: ignore
        del engine
    except:
        pass

    return duration


def test_countdown_rates(rates: List[int]) -> List[Tuple[int, dict]]:
    """
    Test various speech rates for countdown numbers.

    See copilot_compliance in the root for code standards.

    Args:
        rates: List of speech rates to test

    Returns:
        List of (rate, results_dict) tuples
    """
    countdown_words = ["10", "9", "8", "7", "6", "5", "4", "3", "2", "1"]
    results = []

    for rate in rates:
        print(f"\nTesting rate: {rate}")
        print("-" * 40)

        durations = {}
        max_duration = 0

        for word in countdown_words:
            duration = measure_speech_duration(word, rate)
            durations[word] = duration
            max_duration = max(max_duration, duration)
            status = "✓" if duration < 1.0 else "✗"
            print(f"  '{word}': {duration:.3f}s {status}")

            # Small delay between tests
            time.sleep(0.2)

        avg_duration = sum(durations.values()) / len(durations)
        all_under_one = all(d < 1.0 for d in durations.values())

        print(f"\n  Average: {avg_duration:.3f}s")
        print(f"  Max: {max_duration:.3f}s")
        print(f"  All under 1s: {'Yes ✓' if all_under_one else 'No ✗'}")

        results.append(
            (
                rate,
                {
                    "durations": durations,
                    "avg": avg_duration,
                    "max": max_duration,
                    "all_under_one": all_under_one,
                },
            )
        )

    return results


def test_phrase_durations(rate: int) -> None:
    """
    Test durations for full announcement phrases.

    See copilot_compliance in the root for code standards.

    Args:
        rate: Speech rate to test
    """
    phrases = [
        "50 seconds remaining",
        "40 seconds remaining",
        "30 seconds remaining",
        "20 seconds remaining",
        "1 minute remaining",
        "2 minutes remaining",
        "5 minutes remaining",
        "Finished",
    ]

    print(f"\nTesting phrases at rate {rate}")
    print("-" * 50)

    for phrase in phrases:
        duration = measure_speech_duration(phrase, rate)
        print(f"  '{phrase}': {duration:.3f}s")
        time.sleep(0.2)


def find_optimal_rate() -> int:
    """
    Find the optimal speech rate for countdown.

    See copilot_compliance in the root for code standards.

    Returns:
        Optimal rate where all countdown words take <1 second
    """
    # Test rates from 200 to 350
    rates = [200, 220, 240, 260, 280, 300, 320, 350]
    results = test_countdown_rates(rates)

    # Find minimum rate where all words are under 1 second
    valid_rates = [(r, d) for r, d in results if d["all_under_one"]]

    if valid_rates:
        optimal = min(valid_rates, key=lambda x: x[0])
        print(f"\n{'='*50}")
        print(f"OPTIMAL RATE: {optimal[0]}")
        print(f"Max duration: {optimal[1]['max']:.3f}s")
        print(f"{'='*50}")
        return optimal[0]
    else:
        print("\nWarning: No rate found where all words are under 1 second")
        # Return highest tested rate
        return rates[-1]


if __name__ == "__main__":
    print("TTS Speech Rate Calibration")
    print("=" * 50)

    # Find optimal rate for countdown
    optimal_rate = find_optimal_rate()

    # Also test standard rate for regular announcements
    print("\n\nTesting standard phrases at normal rate (180):")
    test_phrase_durations(180)

    print(f"\n\nRecommended settings:")
    print(f"  tts_rate_normal: 180")
    print(f"  tts_rate_countdown: {optimal_rate}")
