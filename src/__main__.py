"""
Main entry point for the timer application.

See copilot_compliance in the root for code standards.
"""

from src.ui import launch_timer_ui


def main() -> None:
    """
    Main function to launch the timer GUI.

    See copilot_compliance in the root for code standards.
    """
    launch_timer_ui(prep_duration="10s", main_duration="7m15s")


if __name__ == "__main__":
    main()
