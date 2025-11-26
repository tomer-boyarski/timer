"""
Configuration management for timer settings.

See copilot_compliance in the root for code standards.
"""

import json
import csv
import os
from pathlib import Path
from typing import Dict, Any, List, Tuple, Optional

from src.stage import Stage, StageConfig


class ConfigManager:
    """
    Manages loading and saving of timer configuration.

    See copilot_compliance in the root for code standards.
    """

    DEFAULT_CONFIG_DIR = Path(__file__).parent.parent / "config"
    DEFAULT_SETTINGS_FILE = DEFAULT_CONFIG_DIR / "settings.json"
    DEFAULT_ANNOUNCEMENTS_CSV = DEFAULT_CONFIG_DIR / "announcements.csv"

    def __init__(
        self,
        settings_path: Optional[Path] = None,
    ) -> None:
        """
        Initialize configuration manager.

        See copilot_compliance in the root for code standards.

        Args:
            settings_path: Path to settings JSON file (default: config/settings.json)
        """
        self.settings_path = settings_path or self.DEFAULT_SETTINGS_FILE
        self._ensure_config_dir()

    def _ensure_config_dir(self) -> None:
        """
        Ensure config directory exists.

        See copilot_compliance in the root for code standards.
        """
        config_dir = self.settings_path.parent
        config_dir.mkdir(parents=True, exist_ok=True)

    def _get_default_settings(self) -> Dict[str, Any]:
        """
        Get default settings dictionary.

        See copilot_compliance in the root for code standards.

        Returns:
            Default settings dictionary
        """
        return {
            "prep_duration": "20s",
            "main_duration": "6m55s",
            "audio_offset": 0,
            "stages": StageConfig.default().to_dict(),
            "tts_rate_normal": 180,
            "tts_rate_countdown": 250,
        }

    def load_settings(self) -> Dict[str, Any]:
        """
        Load settings from JSON file.

        See copilot_compliance in the root for code standards.

        Returns:
            Settings dictionary
        """
        if not self.settings_path.exists():
            default_settings = self._get_default_settings()
            self.save_settings(default_settings)
            return default_settings

        try:
            with open(self.settings_path, "r", encoding="utf-8") as f:
                settings = json.load(f)
            # Merge with defaults to ensure all keys exist
            default_settings = self._get_default_settings()
            for key, value in default_settings.items():
                if key not in settings:
                    settings[key] = value
            return settings
        except (json.JSONDecodeError, IOError) as e:
            print(f"Error loading settings: {e}")
            return self._get_default_settings()

    def save_settings(self, settings: Dict[str, Any]) -> None:
        """
        Save settings to JSON file.

        See copilot_compliance in the root for code standards.

        Args:
            settings: Settings dictionary to save
        """
        self._ensure_config_dir()
        try:
            with open(self.settings_path, "w", encoding="utf-8") as f:
                json.dump(settings, f, indent=4)
        except IOError as e:
            print(f"Error saving settings: {e}")

    def get_stage_config(self, settings: Optional[Dict[str, Any]] = None) -> StageConfig:
        """
        Get StageConfig from settings.

        See copilot_compliance in the root for code standards.

        Args:
            settings: Optional settings dict (loads from file if None)

        Returns:
            StageConfig instance
        """
        if settings is None:
            settings = self.load_settings()
        return StageConfig.from_dict(settings.get("stages", []))

    def load_csv_announcements(
        self, csv_path: Optional[Path] = None
    ) -> List[Tuple[int, str]]:
        """
        Load announcements from CSV file.

        See copilot_compliance in the root for code standards.

        CSV format:
            remaining_seconds,announcement_text
            60,"1 minute remaining"
            30,"30 seconds remaining"

        Args:
            csv_path: Path to CSV file (default: config/announcements.csv)

        Returns:
            List of (remaining_seconds, text) tuples
        """
        path = csv_path or self.DEFAULT_ANNOUNCEMENTS_CSV

        if not path.exists():
            return []

        announcements: List[Tuple[int, str]] = []
        try:
            with open(path, "r", encoding="utf-8", newline="") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    try:
                        seconds = int(row["remaining_seconds"])
                        text = row["announcement_text"]
                        announcements.append((seconds, text))
                    except (KeyError, ValueError) as e:
                        print(f"Skipping invalid CSV row: {e}")
        except IOError as e:
            print(f"Error reading CSV: {e}")

        return sorted(announcements, key=lambda x: x[0], reverse=True)

    def update_durations(
        self, prep_duration: str, main_duration: str
    ) -> Dict[str, Any]:
        """
        Update timer durations and save.

        See copilot_compliance in the root for code standards.

        Args:
            prep_duration: New prep timer duration string
            main_duration: New main timer duration string

        Returns:
            Updated settings dictionary
        """
        settings = self.load_settings()
        settings["prep_duration"] = prep_duration
        settings["main_duration"] = main_duration
        self.save_settings(settings)
        return settings

    def update_stages(self, stage_config: StageConfig) -> Dict[str, Any]:
        """
        Update stage configuration and save.

        See copilot_compliance in the root for code standards.

        Args:
            stage_config: New StageConfig instance

        Returns:
            Updated settings dictionary
        """
        settings = self.load_settings()
        settings["stages"] = stage_config.to_dict()
        self.save_settings(settings)
        return settings
