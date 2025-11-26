"""
GUI interface for the timer using tkinter.

See copilot_compliance in the root for code standards.
"""

import tkinter as tk
from tkinter import ttk
import time
import threading
from typing import Optional, Dict, Callable, List

from src.tts import speak_text, test_tts_availability
from src.time_utils import parse_time_string, format_time
from src.stage import Stage, StageConfig
from src.config_manager import ConfigManager
from src.audio_generator import AudioGenerator, AudioPlayer


class DurationEntry(tk.Frame):
    """
    Custom entry widget for MM:SS duration input.

    See copilot_compliance in the root for code standards.
    """

    def __init__(
        self,
        parent: tk.Widget,
        label_text: str,
        default_value: str = "0:00",
        bg: str = "black",
        fg: str = "white",
    ) -> None:
        """
        Initialize duration entry.

        See copilot_compliance in the root for code standards.

        Args:
            parent: Parent widget
            label_text: Label to display above entry
            default_value: Default duration string
            bg: Background color
            fg: Foreground color
        """
        super().__init__(parent, bg=bg)

        self.label = tk.Label(
            self,
            text=label_text,
            font=("Arial", 14),
            fg=fg,
            bg=bg,
        )
        self.label.pack()

        self.entry_frame = tk.Frame(self, bg=bg)
        self.entry_frame.pack(pady=5)

        # Parse default value
        seconds = parse_time_string(default_value)
        mins = seconds // 60
        secs = seconds % 60

        # Minutes entry
        self.minutes_var = tk.StringVar(value=str(mins))
        self.minutes_entry = tk.Entry(
            self.entry_frame,
            textvariable=self.minutes_var,
            width=3,
            font=("Arial", 18),
            justify="center",
        )
        self.minutes_entry.pack(side=tk.LEFT)

        # Colon separator
        tk.Label(
            self.entry_frame,
            text=":",
            font=("Arial", 18),
            fg=fg,
            bg=bg,
        ).pack(side=tk.LEFT)

        # Seconds entry
        self.seconds_var = tk.StringVar(value=f"{secs:02d}")
        self.seconds_entry = tk.Entry(
            self.entry_frame,
            textvariable=self.seconds_var,
            width=3,
            font=("Arial", 18),
            justify="center",
        )
        self.seconds_entry.pack(side=tk.LEFT)

    def get_duration_string(self) -> str:
        """
        Get duration as string in format suitable for parse_time_string.

        See copilot_compliance in the root for code standards.

        Returns:
            Duration string like "6m55s"
        """
        try:
            mins = int(self.minutes_var.get())
            secs = int(self.seconds_var.get())
            if mins > 0 and secs > 0:
                return f"{mins}m{secs}s"
            elif mins > 0:
                return f"{mins}m"
            else:
                return f"{secs}s"
        except ValueError:
            return "0s"

    def get_seconds(self) -> int:
        """
        Get duration in seconds.

        See copilot_compliance in the root for code standards.

        Returns:
            Duration in seconds
        """
        return parse_time_string(self.get_duration_string())

    def set_duration(self, duration_str: str) -> None:
        """
        Set the duration from a string.

        See copilot_compliance in the root for code standards.

        Args:
            duration_str: Duration string like "6m55s"
        """
        seconds = parse_time_string(duration_str)
        mins = seconds // 60
        secs = seconds % 60
        self.minutes_var.set(str(mins))
        self.seconds_var.set(f"{secs:02d}")


