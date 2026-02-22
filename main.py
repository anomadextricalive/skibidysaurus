import sys
import threading
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu, QWidget, QVBoxLayout, QPushButton
from PyQt6.QtGui import QIcon, QAction
from PyQt6.QtCore import QObject, pyqtSignal, QThread, QTimer

from ui.overlay import HoverOverlay
from core.capture import capture_screen_base64
from core.injector import inject_text
from llm.clients import LLMManager

class WorkerThread(QThread):
    result_ready = pyqtSignal(str)

    def __init__(self, prompt, model, llm_manager):
        super().__init__()
        self.prompt = prompt
        self.model = model
        self.llm_manager = llm_manager

    def run(self):
        # 1. Capture screen silently
        try:
            base64_image = capture_screen_base64()
            # 2. Get LLM Response
            response = self.llm_manager.get_response(self.prompt, base64_image, self.model)
        except Exception as e:
            response = f"Error capturing or generating: {e}"
        # 3. Emit result
        self.result_ready.emit(response)


class FloatingLauncher(QWidget):
    def __init__(self, trigger_col):
        super().__init__()
        self.trigger_col = trigger_col
        # ToolTip ensures it doesn't show in the dock, stays on top, bypassing Mac window ordering logic
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint | 
            Qt.WindowType.WindowStaysOnTopHint | 
            Qt.WindowType.ToolTip
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        
        self.btn = QPushButton("🚀")
        self.btn.setFixedSize(50, 50)
        self.btn.setStyleSheet("""
            QPushButton {
                background-color: rgba(60, 120, 200, 220);
                border-radius: 25px;
                color: white;
                font-size: 24px;
                border: 2px solid rgba(255, 255, 255, 0.3);
            }
            QPushButton:hover {
                background-color: rgba(80, 140, 220, 255);
            }
        """)
        self.btn.clicked.connect(self.on_click)
        self.btn.setToolTip("Launch Skibidysaurus")
        
        layout.addWidget(self.btn)
        self.setLayout(layout)
        
        # Position at the center-right edge of the screen
        from PyQt6.QtGui import QGuiApplication
        screen = QGuiApplication.primaryScreen().geometry()
        
        # Position with padding from the right edge
        x_pos = screen.width() - 80
        y_pos = screen.height() // 2 - 25
        self.setGeometry(x_pos, y_pos, 50, 50)
        self.show()
        self.raise_()

    def on_click(self):
        self.trigger_col()

class AppController(QObject):
    # Signal to safely show UI from a background pynput thread, optionally with selected text
    trigger_ui = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.app = QApplication(sys.argv)
        
        # We don't want the app to quit if the overlay is hidden
        self.app.setQuitOnLastWindowClosed(False)

        # Initialize System Tray
        self.tray_icon = QSystemTrayIcon(QIcon("icon.png"), self.app)
        self.tray_icon.setToolTip("Skibidysaurus")
        
        # Create a menu for the tray
        tray_menu = QMenu()
        
        # "Ask Skibidysaurus" Action
        ask_action = QAction("Ask Skibidysaurus", self.app)
        ask_action.triggered.connect(self.on_activate)
        tray_menu.addAction(ask_action)
        
        tray_menu.addSeparator()

        # "Quit" Action
        quit_action = QAction("Quit", self.app)
        quit_action.triggered.connect(self.quit_app)
        tray_menu.addAction(quit_action)

        self.tray_icon.setContextMenu(tray_menu)
        self.tray_icon.show()

        self.overlay = HoverOverlay()
        self.llm_manager = LLMManager()
        self.launcher = FloatingLauncher(self.on_activate)

        # Connect signals
        self.trigger_ui.connect(self.overlay.show_ready)
        self.overlay.submit_query.connect(self.handle_query)
        self.overlay.settings_saved.connect(self.llm_manager.refresh_config)

        # Setup global hotkey polling (Cmd + Option + G) via PyObjC
        self.hotkey_timer = QTimer(self)
        self.hotkey_timer.timeout.connect(self.check_hotkey)
        self.hotkey_timer.start(50)  # Check every 50ms
        self.hotkey_pressed_state = False
        
        print("Skibidysaurus running quietly in the background! Press Cmd+Option+G anywhere to trigger.")

    def check_hotkey(self):
        from Quartz import CGEventSourceKeyState, kCGEventSourceStateHIDSystemState
        # KeyCodes: 5 is 'G', 55 is Command, 58 is Option
        g_pressed = CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 5)
        cmd_pressed = CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 55)
        opt_pressed = CGEventSourceKeyState(kCGEventSourceStateHIDSystemState, 58)
        
        is_pressed = g_pressed and cmd_pressed and opt_pressed
        
        if is_pressed and not self.hotkey_pressed_state:
            # Just pressed
            self.hotkey_pressed_state = True
            self.on_activate()
        elif not is_pressed and self.hotkey_pressed_state:
            # Released
            self.hotkey_pressed_state = False

    def on_activate(self):
        # Hotkey pressed! Safely tell PyQt to show the window.
        import time
        from Quartz import CGEventCreateKeyboardEvent, CGEventPost, kCGHIDEventTap
        
        # 1. Simulate Cmd+C to copy selected text
        # Keycode 8 is 'C', 55 is Command
        try:
            # Cmd Down
            cmd_down = CGEventCreateKeyboardEvent(None, 55, True)
            CGEventPost(kCGHIDEventTap, cmd_down)
            
            # C Down
            c_down = CGEventCreateKeyboardEvent(None, 8, True)
            CGEventPost(kCGHIDEventTap, c_down)
            
            # C Up
            c_up = CGEventCreateKeyboardEvent(None, 8, False)
            CGEventPost(kCGHIDEventTap, c_up)
            
            # Cmd Up
            cmd_up = CGEventCreateKeyboardEvent(None, 55, False)
            CGEventPost(kCGHIDEventTap, cmd_up)
        except Exception as e:
            print(f"Error sending Cmd+C: {e}")
            
        # 2. Give the OS a tiny fraction of a second to update the clipboard
        time.sleep(0.1)
        
        # 3. Read clipboard text
        clipboard = QApplication.clipboard()
        selected_text = clipboard.text()
        
        # 4. Show UI with the copied text
        self.trigger_ui.emit(selected_text)

    def handle_query(self, prompt, model):
        self.worker = WorkerThread(prompt, model, self.llm_manager)
        self.worker.result_ready.connect(self.on_result)
        self.worker.start()

    def on_result(self, response):
        # Display the output directly inside the overlay
        self.overlay.show_result(response)
        
        # Copy the text to the clipboard as a convenience
        QApplication.clipboard().setText(response)

    def quit_app(self):
        self.overlay.close()
        self.app.quit()
        sys.exit()

    def run(self):
        # Run the PyQt event loop
        sys.exit(self.app.exec())


if __name__ == "__main__":
    controller = AppController()
    controller.run()
