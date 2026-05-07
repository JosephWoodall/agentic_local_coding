#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
MODEL_PATH="$HOME/Downloads/Qwen3.5-27B.Q8_0.gguf"
PORT=8080

echo "=========================================="
echo " Initializing Local Qwen Development Environment"
echo "=========================================="

# ==========================================
# 1. VERIFY MODEL
# ==========================================
if [ ! -f "$MODEL_PATH" ]; then
    echo "❌ Error: Could not find the model at $MODEL_PATH"
    exit 1
fi

# ==========================================
# 2. INSTALL UV + AIDER
# ==========================================
echo "⚙️  Checking Python Environment..."

# Install uv if not present (handles its own Python — no system Python dependency)
if ! command -v uv &> /dev/null; then
    echo "📦 Installing uv (fast Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to PATH for the rest of this session
    export PATH="$HOME/.local/bin:$PATH"
fi

# Install aider via uv tool (pins Python 3.12, no compile step)
if ! uv tool list 2>/dev/null | grep -q "aider-chat"; then
    echo "📦 Installing Aider via uv (uses Python 3.12, pre-built wheels)..."
    uv tool install aider-chat --python 3.12
    echo "✅ Aider installed."
else
    echo "✅ Aider is ready."
fi

# Ensure uv-managed tools are on PATH
export PATH="$HOME/.local/bin:$PATH"

# ==========================================
# 3. MANAGE INFERENCE ENGINE
# ==========================================
if pgrep -x "llama-server" > /dev/null; then
    echo "✅ llama-server is already running."
else
    echo "⏳ Starting llama-server in the background..."
    llama-server -m "$MODEL_PATH" --port $PORT --ctx-size 8192 > llama-server.log 2>&1 &

    echo "🧠 Loading Q8 weights into RAM/VRAM (this takes 5-15 seconds)..."
    sleep 10
fi

# ==========================================
# 4. CREATE OPENCLAUDE BACKUP LAUNCHER
# ==========================================
cat <<EOF > launch_openclaude.sh
#!/bin/bash
export CLAUDE_CODE_USE_OPENAI=1
export OPENAI_BASE_URL="http://127.0.0.1:$PORT/v1"
export OPENAI_API_KEY="none"
export OPENAI_MODEL="qwen"
openclaude
EOF
chmod +x launch_openclaude.sh

# ==========================================
# 5. LAUNCH AIDER (FOREGROUND)
# ==========================================
echo "🚀 Dropping you into Aider..."
echo "=========================================="

export OPENAI_API_BASE="http://127.0.0.1:$PORT/v1"
export OPENAI_API_KEY="none"

exec aider --model openai/qwen