class StageRow(tk.Frame):
    """
    Row widget for configuring a single stage.

    See copilot_compliance in the root for code standards.
    """

    def __init__(
        self,
        parent: tk.Widget,
        stage_name: str,
        duration_threshold: int,
        interval: int,
        verbosity: str,
        bg: str = "black",
        fg: str = "white",
        show_duration: bool = True,
    ) -> None:
        """
        Initialize stage row.

        See copilot_compliance in the root for code standards.

        Args:
            parent: Parent widget
            stage_name: Display name for stage
            duration_threshold: Stage duration threshold in seconds
            interval: Announcement interval in seconds
            verbosity: "low" or "high"
            bg: Background color
            fg: Foreground color
            show_duration: Whether to show duration input (False for "everything")
        """
        super().__init__(parent, bg=bg)
        self.stage_name = stage_name
        self.show_duration = show_duration
        self.original_threshold = duration_threshold

        # Stage name label
        self.name_label = tk.Label(
            self,
            text=stage_name,
            font=("Arial", 12),
            fg=fg,
            bg=bg,
            width=12,
            anchor="w",
        )
        self.name_label.pack(side=tk.LEFT, padx=5)

        # Duration entry (MM:SS format)
        if show_duration:
            self.duration_frame = tk.Frame(self, bg=bg)
            self.duration_frame.pack(side=tk.LEFT, padx=5)

            dur_mins = duration_threshold // 60
            dur_secs = duration_threshold % 60

            self.dur_mins_var = tk.StringVar(value=str(dur_mins))
            self.dur_mins_entry = tk.Entry(
                self.duration_frame,
                textvariable=self.dur_mins_var,
                width=2,
                font=("Arial", 12),
                justify="center",
            )
            self.dur_mins_entry.pack(side=tk.LEFT)

            tk.Label(
                self.duration_frame, text=":", font=("Arial", 12), fg=fg, bg=bg
            ).pack(side=tk.LEFT)

            self.dur_secs_var = tk.StringVar(value=f"{dur_secs:02d}")
            self.dur_secs_entry = tk.Entry(
                self.duration_frame,
                textvariable=self.dur_secs_var,
                width=2,
                font=("Arial", 12),
                justify="center",
            )
            self.dur_secs_entry.pack(side=tk.LEFT)
        else:
            # "Rest" label for "everything" stage
            tk.Label(
                self,
                text="(rest)",
                font=("Arial", 12),
                fg="gray",
                bg=bg,
                width=8,
            ).pack(side=tk.LEFT, padx=5)

        # Interval entry (MM:SS format)
        self.interval_frame = tk.Frame(self, bg=bg)
        self.interval_frame.pack(side=tk.LEFT, padx=5)

        int_mins = interval // 60
        int_secs = interval % 60

        self.int_mins_var = tk.StringVar(value=str(int_mins))
        self.int_mins_entry = tk.Entry(
            self.interval_frame,
            textvariable=self.int_mins_var,
            width=2,
            font=("Arial", 12),
            justify="center",
        )
        self.int_mins_entry.pack(side=tk.LEFT)

        tk.Label(self.interval_frame, text=":", font=("Arial", 12), fg=fg, bg=bg).pack(
            side=tk.LEFT
        )

        self.int_secs_var = tk.StringVar(value=f"{int_secs:02d}")
        self.int_secs_entry = tk.Entry(
            self.interval_frame,
            textvariable=self.int_secs_var,
            width=2,
            font=("Arial", 12),
            justify="center",
        )
        self.int_secs_entry.pack(side=tk.LEFT)

        # Verbosity dropdown
        self.verbosity_var = tk.StringVar(value=verbosity)
        self.verbosity_dropdown = ttk.Combobox(
            self,
            textvariable=self.verbosity_var,
            values=["low", "high"],
            state="readonly",
            width=6,
            font=("Arial", 12),
        )
        self.verbosity_dropdown.pack(side=tk.LEFT, padx=10)

    def get_stage(self, name: str) -> Stage:
        """
        Get Stage object from current values.

        See copilot_compliance in the root for code standards.

        Args:
            name: Internal stage name

        Returns:
            Stage object
        """
        # Get duration threshold
        if self.show_duration:
            try:
                mins = int(self.dur_mins_var.get())
                secs = int(self.dur_secs_var.get())
                duration_threshold = mins * 60 + secs
            except ValueError:
                duration_threshold = self.original_threshold
        else:
            duration_threshold = 0

        # Get interval
        try:
            int_mins = int(self.int_mins_var.get())
            int_secs = int(self.int_secs_var.get())
            interval = int_mins * 60 + int_secs
            if interval <= 0:
                interval = 1
        except ValueError:
            interval = 1

        return Stage(
            name=name,
            duration_threshold=duration_threshold,
            announcement_interval=interval,
            verbosity=self.verbosity_var.get(),
        )


