from PyQt6.QtWidgets import (QWidget, QVBoxLayout, QLineEdit, QComboBox, QApplication, 
                               QPushButton, QHBoxLayout, QTextEdit, QDialog, QLabel, 
                               QFormLayout, QDialogButtonBox)
from PyQt6.QtCore import Qt, pyqtSignal, QTimer
import os
from dotenv import set_key, load_dotenv

class SettingsDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Skibidysaurus Settings")
        self.setFixedSize(400, 150)
        
        layout = QVBoxLayout(self)
        form_layout = QFormLayout()
        
        self.api_key_input = QLineEdit()
        self.api_key_input.setEchoMode(QLineEdit.EchoMode.Password)
        load_dotenv()
        self.api_key_input.setText(os.environ.get("GEMINI_API_KEY", ""))
        form_layout.addRow(QLabel("Gemini API Key:"), self.api_key_input)
        
        self.theme_selector = QComboBox()
        self.theme_selector.addItems(["Dark (Default)", "Light", "Neon", "Hacker"])
        current_theme = os.environ.get("HOVERGPT_THEME", "Dark (Default)")
        self.theme_selector.setCurrentText(current_theme)
        form_layout.addRow(QLabel("Theme:"), self.theme_selector)
        
        layout.addLayout(form_layout)
        
        button_box = QDialogButtonBox(QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel)
        button_box.accepted.connect(self.save_settings)
        button_box.rejected.connect(self.reject)
        layout.addWidget(button_box)

    def save_settings(self):
        new_key = self.api_key_input.text().strip()
        new_theme = self.theme_selector.currentText()
        env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
        
        set_key(env_path, "GEMINI_API_KEY", new_key)
        set_key(env_path, "HOVERGPT_THEME", new_theme)
        
        # Refresh current process env
        os.environ["GEMINI_API_KEY"] = new_key
        os.environ["HOVERGPT_THEME"] = new_theme
        self.accept()

