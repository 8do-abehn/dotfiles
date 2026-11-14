#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp>=2.3,<3", "httpx>=0.27"]
# ///
"""MCP server that lets Claude Code hand work to a local Ollama model.

Useful for private or bulk grunt work: the local model reads the data, so it
never leaves the homelab, and Claude only sees the short answer.

Config comes from the environment, so no hostnames live in this public repo:
  LOCAL_LLM_URL    Ollama base URL, e.g. https://ollama.<tailnet>.ts.net (required)
  LOCAL_LLM_MODEL  default model (default: mimo-v2.6:9b)
  LOCAL_LLM_CTX    context window in tokens (default: 8192)
"""

import logging
import os
from pathlib import Path

import httpx
from mcp.server.mcpserver import MCPServer

BASE_URL = os.environ.get("LOCAL_LLM_URL", "").rstrip("/")
DEFAULT_MODEL = os.environ.get("LOCAL_LLM_MODEL", "mimo-v2.6:9b")
NUM_CTX = int(os.environ.get("LOCAL_LLM_CTX", "8192"))

# The GPU reads prompts at roughly 190 tokens/s, so a full 8k context takes
# about 45s before the first output token. Leave plenty of headroom.
TIMEOUT = httpx.Timeout(600.0, connect=10.0)

# Rough guard so a huge file fails fast instead of being silently truncated by
# the model's context window. About 3 characters per token, minus room for the
# instruction and the answer.
MAX_FILE_CHARS = (NUM_CTX - 1500) * 3

# httpx logs every request URL at INFO; keep the MCP log quiet.
logging.getLogger("httpx").setLevel(logging.WARNING)

mcp = MCPServer("local-llm")


async def _chat(messages: list[dict], model: str, max_tokens: int) -> str:
    if not BASE_URL:
        return "LOCAL_LLM_URL is not set; register the server with -e LOCAL_LLM_URL=..."
    body = {
        "model": model,
        "messages": messages,
        "stream": False,
        # Reasoning output roughly doubles the wait for little gain on grunt work.
        "think": False,
        "options": {"num_ctx": NUM_CTX, "num_predict": max_tokens},
    }
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        r = await client.post(f"{BASE_URL}/api/chat", json=body)
        r.raise_for_status()
        d = r.json()
    stats = (
        f"[{model}: {d.get('prompt_eval_count', 0)} prompt tokens, "
        f"{d.get('eval_count', 0)} output tokens, "
        f"{d.get('total_duration', 0) / 1e9:.1f}s]"
    )
    return f"{d['message']['content']}\n\n{stats}"


@mcp.tool()
async def ask(prompt: str, system: str = "", model: str = "", max_tokens: int = 1024) -> str:
    """Send a prompt to the local LLM on the homelab GPU and return its answer.

    A small (~9B) model: fine for summarizing, extracting, classifying,
    rewriting and simple questions; weak at multi-step reasoning and code
    review. Use it for private data that should stay in the homelab, or for
    bulk work not worth spending Claude tokens on.
    """
    messages = [{"role": "system", "content": system}] if system else []
    messages.append({"role": "user", "content": prompt})
    return await _chat(messages, model or DEFAULT_MODEL, max_tokens)


@mcp.tool()
async def ask_about_file(path: str, instruction: str, model: str = "", max_tokens: int = 1024) -> str:
    """Have the local LLM read a local text file and follow an instruction about it.

    The file content goes only to the homelab model, never to Claude, so use
    this for logs, drafts, or exports that may hold personal data, e.g.
    "list any names, emails or addresses" or "summarize the errors".
    Files larger than the context window are refused rather than truncated.
    """
    p = Path(path).expanduser()
    if not p.is_file():
        return f"Not a file: {p}"
    text = p.read_text(errors="replace")
    if len(text) > MAX_FILE_CHARS:
        return (
            f"{p} is {len(text)} characters; the limit at LOCAL_LLM_CTX={NUM_CTX} is "
            f"about {MAX_FILE_CHARS}. Split it, or pass a smaller excerpt to ask."
        )
    messages = [
        {"role": "system", "content": "Answer using only the file below. Be concise."},
        {"role": "user", "content": f"File: {p.name}\n\n{text}\n\n---\n{instruction}"},
    ]
    return await _chat(messages, model or DEFAULT_MODEL, max_tokens)


@mcp.tool()
async def models() -> str:
    """List the models available on the local Ollama server."""
    if not BASE_URL:
        return "LOCAL_LLM_URL is not set"
    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        r = await client.get(f"{BASE_URL}/api/tags")
        r.raise_for_status()
    names = [m["name"] for m in r.json().get("models", [])]
    return f"default: {DEFAULT_MODEL}\navailable: {', '.join(names)}"


if __name__ == "__main__":
    mcp.run()
