#!/usr/bin/env bash
# stdin = expression. bc does the math. No LLM.
expr="$(cat)"
expr="${expr#ask }"
printf '%s\n' "$expr" | bc -l
