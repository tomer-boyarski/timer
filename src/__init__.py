"""
Timer package with stage-based announcements and pre-generated audio.

See copilot_compliance in the root for code standards.
"""

from src.tts import speak_text, test_tts_availability
from src.time_utils import parse_time_string, format_time, format_time_announcement
from src.announcements import generate_announcement_intervals
from src.display import display_timer_info
from src.ui import launch_timer_ui
from src.stage import Stage, StageConfig
from src.config_manager import ConfigManager
from src.audio_generator import AudioGenerator, AudioPlayer

__all__ = [
    "launch_timer_ui",
    "speak_text",
    "test_tts_availability",
    "parse_time_string",
    "format_time",
    "format_time_announcement",
    "generate_announcement_intervals",
    "display_timer_info",
    "Stage",
    "StageConfig",
    "ConfigManager",
    "AudioGenerator",
    "AudioPlayer",
]
