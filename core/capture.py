import subprocess
import base64
import os
import tempfile
import shutil

def capture_screen_base64() -> str:
    """
    Captures the main screen and returns it as a base64 encoded jpeg string.
    This runs silently without shutter sounds.
    """
    fd, temp_path = tempfile.mkstemp(suffix=".jpg")
    os.close(fd)
    try:
        # -x: disable sound, -m: only main monitor, -t: format
        subprocess.run(["screencapture", "-x", "-m", "-t", "jpg", temp_path], check=True)
        
        # Save a copy locally for debugging visibility issues
        debug_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "debug_screenshot.jpg")
        shutil.copy(temp_path, debug_path)

        with open(temp_path, "rb") as image_file:
            encoded_string = base64.b64encode(image_file.read()).decode('utf-8')
        return encoded_string
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
