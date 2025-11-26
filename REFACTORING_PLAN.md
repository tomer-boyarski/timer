# Timer Application Refactoring Plan

## Overview

Major refactoring to solve the hardware speaker delay issue by pre-generating a complete audio file for the entire timer duration. The audio and visual components will be decoupled, with the audio file sent to speakers before the visual timer starts.

## Key Changes

### 1. Pre-generated Audio File System
- Create a complete WAV audio file with all announcements embedded at correct timestamps
- Audio file duration = prep timer + main timer duration
- Silence between announcements
- Send audio file to speakers, then start visual timer
- Configurable offset between audio playback start and timer start (default: 0)

### 2. Stage-based Announcement System
Replace exponential intervals with a three-stage system:

| Stage | Duration Threshold | Interval | Verbosity |
|-------|-------------------|----------|-----------|
| Final Countdown | Last 10 seconds | Every 1 second | Low (just numbers: "10", "9", etc.) |
| One Minute | Last 60 seconds | Every 10 seconds | High ("50 seconds remaining") |
| Everything Else | > 60 seconds | Every 60 seconds | High ("7 minutes remaining") |

- Each stage has: duration, announcement_interval, verbosity (low/high)
- Low verbosity: just the number ("10", "9", etc.)
- High verbosity: full phrase ("X minutes/seconds remaining")
- TTS speech rate must ensure numbers take <1 second to speak

### 3. Configuration System
- New `config/` directory for all configuration files
- `config/settings.json`: Timer durations, audio offset, stage configurations
- `config/announcements.csv`: Optional CSV-based announcement override
- Settings saved when user clicks START
- Last used values become new defaults

### 4. New GUI Configuration Screen
Layout:
```
+------------------------------------------+
|  PREP TIMER          |    MAIN TIMER     |
|  Duration: [__:__]   |  Duration: [__:__]|
+------------------------------------------+
|           ANNOUNCEMENT CONFIGURATION      |
+------------------------------------------+
| Stage      | Duration | Interval | Verbosity |
|------------|----------|----------|-----------|
| Countdown  | 0:10     | 0:01     | [Low  v]  |
| One Minute | 1:00     | 0:10     | [High v]  |
| Everything | (rest)   | 1:00     | [High v]  |
+------------------------------------------+
|              [ START ]                    |
+------------------------------------------+
```

### 5. Audio Generation
- Use pyttsx3 to generate speech audio segments
- Use wave module to create WAV file with silence
- Calculate exact byte positions for each announcement
- Speech rate configurable for final countdown (must be fast)

## Implementation Phases (Git Branches)

### Phase 1: `feature/stage-model` ✅ COMPLETE
- Create `Stage` dataclass with duration, interval, verbosity
- Create `StageConfig` class to manage stage-based announcements
- Create `AnnouncementGenerator` to produce list of (timestamp, text) tuples
- Unit tests for stage logic

### Phase 2: `feature/audio-generation` ✅ COMPLETE
- Create `AudioGenerator` class
- Generate TTS audio segments with pyttsx3
- Compose WAV file with silence and speech at correct timestamps
- Script to test/calibrate TTS speech rate for final countdown
- Save audio to temp file

### Phase 3: `feature/config-system` ✅ COMPLETE
- Create `config/` directory structure
- Create `ConfigManager` class for JSON read/write
- Default settings with stage configurations
- CSV announcement file support (optional override)

### Phase 4: `feature/config-ui` ✅ COMPLETE
- Redesign `TimerWindow` start screen to configuration screen
- Two columns: prep timer (left), main timer (right)
- Duration inputs in MM:SS format
- Stage configuration table with dropdowns
- Save settings on START click

### Phase 5: `feature/audio-visual-sync` ✅ COMPLETE
- Integrate audio playback with timer display
- Start audio file, then start visual timer after offset
- Remove real-time TTS calls during timer
- Handle audio completion

### Phase 6: `feature/cleanup` ✅ COMPLETE
- Remove old exponential announcement code
- Update documentation
- Final testing
- Merge to main

## New File Structure

```
timer/
├── config/
│   ├── settings.json          # User settings (durations, stages)
│   └── announcements.csv      # Optional CSV announcements
├── src/
│   ├── __init__.py
│   ├── __main__.py
│   ├── announcements.py       # Updated for stage-based
│   ├── audio_generator.py     # NEW: WAV file generation
│   ├── config_manager.py      # NEW: Settings management
│   ├── display.py
│   ├── stage.py               # NEW: Stage dataclass
│   ├── time_utils.py
│   ├── tts.py                 # Updated for audio generation
│   └── ui.py                  # Updated for config screen
├── scripts/
│   └── calibrate_tts_speed.py # NEW: Test TTS speech rates
├── REFACTORING_PLAN.md
└── ...
```

## New Classes

### Stage (dataclass)
```python
@dataclass
class Stage:
    name: str                    # "countdown", "one_minute", "everything"
    duration_threshold: int      # Seconds threshold (10, 60, or 0 for "rest")
    announcement_interval: int   # Seconds between announcements
    verbosity: str               # "low" or "high"
```

### StageConfig
```python
class StageConfig:
    stages: List[Stage]
    
    def get_announcements(self, total_seconds: int) -> List[Tuple[int, str]]:
        """Generate list of (remaining_seconds, text) announcements."""
```

### AudioGenerator
```python
class AudioGenerator:
    def generate_audio_file(
        self, 
        prep_duration: int,
        main_duration: int,
        prep_stages: StageConfig,
        main_stages: StageConfig,
        output_path: str
    ) -> str:
        """Generate complete WAV file with all announcements."""
```

### ConfigManager
```python
class ConfigManager:
    def load_settings(self) -> dict:
        """Load settings from config/settings.json."""
    
    def save_settings(self, settings: dict) -> None:
        """Save settings to config/settings.json."""
    
    def load_csv_announcements(self, path: str) -> List[Tuple[int, str]]:
        """Load announcements from CSV file."""
```

## Implementation Order

1. Create `config/` directory and `settings.json` with defaults
2. Create `Stage` dataclass in `src/stage.py`
3. Create `StageConfig` class for announcement generation
4. Create TTS calibration script
5. Create `AudioGenerator` class
6. Create `ConfigManager` class
7. Update UI with configuration screen
8. Integrate audio playback with timer
9. Clean up and merge

## Default Configuration Values

```json
{
    "prep_duration": "20s",
    "main_duration": "6m55s",
    "audio_offset": 1,
    "stages": [
        {
            "name": "countdown",
            "duration_threshold": 10,
            "announcement_interval": 1,
            "verbosity": "low"
        },
        {
            "name": "one_minute",
            "duration_threshold": 60,
            "announcement_interval": 10,
            "verbosity": "high"
        },
        {
            "name": "everything",
            "duration_threshold": 0,
            "announcement_interval": 60,
            "verbosity": "high"
        }
    ],
    "tts_rate_normal": 180,
    "tts_rate_countdown": 250
}
```

## Announcement Text Format

- High verbosity: "{X} minutes remaining" or "{X} seconds remaining"
- Low verbosity: "{X}" (just the number)
- "Finished" announcement at end of main timer

## Audio File Format

- WAV format (uncompressed for simplicity)
- Sample rate: 22050 Hz
- Channels: 1 (mono)
- Bit depth: 16-bit