class ConfigScreen(tk.Frame):
    """
    Configuration screen for timer settings.

    See copilot_compliance in the root for code standards.
    """

    def __init__(
        self,
        parent: tk.Tk,
        config_manager: ConfigManager,
        on_start: Callable[[], None],
    ) -> None:
        """
        Initialize configuration screen.

        See copilot_compliance in the root for code standards.

        Args:
            parent: Parent window
            config_manager: Configuration manager
            on_start: Callback when START is clicked
        """
        super().__init__(parent, bg="black")
        self.config_manager = config_manager
        self.on_start = on_start

        settings = config_manager.load_settings()

        # Title
        title = tk.Label(
            self,
            text="Timer Configuration",
            font=("Arial", 24, "bold"),
            fg="white",
            bg="black",
        )
        title.pack(pady=20)

        # Timer durations section
        durations_frame = tk.Frame(self, bg="black")
        durations_frame.pack(pady=20)

        # Prep timer (left)
        self.prep_entry = DurationEntry(
            durations_frame,
            "PREP TIMER",
            settings.get("prep_duration", "20s"),
        )
        self.prep_entry.pack(side=tk.LEFT, padx=40)

        # Main timer (right)
        self.main_entry = DurationEntry(
            durations_frame,
            "MAIN TIMER",
            settings.get("main_duration", "6m55s"),
        )
        self.main_entry.pack(side=tk.LEFT, padx=40)

        # Announcements section title
        ann_title = tk.Label(
            self,
            text="Announcement Configuration",
            font=("Arial", 16),
            fg="white",
            bg="black",
        )
        ann_title.pack(pady=(30, 10))

        # Column headers
        headers_frame = tk.Frame(self, bg="black")
        headers_frame.pack()

        headers = ["Stage", "Duration", "Interval", "Verbosity"]
        widths = [12, 8, 8, 8]
        for header, width in zip(headers, widths):
            tk.Label(
                headers_frame,
                text=header,
                font=("Arial", 11, "bold"),
                fg="gray",
                bg="black",
                width=width,
            ).pack(side=tk.LEFT, padx=5)

        # Stage rows
        stages_frame = tk.Frame(self, bg="black")
        stages_frame.pack(pady=10)

        stage_config = config_manager.get_stage_config(settings)
        stage_dict = {s.name: s for s in stage_config.stages}

        # Countdown stage
        countdown = stage_dict.get("countdown", Stage("countdown", 10, 1, "low"))
        self.countdown_row = StageRow(
            stages_frame,
            "Countdown",
            countdown.duration_threshold,
            countdown.announcement_interval,
            countdown.verbosity,
            show_duration=True,
        )
        self.countdown_row.pack(pady=5)

        # One minute stage
        one_min = stage_dict.get("one_minute", Stage("one_minute", 60, 10, "high"))
        self.one_minute_row = StageRow(
            stages_frame,
            "One Minute",
            one_min.duration_threshold,
            one_min.announcement_interval,
            one_min.verbosity,
            show_duration=True,
        )
        self.one_minute_row.pack(pady=5)

        # Everything stage
        everything = stage_dict.get("everything", Stage("everything", 0, 60, "high"))
        self.everything_row = StageRow(
            stages_frame,
            "Everything",
            everything.duration_threshold,
            everything.announcement_interval,
            everything.verbosity,
            show_duration=False,
        )
        self.everything_row.pack(pady=5)

        # Start button
        self.start_button = tk.Button(
            self,
            text="START",
            command=self._on_start_clicked,
            font=("Arial", 24),
            bg="white",
            fg="black",
            padx=60,
            pady=15,
        )
        self.start_button.pack(pady=40)

        # Status label for loading message
        self.status_label = tk.Label(
            self,
            text="",
            font=("Arial", 12),
            fg="gray",
            bg="black",
        )
        self.status_label.pack()

    def _on_start_clicked(self) -> None:
        """
        Handle START button click.

        See copilot_compliance in the root for code standards.
        """
        # Show loading status
        self.status_label.config(text="Generating audio...")
        self.start_button.config(state="disabled")
        self.update()

        # Save settings
        self._save_settings()

        # Call start callback
        self.on_start()

    def _save_settings(self) -> None:
        """
        Save current settings to config file.

        See copilot_compliance in the root for code standards.
        """
        settings = self.config_manager.load_settings()

        settings["prep_duration"] = self.prep_entry.get_duration_string()
        settings["main_duration"] = self.main_entry.get_duration_string()

        # Build stage config
        stages = [
            self.countdown_row.get_stage("countdown"),
            self.one_minute_row.get_stage("one_minute"),
            self.everything_row.get_stage("everything"),
        ]
        stage_config = StageConfig(stages)
        settings["stages"] = stage_config.to_dict()

        self.config_manager.save_settings(settings)

    def get_prep_duration(self) -> str:
        """Get prep timer duration string."""
        return self.prep_entry.get_duration_string()

    def get_main_duration(self) -> str:
        """Get main timer duration string."""
        return self.main_entry.get_duration_string()

    def get_stage_config(self) -> StageConfig:
        """Get current stage configuration."""
        stages = [
            self.countdown_row.get_stage("countdown"),
            self.one_minute_row.get_stage("one_minute"),
            self.everything_row.get_stage("everything"),
        ]
        return StageConfig(stages)


