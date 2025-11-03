# Simple Customized Timer with Text-to-Speech Announcements

A flexible Windows timer that announces custom messages at specified intervals using text-to-speech and provides audio countdown beeps.

## Features

- ✅ **Customizable Duration**: Support for human-friendly time formats (`4m`, `30s`, `2m30s`, `1h30m`)
- ✅ **Text-to-Speech Announcements**: Configurable voice announcements at specific intervals
- ✅ **Audio Countdown**: Beep-based final countdown with visual display
- ✅ **Dual TTS Support**: Fallback between pyttsx3 and Windows SAPI for reliability
- ✅ **Unified Timer Logic**: Single loop architecture with consistent timing
- ✅ **Real-time Display**: Live countdown display with MM:SS format
- ✅ **Voice Optimization**: Fast speech rate and maximum volume for clarity

## Requirements

- **Python 3.6+**
- **Windows OS** (uses Windows-specific audio APIs)
- **Dependencies**: See `requirements.txt`

## Installation

1. Clone or download this repository
2. Install dependencies:
```bash
pip install -r requirements.txt
```

## Usage

### Basic Usage

Run the default 25-second timer:
```bash
python timer.py
```

### Custom Timer Examples

```python
from timer import timer

# 6-minute timer with multiple announcements
timer("6m", {
    "4 minutes left": "4m",
    "2 minutes left": "2m", 
    "1 minute left": "1m",
    "30 seconds left": "30s",
    "20 seconds left": "20s"
}, final_countdown_from=10)

# 30-second timer with simple announcement
timer("30s", {
    "20 seconds remaining": "20s"
}, final_countdown_from=5)

# 1 hour timer
timer("1h", {
    "30 minutes left": "30m",
    "10 minutes left": "10m",
    "5 minutes left": "5m"
})
```

### Time Format Examples

| Format | Duration |
|--------|----------|
| `"30s"` | 30 seconds |
| `"4m"` | 4 minutes |
| `"2m30s"` | 2 minutes 30 seconds |
| `"1h30m"` | 1 hour 30 minutes |
| `300` | 300 seconds (integer) |

## Configuration

### Audio Settings

The timer automatically configures optimal audio settings:

**Text-to-Speech:**
- pyttsx3: 180 WPM, maximum volume
- Windows SAPI: Rate +3, volume 100

**Beep Sounds:**
- Frequency: 1000Hz
- Duration: 200ms (short, crisp beeps)

### Timer Parameters

```python
timer(total_duration, announcements, final_countdown_from=10)
```

- **`total_duration`**: Timer duration (string format like "6m" or integer seconds)
- **`announcements`**: Dictionary mapping announcement text to trigger times
- **`final_countdown_from`**: Number to start final countdown from (default: 10)

## Architecture

The timer uses a unified single-loop architecture:

1. **Initialization Phase**: Parse settings, display timer info, test TTS
2. **Main Timer Loop**: 
   - Regular phase: Text announcements at specified intervals
   - Countdown phase: Audio beeps for final seconds
3. **Completion**: Final "Finished" announcement

### Dual TTS System

For maximum reliability, the timer includes two TTS methods:
1. **pyttsx3** (Primary): Cross-platform TTS library
2. **Windows SAPI** (Fallback): Direct Windows COM interface

## Files

- **`timer.py`**: Main timer implementation
- **`requirements.txt`**: Python dependencies
- **`README.md`**: This documentation

## Dependencies

- **`pyttsx3`**: Text-to-speech library
- **`pywin32`**: Windows COM interface for SAPI fallback
- **`winsound`**: Built-in Windows audio (included with Python)
- **`time`**, **`re`**: Standard library modules

## Platform Support

- **Primary**: Windows (full functionality)
- **Limited**: Other platforms (TTS may work, but beeps require Windows)

## Example Output

```
============================================================
 TIMER SETUP
============================================================
 Duration: 00:25 (25 seconds)

 Announcements scheduled:
   00:20 - "20 seconds remaining"

 Final countdown from: 10
============================================================

 TEXT-TO-SPEECH STATUS
============================================================
 Found 2 TTS voices available
============================================================

 STARTING 00:25 TIMER
============================================================
 Time remaining: 00:24 (24.9s)

 SPEAKING: 20 seconds remaining
------------------------------------------------------------

 FINAL COUNTDOWN
============================================================
 Time remaining: 00:03 (3.1s)
    3
    BEEP!
    2  
    BEEP!
    1
    BEEP!

============================================================
 TIMER COMPLETED!
============================================================

 SPEAKING: Finished
------------------------------------------------------------
```

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve the timer functionality.

## License

This project is open source. Feel free to use and modify as needed.