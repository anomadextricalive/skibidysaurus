import sys
import argparse
import base64
from llm.clients import LLMManager

def get_ai_response(
    prompt: str,
    context: str = "",
    screenshot_path: str = "",
    engine: str = "gemini",
    ollama_model: str = "llava"
):
    llm_manager = LLMManager()
    
    # Pre-pend context if available (from clipboard/highlight)
    full_prompt = prompt
    if context:
        full_prompt = f"Edit this: '{context}' -> \n\nQuery: {prompt}"

    try:
        # Use the screenshot path if provided by Swift, otherwise capture ourselves
        if screenshot_path:
            with open(screenshot_path, "rb") as f:
                base64_image = base64.b64encode(f.read()).decode("utf-8")
        else:
            from core.capture import capture_screen_base64
            base64_image = capture_screen_base64()
        
        # Call selected engine
        response = llm_manager.get_response(
            full_prompt,
            base64_image,
            engine=engine,
            ollama_model=ollama_model
        )
        return response
    except Exception as e:
        return f"Error: {e}"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Skibidysaurus AI Backend")
    parser.add_argument("--prompt", required=True, type=str, help="The user's query.")
    parser.add_argument("--context", required=False, type=str, default="", help="Highlighted text context.")
    parser.add_argument("--screenshot", required=False, type=str, default="", help="Path to screenshot JPEG taken by Swift.")
    parser.add_argument("--engine", required=False, type=str, default="gemini", choices=["gemini", "ollama"], help="Inference engine.")
    parser.add_argument("--ollama-model", required=False, type=str, default="llava", help="Local Ollama model to use.")
    
    args = parser.parse_args()
    
    print(get_ai_response(
        args.prompt,
        args.context,
        args.screenshot,
        engine=args.engine,
        ollama_model=args.ollama_model
    ))
