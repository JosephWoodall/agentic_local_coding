#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_DIR="$SCRIPT_DIR/models"

echo "Starting Ollama service..."
sudo systemctl start ollama

# Wait for Ollama to be ready
for i in $(seq 1 10); do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        break
    fi
    echo "Waiting for Ollama to be ready... ($i/10)"
    sleep 1
done

# Auto-register any GGUF models that have a Modelfile — recreate if Modelfile changed
if [ -d "$MODELS_DIR" ]; then
    echo "Scanning models/ for Modelfiles to auto-register..."
    while IFS= read -r -d '' modelfile; do
        model_dir="$(dirname "$modelfile")"
        dir_name="$(basename "$model_dir")"
        # Derive a clean Ollama tag: lowercase, replace spaces/underscores/dots with hyphens
        tag="$(echo "$dir_name" | tr '[:upper:]' '[:lower:]' | tr ' _.' '-' | tr -s '-')"
        hash_file="$model_dir/.modelfile.sha256"

        # Compute current hash of the Modelfile
        current_hash=$(sha256sum "$modelfile" 2>/dev/null | awk '{print $1}')
        stored_hash=$(cat "$hash_file" 2>/dev/null || echo "")

        # Check if registered in Ollama
        is_registered=false
        if ollama list 2>/dev/null | awk '{print $1}' | grep -q "^${tag}:"; then
            is_registered=true
        fi

        if $is_registered && [ "$current_hash" = "$stored_hash" ]; then
            echo "  [skip] '$tag' already registered and Modelfile unchanged."
        else
            if $is_registered; then
                echo "  [update] Modelfile changed — recreating '$tag'..."
            else
                echo "  [register] Creating Ollama model '$tag'..."
            fi
            (cd "$model_dir" && ollama create "$tag" -f Modelfile)
            if [ $? -eq 0 ]; then
                echo "$current_hash" > "$hash_file"
                echo "  [ok] '$tag' registered successfully."
            else
                echo "  [warn] Failed to register '$tag'. Check $modelfile"
            fi
        fi
    done < <(find "$MODELS_DIR" -name "Modelfile" -print0)
fi

# Ensure the @ai-sdk/openai-compatible npm package is installed for the custom Ollama provider
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
if [ ! -d "$OPENCODE_CONFIG_DIR/node_modules/@ai-sdk/openai-compatible" ]; then
    echo "Installing @ai-sdk/openai-compatible for OpenCode custom provider..."
    npm --prefix "$OPENCODE_CONFIG_DIR" install @ai-sdk/openai-compatible --silent 2>&1 && \
        echo "  [ok] @ai-sdk/openai-compatible installed." || \
        echo "  [warn] Failed to install @ai-sdk/openai-compatible — custom Ollama provider may not work."
else
    echo "  [skip] @ai-sdk/openai-compatible already installed."
fi

echo "----------------------------------------"

# Function to clean up and stop the service
cleanup() {
    echo -e "\nStopping Ollama service..."
    sudo systemctl stop ollama
    echo "Engine shut down cleanly."
    exit 0
}

# Trap Ctrl+C (SIGINT) and script exit to trigger the cleanup
trap cleanup SIGINT EXIT

echo "Ollama is running. Launching OpenCode..."

# If no arguments are passed, just launch the TUI normally
if [ $# -eq 0 ]; then
    opencode
# If the first argument is a file that exists, tell the agent to read it
elif [ -f "$1" ]; then
    echo "Directing agent to execute $1..."
    opencode --prompt "Please read the instructions in the file '$1' and execute them step-by-step."
# If it's just regular text, pass it as a prompt
else
    opencode --prompt "$*"
fi