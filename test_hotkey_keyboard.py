import keyboard

def on_activate():
    print('Global hotkey activated via keyboard module!')

print("Listening for cmd+alt+g with keyboard module...")
keyboard.add_hotkey('cmd+alt+g', on_activate)
keyboard.wait('esc')
