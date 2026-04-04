#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="$SCRIPT_DIR/models"
WEB_DIR="$SCRIPT_DIR/web"
LLAMA_PORT="${LLAMA_PORT:-8080}"
GPU_LAYERS="${GPU_LAYERS:-0}"
CTX_SIZE="${CTX_SIZE:-8192}"
LLAMA_SERVER_PID=""
OPEN_WEB=false
LOG_FILE="/tmp/llama-server.log"

# Prefer a local binary (newer version) over system install
if [ -x "$SCRIPT_DIR/bin/llama-server" ]; then
    LLAMA_BIN="$SCRIPT_DIR/bin/llama-server"
else
    LLAMA_BIN="llama-server"
fi

# ── Parse flags ────────────────────────────────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --web) OPEN_WEB=true ;;
        --gpu) GPU_LAYERS=99; CTX_SIZE=32768 ;;
        --cpu) GPU_LAYERS=0;  CTX_SIZE=8192  ;;
    esac
done

# ── Find GGUF model ────────────────────────────────────────────────────────────
find_model() {
    if [ ! -d "$MODELS_DIR" ]; then
        echo "[error] No models/ directory found at $MODELS_DIR"
        echo "        Download a Gemma 4 GGUF and place it in models/"
        echo "        Example: .venv/bin/hf download ggml-org/gemma-4-E2B-it-GGUF --include '*Q4_K_M*' --local-dir models/"
        exit 1
    fi

    local model
    # Exclude .cache/ (HF incomplete downloads) and only match real .gguf files
    model=$(find "$MODELS_DIR" -type f -name "*.gguf" \
        ! -path "*/.cache/*" \
        ! -name "*.incomplete" \
        | sort | head -n 1)

    if [ -z "$model" ]; then
        echo "[error] No .gguf file found in $MODELS_DIR"
        echo "        Download a Gemma 4 GGUF, e.g.:"
        echo "          .venv/bin/hf download ggml-org/gemma-4-E2B-it-GGUF --include '*Q4_K_M*' --local-dir models/"
        exit 1
    fi

    echo "$model"
}

# ── Start llama-server ─────────────────────────────────────────────────────────
start_server() {
    local model="$1"
    local mode="CPU"
    [ "$GPU_LAYERS" -gt 0 ] && mode="GPU (${GPU_LAYERS} layers)"
    local ver
    ver=$("$LLAMA_BIN" --version 2>&1 | head -1 || echo "unknown")
    echo ""
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│            Gemma 4 · llama.cpp Engine               │"
    echo "└─────────────────────────────────────────────────────┘"
    echo "  Binary : $(basename "$LLAMA_BIN") ($ver)"
    echo "  Model  : $(basename "$model")"
    echo "  Mode   : $mode"
    echo "  Port   : $LLAMA_PORT"
    echo "  Context: $CTX_SIZE tokens"
    echo "  Log    : $LOG_FILE"
    echo ""

    "$LLAMA_BIN" \
        --model "$model" \
        --port "$LLAMA_PORT" \
        --host 127.0.0.1 \
        --n-gpu-layers "$GPU_LAYERS" \
        --ctx-size "$CTX_SIZE" \
        --parallel 4 \
        --cont-batching \
        > "$LOG_FILE" 2>&1 &
    LLAMA_SERVER_PID=$!
    echo "  [pid] llama-server started (PID $LLAMA_SERVER_PID)"
}

# ── Wait for server ready ──────────────────────────────────────────────────────
wait_for_server() {
    local timeout=300  # 5 minutes — large models on CPU take a while to load
    echo -n "  [wait] Loading model (may take several minutes on CPU)..."

    for i in $(seq 1 $timeout); do
        # Detect immediate crash — no point waiting
        if ! kill -0 "$LLAMA_SERVER_PID" 2>/dev/null; then
            echo ""
            echo "  [error] llama-server crashed! Last log output:"
            echo "  ─────────────────────────────────────────────"
            tail -25 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
            echo "  ─────────────────────────────────────────────"
            echo "  Full log: $LOG_FILE"
            cleanup
            exit 1
        fi

        if curl -s "http://127.0.0.1:$LLAMA_PORT/health" 2>/dev/null | grep -q '"status"'; then
            echo " ready! (${i}s)"
            return 0
        fi

        # Heartbeat every 30s so the user knows it's still working
        if (( i % 30 == 0 )); then
            echo -n " ${i}s..."
        else
            echo -n "."
        fi
        sleep 1
    done

    echo ""
    echo "  [error] llama-server did not become ready in ${timeout}s."
    echo "  Last log output:"
    tail -25 "$LOG_FILE" 2>/dev/null | sed 's/^/  /'
    echo "  Full log: $LOG_FILE"
    cleanup
    exit 1
}

# ── Ensure @ai-sdk/openai-compatible is installed ─────────────────────────────
ensure_npm_dep() {
    local OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
    if [ ! -d "$OPENCODE_CONFIG_DIR/node_modules/@ai-sdk/openai-compatible" ]; then
        echo "  [npm] Installing @ai-sdk/openai-compatible..."
        npm --prefix "$OPENCODE_CONFIG_DIR" install @ai-sdk/openai-compatible --silent 2>&1 && \
            echo "  [ok] @ai-sdk/openai-compatible installed." || \
            echo "  [warn] Failed to install @ai-sdk/openai-compatible — TUI provider may not work."
    else
        echo "  [skip] @ai-sdk/openai-compatible already installed."
    fi
}

# ── Cleanup ────────────────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo "Shutting down llama-server..."
    if [ -n "$LLAMA_SERVER_PID" ] && kill -0 "$LLAMA_SERVER_PID" 2>/dev/null; then
        kill "$LLAMA_SERVER_PID"
        wait "$LLAMA_SERVER_PID" 2>/dev/null
    fi
    echo "Engine shut down cleanly."
    exit 0
}

trap cleanup SIGINT SIGTERM EXIT

# ── Main ───────────────────────────────────────────────────────────────────────
MODEL=$(find_model)
start_server "$MODEL"
wait_for_server
ensure_npm_dep

echo ""
echo "----------------------------------------"

if $OPEN_WEB; then
    echo "  [web] Opening browser chat UI..."
    WEB_FILE="$WEB_DIR/index.html"
    if [ ! -f "$WEB_FILE" ]; then
        echo "  [error] web/index.html not found. Run without --web for TUI mode."
        cleanup
        exit 1
    fi
    if command -v xdg-open &>/dev/null; then
        xdg-open "file://$WEB_FILE" &
    elif command -v firefox &>/dev/null; then
        firefox "file://$WEB_FILE" &
    elif command -v chromium &>/dev/null; then
        chromium "file://$WEB_FILE" &
    fi
    echo "  Opened web/index.html in browser."
    echo "  llama-server is running at http://127.0.0.1:$LLAMA_PORT"
    echo "  Press Ctrl+C to stop."
    wait "$LLAMA_SERVER_PID"
else
    echo "  Gemma 4 is running. Launching OpenCode TUI..."
    echo ""

    if [ $# -eq 0 ] || [ "$1" = "--web" ]; then
        opencode
    elif [ -f "$1" ]; then
        echo "  Directing agent to execute $1..."
        opencode --prompt "Please read the instructions in the file '$1' and execute them step-by-step."
    else
        OPENCODE_ARGS=()
        for arg in "$@"; do
            [ "$arg" != "--web" ] && OPENCODE_ARGS+=("$arg")
        done
        opencode --prompt "${OPENCODE_ARGS[*]}"
    fi
fi