class AudioTimer:
    """
    Timer that uses pre-generated audio file for announcements.

    See copilot_compliance in the root for code standards.
    """

    def __init__(
        self,
        root: tk.Tk,
        prep_seconds: int,
        main_seconds: int,
        audio_file: str,
        audio_offset: float = 0.0,
        on_complete: Optional[Callable[[], None]] = None,
    ) -> None:
        """
        Initialize audio timer.

        See copilot_compliance in the root for code standards.

        Args:
            root: tkinter root window
            prep_seconds: Prep timer duration in seconds
            main_seconds: Main timer duration in seconds
            audio_file: Path to pre-generated audio file
            audio_offset: Delay between audio start and timer start
            on_complete: Callback when timer finishes
        """
        self.root = root
        self.prep_seconds = prep_seconds
        self.main_seconds = main_seconds
        self.total_seconds = prep_seconds + main_seconds
        self.audio_file = audio_file
        self.audio_offset = audio_offset
        self.on_complete = on_complete

        self.audio_player = AudioPlayer()
        self.timer_running = False
        self.start_time: Optional[float] = None
        self.label: Optional[tk.Label] = None

        # Track which phase we're in
        self.in_prep_phase = True

    def start(self) -> None:
        """
        Start the timer with audio.

        See copilot_compliance in the root for code standards.
        """
        # Start audio playback
        self.audio_player.play_file(self.audio_file)

        # Wait for offset then start visual timer
        if self.audio_offset > 0:
            self.root.after(int(self.audio_offset * 1000), self._start_visual_timer)
        else:
            self._start_visual_timer()

    def _start_visual_timer(self) -> None:
        """
        Start the visual countdown after audio offset.

        See copilot_compliance in the root for code standards.
        """
        self.timer_running = True
        self.start_time = time.time()
        self.in_prep_phase = True
        self.show_timer_screen()
        self.update_display()

    def show_timer_screen(self) -> None:
        """
        Display the countdown timer screen.

        See copilot_compliance in the root for code standards.
        """
        self.clear_window()

        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        font_size = int(min(screen_width, screen_height) * 0.25)

        self.label = tk.Label(
            self.root,
            text="00:00",
            font=("Arial", font_size),
            fg="white",
            bg="black",
        )
        self.label.place(relx=0.5, rely=0.5, anchor="center")

    def clear_window(self) -> None:
        """
        Clear all widgets from the window.

        See copilot_compliance in the root for code standards.
        """
        for widget in self.root.winfo_children():
            widget.destroy()
        self.label = None

    def update_display(self) -> None:
        """
        Update the countdown display.

        See copilot_compliance in the root for code standards.
        """
        if not self.timer_running or self.start_time is None:
            return

        elapsed = time.time() - self.start_time

        if self.in_prep_phase:
            remaining = max(0, self.prep_seconds - elapsed)
            if remaining <= 0:
                # Transition to main timer
                self.in_prep_phase = False
                self.start_time = time.time()
                remaining = self.main_seconds
        else:
            remaining = max(0, self.main_seconds - elapsed)

        if remaining <= 0 and not self.in_prep_phase:
            self.timer_running = False
            if self.on_complete:
                self.on_complete()
            return

        if self.label is not None:
            self.label.config(text=format_time(remaining))

        self.root.after(100, self.update_display)

    def stop(self) -> None:
        """
        Stop the timer and audio.

        See copilot_compliance in the root for code standards.
        """
        self.timer_running = False
        self.audio_player.stop()


