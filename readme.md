# Agentic Local Coding — Gemma 4 + llama.cpp

A self-hosted AI coding agent with complete data sovereignty.  
Backend: **llama.cpp** (`llama-server`) · Model: **Gemma 4** (Google, Apache 2.0)

---

## Quick Start

### 0. Set up Python venv (first time only)

```bash
python3 -m venv .venv
.venv/bin/pip install -q huggingface-hub
```

### 1. Download a Gemma 4 GGUF model

```bash
# Best for coding — 26B MoE, 4B active params (~16 GB Q4_K_M) ← recommended
mkdir -p models
.venv/bin/hf download ggml-org/gemma-4-26B-A4B-it-GGUF \
  --include "*Q4_K_M*" --local-dir models/

# Smallest / fastest (5B, ~3 GB) — if limited VRAM
.venv/bin/hf download ggml-org/gemma-4-E2B-it-GGUF \
  --include "*Q4_K_M*" --local-dir models/

# Better quality (8B, ~5 GB)
.venv/bin/hf download ggml-org/gemma-4-E4B-it-GGUF \
  --include "*Q4_K_M*" --local-dir models/
```

Place any `.gguf` file anywhere inside `models/`. The engine auto-detects it.

### 2. Terminal mode (OpenCode TUI)

```bash
./start-engine.sh                         # Interactive TUI
./start-engine.sh agent_instructions.md  # Execute a task file
./start-engine.sh "your prompt here"     # One-shot prompt
```

### 3. Web mode (browser chat UI)

```bash
./start-engine.sh --web
```

Opens `web/index.html` in your browser — a streaming chat interface
that connects to the local llama-server API.

---

## Configuration

| Environment Variable | Default | Description |
|----------------------|---------|-------------|
| `GPU_LAYERS` | `99` | Layers to offload to GPU (0 = CPU only) |
| `CTX_SIZE`   | `32768` | Context window in tokens (max 131072) |
| `LLAMA_PORT` | `8080`  | Port for llama-server |

```bash
GPU_LAYERS=35 CTX_SIZE=65536 ./start-engine.sh
```

---

## Models

Models must be `.gguf` format and placed in `models/`.  
The first `.gguf` found (alphabetical) will be used.

| Model | Params | VRAM (Q4_K_M) | Quality |
|-------|--------|---------------|---------|
| gemma-4-E2B-it | 5B | ~3 GB | Good |
| gemma-4-E4B-it | 8B | ~5 GB | Better |
| gemma-4-26B-A4B-it | 26B (4B active) | ~16 GB | Excellent |
| gemma-4-31B-it | 31B | ~20 GB | Best |

---

## Architecture

```
llama-server (llama.cpp, port 8080)
  ├── OpenAI-compatible REST API (/v1/chat/completions)
  ├── Terminal: opencode TUI → reads opencode.json
  └── Web:     web/index.html → fetch() streaming
```

The API is fully OpenAI-compatible, so any OpenAI-SDK client works out of the box.
