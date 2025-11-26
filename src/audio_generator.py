"""
Audio file generation for timer announcements.

See copilot_compliance in the root for code standards.
"""

import wave
import struct
import tempfile
import os
import threading
from typing import List, Tuple, Optional, Callable

import pyttsx3

from src.stage import StageConfig
from src.time_utils import parse_time_string


class AudioGenerator:
    """
    Generates complete audio file with all timer announcements.

    See copilot_compliance in the root for code standards.
    """

    # Audio parameters
    SAMPLE_RATE = 22050
    CHANNELS = 1
    SAMPLE_WIDTH = 2  # 16-bit

    def __init__(
        self,
        tts_rate_normal: int = 180,
        tts_rate_countdown: int = 250,
    ) -> None:
        """
        Initialize audio generator.

        See copilot_compliance in the root for code standards.

        Args:
            tts_rate_normal: Speech rate for normal announcements
            tts_rate_countdown: Speech rate for countdown (must be fast)
        """
        self.tts_rate_normal = tts_rate_normal
        self.tts_rate_countdown = tts_rate_countdown
        self._temp_files: List[str] = []

    def _generate_silence(self, duration_seconds: float) -> bytes:
        """
        Generate silence audio data.

        See copilot_compliance in the root for code standards.

        Args:
            duration_seconds: Duration of silence in seconds

        Returns:
            Raw audio bytes of silence
        """
        num_samples = int(duration_seconds * self.SAMPLE_RATE)
        # 16-bit silence = 0
        return struct.pack("<" + "h" * num_samples, *([0] * num_samples))

    def _generate_speech_audio(
        self, text: str, rate: int
    ) -> Tuple[bytes, float]:
        """
        Generate speech audio using pyttsx3 and save to temp WAV.

        See copilot_compliance in the root for code standards.

        Args:
            text: Text to speak
            rate: Speech rate

        Returns:
            Tuple of (audio_bytes, duration_seconds)
        """
        # Create temp file for TTS output
        fd, temp_path = tempfile.mkstemp(suffix=".wav")
        os.close(fd)
        self._temp_files.append(temp_path)

        try:
            engine = pyttsx3.init()  # type: ignore
            engine.setProperty("rate", rate)  # type: ignore

            # Save to file
            engine.save_to_file(text, temp_path)  # type: ignore
            engine.runAndWait()  # type: ignore

            try:
                engine.stop()  # type: ignore
                del engine
            except:
                pass

            # Read the generated WAV file
            with wave.open(temp_path, "rb") as wav_file:
                frames = wav_file.readframes(wav_file.getnframes())
                framerate = wav_file.getframerate()
                nframes = wav_file.getnframes()

                # Calculate duration
                duration = nframes / framerate

                # Resample if needed (to match our target sample rate)
                if framerate != self.SAMPLE_RATE:
                    frames = self._resample(frames, framerate, self.SAMPLE_RATE)

                return frames, duration

        except Exception as e:
            print(f"Error generating speech for '{text}': {e}")
            # Return short silence on error
            return self._generate_silence(0.5), 0.5

    def _resample(
        self, audio_bytes: bytes, from_rate: int, to_rate: int
    ) -> bytes:
        """
        Simple resampling by linear interpolation.

        See copilot_compliance in the root for code standards.

        Args:
            audio_bytes: Input audio bytes
            from_rate: Source sample rate
            to_rate: Target sample rate

        Returns:
            Resampled audio bytes
        """
        # Unpack samples
        num_samples = len(audio_bytes) // 2
        samples = list(struct.unpack("<" + "h" * num_samples, audio_bytes))

        # Calculate ratio
        ratio = to_rate / from_rate

        # Resample
        new_length = int(len(samples) * ratio)
        resampled: List[int] = []

        for i in range(new_length):
            src_idx = i / ratio
            idx_low = int(src_idx)
            idx_high = min(idx_low + 1, len(samples) - 1)
            frac = src_idx - idx_low

            # Linear interpolation
            sample = int(samples[idx_low] * (1 - frac) + samples[idx_high] * frac)
            resampled.append(sample)

        return struct.pack("<" + "h" * len(resampled), *resampled)

    def generate_timer_audio(
        self,
        total_seconds: int,
        announcements: List[Tuple[int, str]],
        include_finished: bool = True,
    ) -> Tuple[bytes, float]:
        """
        Generate audio for a single timer.

        See copilot_compliance in the root for code standards.

        Args:
            total_seconds: Total timer duration
            announcements: List of (remaining_seconds, text) tuples
            include_finished: Whether to include "Finished" at the end

        Returns:
            Tuple of (audio_bytes, total_duration)
        """
        audio_data = b""
        current_position = 0.0  # Position in seconds from start

        # Sort announcements by remaining time descending (earliest in time first)
        sorted_announcements = sorted(announcements, key=lambda x: x[0], reverse=True)

        for remaining_seconds, text in sorted_announcements:
            # Calculate when this announcement should play (from start)
            announcement_time = total_seconds - remaining_seconds

            # Add silence up to this point
            silence_duration = announcement_time - current_position
            if silence_duration > 0:
                audio_data += self._generate_silence(silence_duration)
                current_position = announcement_time

            # Determine speech rate (fast for countdown numbers)
            rate = self.tts_rate_normal
            if text.isdigit() or (len(text) <= 2 and text.replace(" ", "").isdigit()):
                rate = self.tts_rate_countdown

            # Generate speech
            speech_audio, speech_duration = self._generate_speech_audio(text, rate)
            audio_data += speech_audio
            current_position += speech_duration

        # Add silence until end of timer
        remaining_silence = total_seconds - current_position
        if remaining_silence > 0:
            audio_data += self._generate_silence(remaining_silence)
            current_position = float(total_seconds)

        # Add "Finished" announcement
        if include_finished:
            speech_audio, speech_duration = self._generate_speech_audio(
                "Finished", self.tts_rate_normal
            )
            audio_data += speech_audio
            current_position += speech_duration

        return audio_data, current_position

    def generate_full_audio(
        self,
        prep_duration: str,
        main_duration: str,
        prep_stages: StageConfig,
        main_stages: StageConfig,
        output_path: Optional[str] = None,
    ) -> str:
        """
        Generate complete audio file for prep + main timer.

        See copilot_compliance in the root for code standards.

        Args:
            prep_duration: Prep timer duration string
            main_duration: Main timer duration string
            prep_stages: Stage configuration for prep timer
            main_stages: Stage configuration for main timer
            output_path: Output WAV file path (auto-generated if None)

        Returns:
            Path to generated WAV file
        """
        prep_seconds = parse_time_string(prep_duration)
        main_seconds = parse_time_string(main_duration)

        # Generate announcements
        prep_announcements = prep_stages.generate_announcements(prep_seconds)
        main_announcements = main_stages.generate_announcements(main_seconds)

        # Generate prep timer audio (no "Finished")
        prep_audio, _ = self.generate_timer_audio(
            prep_seconds, prep_announcements, include_finished=False
        )

        # Generate main timer audio (with "Finished")
        main_audio, _ = self.generate_timer_audio(
            main_seconds, main_announcements, include_finished=True
        )

        # Combine
        full_audio = prep_audio + main_audio

        # Create output path
        if output_path is None:
            fd, output_path = tempfile.mkstemp(suffix=".wav")
            os.close(fd)
            self._temp_files.append(output_path)

        # Write WAV file
        with wave.open(output_path, "wb") as wav_file:
            wav_file.setnchannels(self.CHANNELS)
            wav_file.setsampwidth(self.SAMPLE_WIDTH)
            wav_file.setframerate(self.SAMPLE_RATE)
            wav_file.writeframes(full_audio)

        return output_path

    def cleanup(self) -> None:
        """
        Clean up temporary files.

        See copilot_compliance in the root for code standards.
        """
        for temp_file in self._temp_files:
            try:
                if os.path.exists(temp_file):
                    os.remove(temp_file)
            except:
                pass
        self._temp_files.clear()

    def __del__(self) -> None:
        """Cleanup on destruction."""
        self.cleanup()


