#!/bin/bash
export OPENAI_API_BASE="http://127.0.0.1:8080/v1"
export OPENAI_API_KEY="none"
echo "Starting Aider (connected to Q8 on port 8080)..."
aider --model openai/qwen
