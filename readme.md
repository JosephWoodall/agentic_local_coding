# Local Agentic Coding with OpenClaude

Run a fully local, private coding agent — like Claude Code or Gemini CLI — powered by your own hardware.

## Stack

| Component | Role |
|-----------|------|
| **[OpenClaude](https://github.com/Gitlawb/openclaude)** | Coding-agent CLI (tools, bash, file edit, grep, agents, MCP) |
| **[llama-cpp-python](https://github.com/abetlen/llama-cpp-python)** | OpenAI-compatible server for GGUF models |
| **Qwen2.5-Coder-14B (Q4_K_M)** | SOTA specialized coding model (fits fully in 12GB VRAM) |

## Quick Start

### 1. First-time setup

Clone this repo and run the setup script:

```bash
git clone https://github.com/YourUser/agentic_local_coding.git
cd agentic_local_coding
chmod +x run.sh localcode
./run.sh
```

This will:
- Install OpenClaude globally via npm
- Create a Python venv with llama-cpp-python (CUDA if available)
- Download the GGUF model (~9.1GB, one-time)
- Start the local server and launch OpenClaude

### 2. Use from any directory (the good stuff)

Install the global launcher:

```bash
ln -sf "$(pwd)/localcode" ~/.local/bin/localcode
```

Now from **any** terminal, in **any** codebase:

```bash
cd ~/projects/my-cool-app
localcode
```

That's it. Same workflow as `claude` or `gemini` — one command, full agentic coding.

### 3. Server management

Start just the backend (no client):

```bash
./run.sh --server-only
```

Check if the server is running:

```bash
curl http://127.0.0.1:8080/health
```

Stop the server:

```bash
pkill -f llama_cpp.server
```

## Model Configuration

Edit the top of `run.sh` to change models:

```bash
MODEL_REPO="bartowski/Qwen2.5-Coder-14B-Instruct-GGUF"
MODEL_FILE="Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf"
N_GPU_LAYERS=-1    # -1 means all layers on GPU
N_CTX=16384        # Context window
```

**Tip:** For a different model, also update `MODEL_FILE` in `localcode` to match.

## Requirements

- **Node.js >= 22** (for OpenClaude)
- **Python 3.12** (auto-managed via `uv`)
- **CUDA toolkit** (optional, for GPU acceleration)
- **ripgrep** (optional, for OpenClaude's grep tools)