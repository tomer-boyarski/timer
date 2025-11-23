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
    launch_timer_ui(prep_duration="3s", main_duration="6m55s")


if __name__ == "__main__":
    main()
