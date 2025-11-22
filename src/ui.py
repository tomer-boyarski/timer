"""
GUI interface for the timer using tkinter.

See copilot_compliance in the root for code standards.
"""

import tkinter as tk
import time
import threading
from typing import Optional, Dict

from src.tts import speak_text, test_tts_availability
from src.time_utils import parse_time_string, format_time, format_time_announcement
from src.announcements import generate_announcement_intervals


class TimerWindow:
    """
    Main timer window with START button, countdown display, and FINISHED screen.

    See copilot_compliance in the root for code standards.
    """

    def __init__(
        self,
        total_duration: str = "6m55s",
        shortest_interval: str = "5s",
        multiplier: int = 2,
        offset: float = 0.5,
    ) -> None:
        """
        Initialize the timer window.

        See copilot_compliance in the root for code standards.

        Args:
            total_duration: Total timer duration
            shortest_interval: Shortest announcement interval
            multiplier: Exponential multiplier for intervals
            offset: Seconds to announce early
        """
        self.root = tk.Tk()
        self.root.title("Timer")
        self.root.configure(bg="black")
        self.root.state("zoomed")  # Maximize window on Windows

        self.total_duration = total_duration
        self.shortest_interval = shortest_interval
        self.multiplier = multiplier
        self.offset = offset

        self.total_seconds = parse_time_string(total_duration)
        self.shortest_seconds = parse_time_string(shortest_interval)

        self.announcement_intervals = generate_announcement_intervals(
            self.total_seconds, shortest_interval, multiplier
        )
        self.announced: Dict[int, bool] = {
            interval: False for interval in self.announcement_intervals
        }

        self.timer_running = False
        self.start_time: Optional[float] = None

        self.label: Optional[tk.Label] = None
        self.button: Optional[tk.Button] = None

        self.show_start_screen()

    def show_start_screen(self) -> None:
        """
        Display the initial START screen with centered button.

        See copilot_compliance in the root for code standards.
        """
        self.clear_window()

        self.button = tk.Button(
            self.root,
            text="START",
            command=self.start_timer,
            font=("Arial", 24),
            bg="white",
            fg="black",
            padx=40,
            pady=20,
        )
        self.button.place(relx=0.5, rely=0.5, anchor="center")

    def show_timer_screen(self) -> None:
        """
        Display the countdown timer screen with large text.

        See copilot_compliance in the root for code standards.
        """
        self.clear_window()

        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        font_size = int(min(screen_width, screen_height) * 0.2)

        self.label = tk.Label(
            self.root,
            text="00:00",
            font=("Arial", font_size),
            fg="white",
            bg="black",
        )
        self.label.place(relx=0.5, rely=0.5, anchor="center")

    def show_finished_screen(self) -> None:
        """
        Display the FINISHED screen.

        See copilot_compliance in the root for code standards.
        """
        self.clear_window()

        screen_width = self.root.winfo_screenwidth()
        screen_height = self.root.winfo_screenheight()
        font_size = int(min(screen_width, screen_height) * 0.15)

        self.label = tk.Label(
            self.root,
            text="FINISHED",
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
        self.button = None

    def start_timer(self) -> None:
        """
        Start the timer countdown.

        See copilot_compliance in the root for code standards.
        """
        self.timer_running = True
        self.start_time = time.time()
        self.show_timer_screen()

        timer_thread = threading.Thread(target=self.run_timer, daemon=True)
        timer_thread.start()

        self.update_display()

    def run_timer(self) -> None:
        """
        Run timer logic in background thread for TTS announcements.

        See copilot_compliance in the root for code standards.
        """
        while self.timer_running and self.start_time is not None:
            elapsed_time = time.time() - self.start_time
            remaining_seconds = max(0, self.total_seconds - elapsed_time)

            if remaining_seconds <= 0:
                self.timer_running = False
                break

            # Only make announcements if timer is longer than shortest interval
            if self.total_seconds >= self.shortest_seconds:
                for interval in self.announcement_intervals:
                    trigger_time = interval + self.offset

                    if (
                        not self.announced[interval]
                        and remaining_seconds <= trigger_time
                    ):
                        announcement_text = format_time_announcement(interval)
                        speak_text(announcement_text)
                        self.announced[interval] = True

            time.sleep(0.1)

        speak_text("Finished")

    def update_display(self) -> None:
        """
        Update the countdown display every 100ms.

        See copilot_compliance in the root for code standards.
        """
        if not self.timer_running or self.start_time is None:
            self.show_finished_screen()
            return

        elapsed_time = time.time() - self.start_time
        remaining_seconds = max(0, self.total_seconds - elapsed_time)

        if remaining_seconds <= 0:
            self.timer_running = False
            self.show_finished_screen()
            return

        if self.label is not None:
            self.label.config(text=format_time(remaining_seconds))

        self.root.after(100, self.update_display)

    def run(self) -> None:
        """
        Start the tkinter main loop.

        See copilot_compliance in the root for code standards.
        """
        test_tts_availability()
        self.root.mainloop()


def launch_timer_ui(
    total_duration: str = "6m55s",
    shortest_interval: str = "15s",
    multiplier: int = 2,
    offset: float = 0.5,
) -> None:
    """
    Launch the timer GUI application.

    See copilot_compliance in the root for code standards.

    Args:
        total_duration: Total timer duration
        shortest_interval: Shortest announcement interval
        multiplier: Exponential multiplier for intervals
        offset: Seconds to announce early
    """
    app = TimerWindow(total_duration, shortest_interval, multiplier, offset)
    app.run()
