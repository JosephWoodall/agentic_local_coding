#!/bin/bash

# ==========================================
# CONFIGURATION
# ==========================================
MODEL_REPO="bartowski/Qwen_Qwen3.6-35B-A3B-GGUF"
MODEL_FILE="Qwen_Qwen3.6-35B-A3B-Q2_K.gguf"
MODEL_DIR="$HOME/.cache/gguf"
MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
PORT=8080
# With 12GB VRAM, ~10GB is usable after CUDA overhead.
# Q2_K is 12.6GB total. Start at 48 layers on GPU, rest on CPU.
# Tune UP if no OOM, tune DOWN if you get CUDA OOM errors.
N_GPU_LAYERS=48
N_CTX=8192
VENV_DIR="$(pwd)/.venv"
PYTHON_VERSION="3.12"

echo "=========================================="
echo " Initializing Local Qwen3.6-35B-A3B Environment"
echo "=========================================="

# ==========================================
# 0. ENSURE PATH INCLUDES LOCAL BINARIES
# ==========================================
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# ==========================================
# 1. INSTALL UV + AIDER
# ==========================================
echo "⚙️  Checking Python Environment..."
if ! command -v uv &> /dev/null; then
    echo "📦 Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
fi

if ! uv tool list 2>/dev/null | grep -q "aider-chat"; then
    echo "📦 Installing Aider..."
    uv tool install aider-chat --python $PYTHON_VERSION
    echo "✅ Aider installed."
else
    echo "✅ Aider is ready."
fi

# ==========================================
# 2. SET UP .venv WITH PYTHON 3.12
# ==========================================
# Python 3.14 has poor wheel support for llama-cpp-python.
# Use Python 3.12 via uv for maximum compatibility.
NEED_RECREATE=false

if [ ! -d "$VENV_DIR" ]; then
    NEED_RECREATE=true
elif [ -f "$VENV_DIR/bin/python3" ]; then
    CURRENT_PY=$("$VENV_DIR/bin/python3" --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1)
    if [ "$CURRENT_PY" != "$PYTHON_VERSION" ]; then
        echo "⚠️  Existing venv is Python $CURRENT_PY, need $PYTHON_VERSION. Recreating..."
        NEED_RECREATE=true
    fi
fi

if [ "$NEED_RECREATE" = true ]; then
    echo "🐍 Creating Python $PYTHON_VERSION virtual environment via uv..."
    rm -rf "$VENV_DIR"
    uv venv --python "$PYTHON_VERSION" "$VENV_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create venv. uv may need to download Python $PYTHON_VERSION first."
        echo "   Try: uv python install $PYTHON_VERSION"
        exit 1
    fi
fi

source "$VENV_DIR/bin/activate"
echo "✅ Using Python: $(python3 --version) at $(which python3)"

# ==========================================
# 3. INSTALL llama-cpp-python
# ==========================================
# Use 'uv pip' for all installs — uv-created venvs don't include pip.
if ! python3 -c "import llama_cpp" &> /dev/null; then
    echo "📦 Installing llama-cpp-python..."

    # Attempt CUDA build if nvcc is available
    CUDA_BUILD=false
    if command -v nvcc &> /dev/null; then
        echo "   🟢 CUDA toolkit (nvcc) found. Building with CUDA support..."
        CUDA_BUILD=true
    elif [ -f "/opt/cuda/bin/nvcc" ]; then
        export PATH="/opt/cuda/bin:$PATH"
        export CUDA_HOME="/opt/cuda"
        echo "   🟢 CUDA toolkit found at /opt/cuda. Building with CUDA support..."
        CUDA_BUILD=true
    else
        echo "   ⚠️  CUDA toolkit (nvcc) not found."
        echo "   💡 For GPU acceleration, install the CUDA toolkit:"
        echo "      sudo pacman -S cuda       (Arch/CachyOS)"
        echo "      Then re-run this script."
        echo ""
        echo "   Proceeding with CPU-only build..."
        echo "   (MoE model activates only 3B params — CPU is usable with 40GB RAM)"
    fi

    if [ "$CUDA_BUILD" = true ]; then
        CMAKE_ARGS="-DGGML_CUDA=on" uv pip install llama-cpp-python[server] --no-cache
    else
        uv pip install llama-cpp-python[server] --no-cache
    fi

    if ! python3 -c "import llama_cpp" &> /dev/null; then
        echo "❌ llama-cpp-python installation failed."
        echo "   Try installing build dependencies:"
        echo "     sudo pacman -S cmake gcc base-devel"
        exit 1
    fi
    echo "✅ llama-cpp-python installed."
else
    echo "✅ llama-cpp-python is ready."
fi

# ==========================================
# 4. DOWNLOAD GGUF (one-time, ~12.6GB)
# ==========================================
mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL_PATH" ]; then
    echo "📥 Downloading $MODEL_FILE (~12.6GB, one-time)..."

    # Ensure hf CLI is available (huggingface-cli is deprecated)
    if ! command -v hf &> /dev/null; then
        uv pip install huggingface_hub
    fi

    hf download "$MODEL_REPO" "$MODEL_FILE" \
        --local-dir "$MODEL_DIR"

    if [ ! -f "$MODEL_PATH" ]; then
        echo "❌ Download failed or file not found at $MODEL_PATH"
        echo "   Check your internet connection and try again."
        exit 1
    fi
    echo "✅ Model downloaded."
else
    echo "✅ Model already cached at $MODEL_PATH"
fi

# ==========================================
# 5. START llama-cpp SERVER
# ==========================================
if pgrep -f "llama_cpp.server" > /dev/null; then
    echo "✅ llama-cpp server is already running."
else
    echo "⏳ Starting llama-cpp server..."
    echo "   GPU layers: $N_GPU_LAYERS / CPU handles remainder"
    echo "   Context: $N_CTX tokens"
    echo "   (Run 'tail -f llama-server.log' to monitor)"

    python3 -m llama_cpp.server \
        --model "$MODEL_PATH" \
        --n_gpu_layers $N_GPU_LAYERS \
        --n_ctx $N_CTX \
        --n_threads $(nproc) \
        --port $PORT \
        --host 127.0.0.1 \
        > llama-server.log 2>&1 &

    echo "🧠 Loading model weights..."
    until curl -s "http://127.0.0.1:$PORT/health" > /dev/null 2>&1; do
        if ! pgrep -f "llama_cpp.server" > /dev/null; then
            echo ""
            echo "❌ Server crashed. Last 20 lines of log:"
            tail -20 llama-server.log
            echo ""
            echo "💡 If you see CUDA OOM, reduce N_GPU_LAYERS in this script and retry."
            exit 1
        fi
        echo -n "."
        sleep 3
    done
    echo " ready!"
fi

# ==========================================
# 6. LAUNCH AIDER
# ==========================================
echo "🚀 Launching Aider..."
echo "=========================================="

export OPENAI_API_BASE="http://127.0.0.1:$PORT/v1"
export OPENAI_API_KEY="none"

exec aider \
    --model "openai/$MODEL_FILE" \
    --openai-api-base "http://127.0.0.1:$PORT/v1" \
    --openai-api-key "none" \
    --no-stream