class TimerWindow:
    """
    Main timer window with configuration screen and audio-synced countdown.

    See copilot_compliance in the root for code standards.
    """

    def __init__(self) -> None:
        """
        Initialize the timer window.

        See copilot_compliance in the root for code standards.
        """
        self.root = tk.Tk()
        self.root.title("Timer")
        self.root.configure(bg="black")
        self.root.state("zoomed")

        self.config_manager = ConfigManager()
        self.audio_generator: Optional[AudioGenerator] = None
        self.current_timer: Optional[AudioTimer] = None
        self.audio_file: Optional[str] = None

        self.config_screen: Optional[ConfigScreen] = None

        self.show_config_screen()

    def show_config_screen(self) -> None:
        """
        Display the configuration screen.

        See copilot_compliance in the root for code standards.
        """
        self.clear_window()

        self.config_screen = ConfigScreen(
            self.root,
            self.config_manager,
            self.on_start,
        )
        self.config_screen.pack(expand=True)

    def on_start(self) -> None:
        """
        Handle START button click - generate audio and start timer.

        See copilot_compliance in the root for code standards.
        """
        if self.config_screen is None:
            return

        # Get settings
        prep_duration = self.config_screen.get_prep_duration()
        main_duration = self.config_screen.get_main_duration()
        stage_config = self.config_screen.get_stage_config()

        settings = self.config_manager.load_settings()
        tts_normal = settings.get("tts_rate_normal", 180)
        tts_countdown = settings.get("tts_rate_countdown", 250)
        audio_offset = settings.get("audio_offset", 0)

        # Generate audio in background thread
        def generate_and_start() -> None:
            self.audio_generator = AudioGenerator(
                tts_rate_normal=tts_normal,
                tts_rate_countdown=tts_countdown,
            )

            self.audio_file = self.audio_generator.generate_full_audio(
                prep_duration=prep_duration,
                main_duration=main_duration,
                prep_stages=stage_config,
                main_stages=stage_config,
            )

            # Start timer on main thread
            self.root.after(
                0, lambda: self.start_timer(prep_duration, main_duration, audio_offset)
            )

        thread = threading.Thread(target=generate_and_start, daemon=True)
        thread.start()

    def start_timer(
        self, prep_duration: str, main_duration: str, audio_offset: float
    ) -> None:
        """
        Start the timer with audio.

        See copilot_compliance in the root for code standards.
        """
        if self.audio_file is None:
            return

        prep_seconds = parse_time_string(prep_duration)
        main_seconds = parse_time_string(main_duration)

        self.current_timer = AudioTimer(
            root=self.root,
            prep_seconds=prep_seconds,
            main_seconds=main_seconds,
            audio_file=self.audio_file,
            audio_offset=audio_offset,
            on_complete=self.on_timer_complete,
        )
        self.current_timer.start()

    def on_timer_complete(self) -> None:
        """
        Handle timer completion.

        See copilot_compliance in the root for code standards.
        """
        self.show_finished_screen()

        # Cleanup audio
        if self.audio_generator:
            self.audio_generator.cleanup()

    def show_finished_screen(self) -> None:
        """
        Display the FINISHED screen.

        See copilot_compliance in the root for code standards.
        """
        self.clear_window()

        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        font_size = int(min(screen_width, screen_height) * 0.15)

        label = tk.Label(
            self.root,
            text="FINISHED",
            font=("Arial", font_size),
            fg="white",
            bg="black",
        )
        label.place(relx=0.5, rely=0.5, anchor="center")

    def clear_window(self) -> None:
        """
        Clear all widgets from the window.

        See copilot_compliance in the root for code standards.
        """
        for widget in self.root.winfo_children():
            widget.destroy()
        self.config_screen = None

    def run(self) -> None:
        """
        Start the tkinter main loop.

        See copilot_compliance in the root for code standards.
        """
        self.root.mainloop()


def launch_timer_ui() -> None:
    """
    Launch the timer GUI application.

    See copilot_compliance in the root for code standards.
    """
    app = TimerWindow()
    app.run()
