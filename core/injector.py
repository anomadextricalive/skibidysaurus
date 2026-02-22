import subprocess
import time

def inject_text(text: str):
    """
    Injects text into the currently focused application by placing it 
    in the macOS clipboard and simulating Cmd+V.
    """
    # Give the OS a tiny fraction of a second to ensure focus is fully restored 
    # to the underlying app after our PyQt window closes
    time.sleep(0.3)
    
    # Put text into clipboard safely via pbcopy
    process = subprocess.Popen(['pbcopy'], stdin=subprocess.PIPE)
    process.communicate(input=text.encode('utf-8'))
    
    # Simulate Cmd+V using AppleScript
    apple_script = '''
    tell application "System Events"
        keystroke "v" using {command down}
    end tell
    '''
    subprocess.run(["osascript", "-e", apple_script])
