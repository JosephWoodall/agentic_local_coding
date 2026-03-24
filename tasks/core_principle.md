# This Repo's North Star

**Core Principle:** Local, private, agentic coding assistance with sophisticated reasoning—running an AI coding agent entirely on local hardware without cloud dependencies.

## The One-Sentence Essence
Self-hosted AI coding agent that maintains complete data sovereignty while delivering production-quality software engineering assistance.

## The Intuition
Cloud-based AI coding tools (GitHub Copilot, Cursor Cloud, Claude API) require sending source code to third-party servers, creating unacceptable trade-offs: privacy leakage, subscription costs, internet dependency, and latency. This repo rejects those trade-offs by running a capable reasoning model locally via Ollama, wrapped in an agentic scaffolding that provides structured planning, self-correction, and verification.

The magic is that local models have finally become capable enough to match cloud capabilities for most coding tasks—particularly the distilled reasoning variants that compress chain-of-thought patterns from frontier models into efficient architectures.

## Technical Foundations

- **GGUF Format**: GPT-Generated Unified Format enables efficient quantization and serving of large models on consumer hardware
- **Ollama**: Streamlined local LLM deployment with automatic GPU acceleration
- **Reasoning Distillation**: Models like Qwen3.5-27B distilled from Claude's chain-of-thought patterns provide strong reasoning with reasonable resource requirements
- **Agentic Scaffolding**: Structured workflows for planning, verification, and self-improvement

## Alternatives Rejected

| Alternative | Why It's Inferior |
|-------------|-------------------|
| Cloud-based AI assistants (Copilot, Cursor, Claude API) | Privacy violations, subscription costs, internet dependency, data sovereignty loss |
| Raw local models without agentic frameworks | Lacks structured reasoning, planning, verification, and self-correction mechanisms |
| Non-distilled base models | Too slow for interactive use; require impractical hardware |

## Alignment Verification

Every plan, code change, and verification step must satisfy:
1. Does it enhance local data privacy?
2. Does it reduce cloud dependency?
3. Does it maintain code quality standards?
4. Does it support the self-improvement loop?

**Drift from these principles requires immediate re-planning.**
