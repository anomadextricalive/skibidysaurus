#!/bin/bash

echo "🚀 Setting up HoverGPT..."

# Check for Python 3
if ! command -v python3 &> /dev/null
then
    echo "❌ Python 3 is required but not found. Please install Python 3 and try again."
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate

# Install dependencies
echo "📚 Installing dependencies..."
pip install -r requirements.txt

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "🔑 Creating .env file..."
    echo "GEMINI_API_KEY=" > .env
    echo "HOVERGPT_THEME=Dark (Default)" >> .env
    echo "⚠️ Please add your Gemini API Key to the .env file or via the UI Settings."
fi

echo "✅ Setup complete! You can now start HoverGPT by running:"
echo "   source venv/bin/activate"
echo "   python main.py"
