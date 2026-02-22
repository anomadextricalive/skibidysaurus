#!/bin/bash
set -e

echo "🦖 Setting up Skibidysaurus..."
echo ""

# ── Step 1: Check Prerequisites ──
echo "📋 Checking prerequisites..."

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not found."
    echo "   Install it from https://python.org or via: brew install python3"
    exit 1
fi
echo "  ✅ Python 3 found: $(python3 --version)"

# Check Swift
if ! command -v swift &> /dev/null; then
    echo "❌ Swift compiler not found."
    echo "   Install Xcode Command Line Tools: xcode-select --install"
    exit 1
fi
echo "  ✅ Swift found: $(swift --version 2>&1 | head -1)"

# ── Step 2: Setup Python Virtual Environment ──
echo ""
echo "🐍 Setting up Python backend..."

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "  ✅ Created virtual environment"
fi

source venv/bin/activate
pip install -q -r requirements.txt
echo "  ✅ Python dependencies installed"

# ── Step 3: Create .env if missing ──
if [ ! -f ".env" ]; then
    echo "GEMINI_API_KEY=" > .env
    echo "HOVERGPT_THEME=Dark (Default)" >> .env
    echo "  ⚠️  Created .env — add your Gemini API key via the app Settings or edit .env"
fi

# ── Step 4: Clear Python Cache ──
find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
echo "  ✅ Cleared Python cache"

# ── Step 5: Build Swift App ──
echo ""
echo "🔨 Building Skibidysaurus native app..."
cd SkibidysaurusApp
swift build 2>&1
cd ..
echo "  ✅ Swift build complete"

# ── Step 6: Create a Launch Script ──
LAUNCH_SCRIPT="launch.sh"
cat > "$LAUNCH_SCRIPT" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/SkibidysaurusApp/.build/debug/Skibidysaurus" &
echo "🦖 Skibidysaurus is running! Look for the 🧠 icon in your menu bar."
echo "   Press Cmd+Option+G anywhere to summon the AI."
echo "   Click the 🧠 icon to toggle the overlay."
EOF
chmod +x "$LAUNCH_SCRIPT"
echo "  ✅ Created launch.sh"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  🦖 Skibidysaurus is ready!"
echo ""
echo "  To start:  ./launch.sh"
echo "  To stop:   Press Ctrl+C in this terminal"
echo ""
echo "  First time? Click the 🧠 icon → ⚙️ Settings"
echo "  → Paste your Gemini API Key → Save"
echo "═══════════════════════════════════════════════════"
