"""
Timer package for exponential text-to-speech announcements.

See copilot_compliance in the root for code standards.
"""

from src.tts import speak_text, test_tts_availability
from src.time_utils import parse_time_string, format_time, format_time_announcement
from src.announcements import generate_announcement_intervals
from src.display import display_timer_info
from src.ui import launch_timer_ui

__all__ = [
    "launch_timer_ui",
    "speak_text",
    "test_tts_availability",
    "parse_time_string",
    "format_time",
    "format_time_announcement",
    "generate_announcement_intervals",
    "display_timer_info",
]