class AudioPlayer:
    """
    Plays audio files with synchronization support.

    See copilot_compliance in the root for code standards.
    """

    def __init__(self) -> None:
        """
        Initialize audio player.

        See copilot_compliance in the root for code standards.
        """
        self._playing = False
        self._play_thread: Optional[threading.Thread] = None

    def play_file(self, file_path: str, on_complete: Optional[Callable[[], None]] = None) -> None:
        """
        Play audio file in background thread.

        See copilot_compliance in the root for code standards.

        Args:
            file_path: Path to WAV file
            on_complete: Callback when playback finishes
        """
        self._playing = True
        self._play_thread = threading.Thread(
            target=self._play_worker,
            args=(file_path, on_complete),
            daemon=True,
        )
        self._play_thread.start()

    def _play_worker(
        self, file_path: str, on_complete: Optional[Callable[[], None]]
    ) -> None:
        """
        Worker thread for audio playback.

        See copilot_compliance in the root for code standards.

        Args:
            file_path: Path to WAV file
            on_complete: Callback when playback finishes
        """
        try:
            import winsound

            winsound.PlaySound(file_path, winsound.SND_FILENAME)
        except Exception as e:
            print(f"Audio playback error: {e}")
            # Fallback: try pygame or other libraries
            try:
                import pygame

                pygame.mixer.init()
                pygame.mixer.music.load(file_path)
                pygame.mixer.music.play()
                while pygame.mixer.music.get_busy():
                    pygame.time.wait(100)
            except:
                print("No audio playback available")

        self._playing = False
        if on_complete:
            on_complete()

    def stop(self) -> None:
        """
        Stop current playback.

        See copilot_compliance in the root for code standards.
        """
        self._playing = False
        try:
            import winsound

            winsound.PlaySound(None, winsound.SND_PURGE)
        except:
            pass

    @property
    def is_playing(self) -> bool:
        """Check if audio is currently playing."""
        return self._playing
