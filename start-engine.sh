#!/bin/bash

echo "Starting Ollama service..."
sudo systemctl start ollama

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
echo "----------------------------------------"

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