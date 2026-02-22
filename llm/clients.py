import os
import requests
import json
from google import genai
from google.genai import types
from dotenv import load_dotenv

# Load API Key from .env
load_dotenv()

class LLMManager:
    def __init__(self):
        self.gemini_client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY", ""))

    def refresh_config(self):
        """Re-initializes the Gemini client if the API key environment variable changed"""
        self.gemini_client = genai.Client(api_key=os.environ.get("GEMINI_API_KEY", ""))

    def get_response(self, prompt: str, base64_image: str, engine: str = "gemini") -> str:
        """
        Sends the user prompt and screen context to the selected AI engine.
        Returns the typed-out response.
        """
        system_prompt = (
            "You are HoverGPT, a sophisticated AI assistant seamlessly integrated into the user's environment. "
            "You are provided with a screenshot of the user's current screen and their query. "
            "Always provide a beautifully written, highly professional, and perfectly phrased answer. "
            "Keep your output extremely clean, well-structured, and concise. "
            "Format your responses using Markdown (bullet points, bold text, code blocks) to make them highly readable. "
            "If they ask for a rewrite or code, provide the exact snippet directly."
        )

        if engine == "gemini":
            return self._call_gemini(system_prompt, prompt, base64_image)
        elif engine == "ollama":
            # For Ollama, we check if the user has a vision model like llava installed locally.
            return self._call_ollama(system_prompt, prompt, base64_image)
        else:
            return "Error: Unknown AI engine selected."

    def _call_gemini(self, system_prompt: str, user_prompt: str, base64_image: str) -> str:
        try:
            import base64
            # Google GenAI SDK expects raw bytes for image Part
            image_bytes = base64.b64decode(base64_image)
            response = self.gemini_client.models.generate_content(
                model='gemini-2.5-flash',
                contents=[
                    types.Part.from_bytes(data=image_bytes, mime_type='image/jpeg'),
                    user_prompt
                ],
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    temperature=0.4, # keep it somewhat strict to prompt
                )
            )
            response_text = response.text.strip()
            print(f"[DEBUG] Gemini responded with {len(response_text)} chars: {response_text[:50]}")
            return response_text
        except Exception as e:
            print(f"[ERROR] Gemini API failed: {e}")
            return f"Gemini Error: {str(e)}"

    def _call_ollama(self, system_prompt: str, user_prompt: str, base64_image: str) -> str:
        # Assuming typical local Ollama API running on port 11434
        url = "http://localhost:11434/api/generate"
        payload = {
            "model": "llava", # Must be a vision model to understand the screenshot
            "system": system_prompt,
            "prompt": user_prompt,
            "images": [base64_image],
            "stream": False
        }
        try:
            res = requests.post(url, json=payload, timeout=30)
            res.raise_for_status()
            data = res.json()
            return data.get("response", "").strip()
        except requests.exceptions.ConnectionError:
            return "Ollama Error: Could not connect to local Ollama instance."
        except Exception as e:
            return f"Ollama Error: {str(e)}"