class HoverOverlay(QWidget):
    # Signal emitted when user hits Enter: (prompt, selected_model)
    submit_query = pyqtSignal(str, str)
    # Signal emitted when settings are saved to trigger LLM re-init
    settings_saved = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.animation_timer = QTimer()
        self.animation_timer.timeout.connect(self.animate_thinking)
        self.animation_dots = 0
        self.init_ui()

    def init_ui(self):
        # Frameless, stay on top, tool window (doesn't show in app switcher)
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint | 
            Qt.WindowType.WindowStaysOnTopHint | 
            Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        
        layout = QVBoxLayout()
        layout.setContentsMargins(10, 10, 10, 10)

        # Style container for floating look
        self.container = QWidget(self)
        self.apply_theme()
        
        container_layout = QVBoxLayout(self.container)

        self.model_selector = QComboBox()
        self.model_selector.addItems(["gemini", "ollama"])
        container_layout.addWidget(self.model_selector)
        
        self.settings_button = QPushButton("⚙")
        self.settings_button.setToolTip("Settings")
        self.settings_button.clicked.connect(self.open_settings)
        self.settings_button.setStyleSheet("QPushButton { padding: 5px; border-radius: 5px; font-size: 14px; }")
        
        # Upper row for model and settings
        upper_row = QHBoxLayout()
        upper_row.addWidget(self.model_selector)
        upper_row.addWidget(self.settings_button)
        container_layout.addLayout(upper_row)

        # Input row with text field and explicit submit button
        input_row_layout = QHBoxLayout()
        
        self.input_field = QLineEdit()
        self.input_field.setPlaceholderText("Ask Skibidysaurus (e.g., 'Make this concise')...")
        self.input_field.returnPressed.connect(self.on_submit)
        input_row_layout.addWidget(self.input_field)

        self.submit_button = QPushButton("Submit")
        self.submit_button.clicked.connect(self.on_submit)
        input_row_layout.addWidget(self.submit_button)

        container_layout.addLayout(input_row_layout)

        # Output area
        self.output_area = QTextEdit()
        self.output_area.setReadOnly(True)
        self.output_area.setPlaceholderText("Gemini's response will appear here...")
        container_layout.addWidget(self.output_area)

        layout.addWidget(self.container)
        self.setLayout(layout)
        self.setFixedSize(500, 450)

    def apply_theme(self):
        theme_name = os.environ.get("HOVERGPT_THEME", "Dark (Default)")
        
        themes = {
            "Dark (Default)": {
                "bg": "rgba(30, 30, 30, 230)", "fg": "white",
                "input_bg": "rgba(0, 0, 0, 150)", "border": "#555",
                "btn_bg": "rgba(60, 120, 200, 200)", "btn_hover": "rgba(80, 140, 220, 255)"
            },
            "Light": {
                "bg": "rgba(240, 240, 245, 230)", "fg": "#333",
                "input_bg": "rgba(255, 255, 255, 180)", "border": "#ccc",
                "btn_bg": "rgba(100, 150, 230, 200)", "btn_hover": "rgba(120, 170, 250, 255)"
            },
            "Neon": {
                "bg": "rgba(10, 5, 20, 230)", "fg": "#0ff",
                "input_bg": "rgba(20, 10, 40, 150)", "border": "#f0f",
                "btn_bg": "rgba(200, 0, 200, 200)", "btn_hover": "rgba(255, 0, 255, 255)"
            },
            "Hacker": {
                "bg": "rgba(0, 15, 0, 230)", "fg": "#0f0",
                "input_bg": "rgba(0, 30, 0, 150)", "border": "#0f0",
                "btn_bg": "rgba(0, 100, 0, 200)", "btn_hover": "rgba(0, 150, 0, 255)"
            }
        }
        
        t = themes.get(theme_name, themes["Dark (Default)"])
        
        style = f"""
            QWidget {{
                background-color: {t['bg']};
                border-radius: 12px;
                color: {t['fg']};
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            }}
            QLineEdit, QComboBox {{
                background-color: {t['input_bg']};
                border: 1px solid {t['border']};
                padding: 10px;
                border-radius: 8px;
                font-size: 15px;
                color: {t['fg']};
            }}
            QTextEdit {{
                background-color: {t['input_bg']};
                border: 1px solid {t['border']};
                padding: 15px;
                border-radius: 8px;
                font-size: 16px;
                line-height: 1.5;
                color: {t['fg']};
            }}
            QPushButton {{
                background-color: {t['btn_bg']};
                border: 1px solid {t['border']};
                padding: 10px;
                border-radius: 8px;
                font-size: 16px;
                color: white;
            }}
            QPushButton:hover {{
                background-color: {t['btn_hover']};
            }}
        """
        self.container.setStyleSheet(style)

    def _position_at_cursor(self):
        from PyQt6.QtGui import QCursor
        cursor_pos = QCursor.pos()
        # Offset slightly so it doesn't appear exactly under the pointer
        self.move(cursor_pos.x() + 15, cursor_pos.y() + 15)

    def animate_thinking(self):
        self.animation_dots = (self.animation_dots + 1) % 4
        self.submit_button.setText("Thinking" + "." * self.animation_dots)

    def on_submit(self):
        prompt = self.input_field.text().strip()
        model = self.model_selector.currentText()
        if prompt:
            self.input_field.setEnabled(False)
            self.submit_button.setEnabled(False)
            
            # Start Animation
            self.animation_dots = 0
            self.submit_button.setText("Thinking")
            self.animation_timer.start(400) # update every 400ms
            
            # Emit signal
            self.submit_query.emit(prompt, model)

    def show_ready(self, selected_text=""):
        if not self.isVisible():
            self._position_at_cursor()
            
        self.input_field.setEnabled(True)
        self.input_field.clear()
        
        if selected_text:
            # Pre-fill or append the selected text as context
            self.input_field.setText(f"Edit this: '{selected_text.strip()}' -> ")
            
        self.input_field.setPlaceholderText("Ask Skibidysaurus (e.g., 'Make this concise')...")
        self.input_field.setFocus()
        self.submit_button.setEnabled(True)
        self.submit_button.setText("Submit")
        
        if not self.output_area.toPlainText().strip():
            self.output_area.clear()

        self.show()

    def show_result(self, result_text: str):
        # Stop Animation
        self.animation_timer.stop()
        
        self.input_field.setEnabled(True)
        self.submit_button.setEnabled(True)
        self.submit_button.setText("Submit")
        self.input_field.clear()
        self.input_field.setPlaceholderText("Ask follow up...")
        
        # Render markdown directly for more professional, clean output
        self.output_area.setMarkdown(result_text)
        # Ensure focus doesn't accidentally trigger another submit immediately
        self.input_field.setFocus()

    def keyPressEvent(self, event):
        # Escape key to cancel
        if event.key() == Qt.Key.Key_Escape:
            self.hide()
        else:
            super().keyPressEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.drag_position = event.globalPosition().toPoint() - self.frameGeometry().topLeft()

    def mouseMoveEvent(self, event):
        if event.buttons() == Qt.MouseButton.LeftButton:
            self.move(event.globalPosition().toPoint() - self.drag_position)

    def open_settings(self):
        settings_dialog = SettingsDialog(self)
        if settings_dialog.exec():
            # Apply new theme immediately!
            self.apply_theme()
            self.settings_saved.emit()
