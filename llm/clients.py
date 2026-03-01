import os
import requests
from google import genai
from google.genai import types
from dotenv import load_dotenv

# Load API Key from .env
load_dotenv()

class LLMManager:
    def __init__(self):
        self.gemini_client = None
        self._init_gemini_client_if_available()

    def refresh_config(self):
        """Re-initializes the Gemini client if the API key environment variable changed"""
        self._init_gemini_client_if_available()

    def _init_gemini_client_if_available(self):
        api_key = (os.environ.get("GEMINI_API_KEY", "") or "").strip()
        if not api_key:
            self.gemini_client = None
            return
        self.gemini_client = genai.Client(api_key=api_key)

    def get_response(
        self,
        prompt: str,
        base64_image: str,
        engine: str = "gemini",
        ollama_model: str = "llava:latest",
        openai_model: str = "gpt-4.1-mini",
        claude_model: str = "claude-3-5-haiku-latest",
    ) -> str:
        """
        Sends the user prompt and screen context to the selected AI engine.
        Returns the typed-out response.
        """
        system_prompt = (
            "You are Skibidysaurus, a sophisticated AI assistant seamlessly integrated into the user's environment. "
            "You are provided with a screenshot of the user's current screen and their query. "
            "Always provide a beautifully written, highly professional, and perfectly phrased answer. "
            "Keep your output extremely clean, well-structured, and concise. "
            "Format your responses using Markdown (bullet points, bold text, code blocks) to make them highly readable. "
            "If they ask for a rewrite or code, provide the exact snippet directly."
        )

        if engine == "gemini":
            return self._call_gemini(system_prompt, prompt, base64_image)
        elif engine == "ollama":
            return self._call_ollama(system_prompt, prompt, base64_image, ollama_model)
        elif engine == "openai":
            return self._call_openai(system_prompt, prompt, base64_image, openai_model)
        elif engine == "claude":
            return self._call_claude(system_prompt, prompt, base64_image, claude_model)
        else:
            return "Error: Unknown AI engine selected."

    def _call_gemini(self, system_prompt: str, user_prompt: str, base64_image: str) -> str:
        try:
            if self.gemini_client is None:
                self._init_gemini_client_if_available()
            if self.gemini_client is None:
                return "Gemini Error: missing API key. Add it in Settings."

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
            # print(f"[DEBUG] Gemini responded with {len(response_text)} chars: {response_text[:50]}")
            return response_text
        except Exception as e:
            # print(f"[ERROR] Gemini API failed: {e}")
            return f"Gemini Error: {str(e)}"

    def _call_ollama(self, system_prompt: str, user_prompt: str, base64_image: str, ollama_model: str) -> str:
        generate_url = "http://localhost:11434/api/generate"
        tags_url = "http://localhost:11434/api/tags"
        model_name = (ollama_model or "").strip() or "llava:latest"
        base_payload = {
            "model": model_name,
            "system": system_prompt,
            "prompt": user_prompt,
            "stream": False
        }

        with_image_payload = dict(base_payload)
        if base64_image:
            with_image_payload["images"] = [base64_image]

        text_only_payload = dict(base_payload)

        def _installed_models() -> list[str]:
            try:
                tags_res = requests.get(tags_url, timeout=8)
                tags_res.raise_for_status()
                data = tags_res.json()
                models = data.get("models", [])
                return [m.get("name", "") for m in models if m.get("name")]
            except Exception:
                return []

        def _post_generate(payload: dict) -> str:
            res = requests.post(generate_url, json=payload, timeout=120)
            res.raise_for_status()
            data = res.json()
            response = data.get("response", "").strip()
            if not response:
                return f"Ollama Error: model '{model_name}' returned an empty response."
            return response

        def _is_image_not_supported_error(err: requests.exceptions.HTTPError) -> bool:
            body = ""
            if err.response is not None:
                try:
                    parsed = err.response.json()
                    body = str(parsed.get("error", ""))
                except Exception:
                    body = err.response.text or ""
            body = body.lower()
            return (
                "does not support images" in body
                or "image input is not supported" in body
                or "vision" in body and "not support" in body
            )

        try:
            if "images" in with_image_payload:
                try:
                    return _post_generate(with_image_payload)
                except requests.exceptions.HTTPError as e:
                    # Common failure path: text-only local models cannot handle image fields.
                    if _is_image_not_supported_error(e):
                        fallback = _post_generate(text_only_payload)
                        return (
                            fallback
                            + "\n\n_note: your selected ollama model is text-only, so screen image context was skipped._"
                        )
                    raise
            return _post_generate(text_only_payload)
        except requests.exceptions.ConnectionError:
            return "Ollama Error: Could not connect to local Ollama instance at http://localhost:11434. Start Ollama first."
        except requests.exceptions.HTTPError as e:
            installed = _installed_models()
            installed_hint = f" Installed models: {', '.join(installed)}." if installed else ""
            return (
                f"Ollama Error: {e}. Make sure model '{model_name}' exists "
                f"(try: ollama pull {model_name}).{installed_hint}"
            )
        except Exception as e:
            return f"Ollama Error: {str(e)}"

    def _call_openai(self, system_prompt: str, user_prompt: str, base64_image: str, openai_model: str) -> str:
        api_key = (os.environ.get("OPENAI_API_KEY", "") or "").strip()
        if not api_key:
            return "OpenAI Error: missing API key. Add it in Settings."

        model_name = (openai_model or "").strip() or "gpt-4.1-mini"
        url = "https://api.openai.com/v1/responses"
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }

        content = [{"type": "input_text", "text": user_prompt}]
        if base64_image:
            content.append({
                "type": "input_image",
                "image_url": f"data:image/jpeg;base64,{base64_image}"
            })

        payload = {
            "model": model_name,
            "input": [{
                "role": "user",
                "content": content
            }],
            "instructions": system_prompt,
            "temperature": 0.4,
        }

        try:
            res = requests.post(url, headers=headers, json=payload, timeout=120)
            res.raise_for_status()
            data = res.json()
            response = (data.get("output_text") or "").strip()
            if not response:
                return f"OpenAI Error: model '{model_name}' returned an empty response."
            return response
        except requests.exceptions.HTTPError as e:
            detail = ""
            if e.response is not None:
                try:
                    detail = str(e.response.json())
                except Exception:
                    detail = e.response.text or ""
            return f"OpenAI Error: {e}. {detail}".strip()
        except Exception as e:
            return f"OpenAI Error: {str(e)}"

    def _call_claude(self, system_prompt: str, user_prompt: str, base64_image: str, claude_model: str) -> str:
        api_key = (os.environ.get("ANTHROPIC_API_KEY", "") or "").strip()
        if not api_key:
            return "Claude Error: missing API key. Add it in Settings."

        model_name = (claude_model or "").strip() or "claude-3-5-haiku-latest"
        url = "https://api.anthropic.com/v1/messages"
        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        }

        content = [{"type": "text", "text": user_prompt}]
        if base64_image:
            content.insert(0, {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64_image,
                },
            })

        payload = {
            "model": model_name,
            "max_tokens": 1200,
            "temperature": 0.4,
            "system": system_prompt,
            "messages": [{"role": "user", "content": content}],
        }

        try:
            res = requests.post(url, headers=headers, json=payload, timeout=120)
            res.raise_for_status()
            data = res.json()
            blocks = data.get("content", [])
            texts = [b.get("text", "") for b in blocks if b.get("type") == "text" and b.get("text")]
            response = "\n".join(texts).strip()
            if not response:
                return f"Claude Error: model '{model_name}' returned an empty response."
            return response
        except requests.exceptions.HTTPError as e:
            detail = ""
            if e.response is not None:
                try:
                    detail = str(e.response.json())
                except Exception:
                    detail = e.response.text or ""
            return f"Claude Error: {e}. {detail}".strip()
        except Exception as e:
            return f"Claude Error: {str(e)}"
