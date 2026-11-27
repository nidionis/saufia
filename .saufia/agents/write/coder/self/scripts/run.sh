#!/usr/bin/env bash
# Print the coder contract from its own config/prompt. No LLM.
cat "${AGENT_DIR:-.}/../prompt" 2>/dev/null || true
