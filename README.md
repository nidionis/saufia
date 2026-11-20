# digest

`digest.py` densifies a source tree, archives the digest mirror, and routes
queries to relevant source files before calling an Ollama or OpenAI-compatible
LLM.

```bash
python3 digest.py densify --ratio 0.1
python3 digest.py archive
python3 digest.py stats
python3 digest.py ask "question"
python3 digest.py ask --route-only "question"
```

Configuration is loaded in increasing priority: `/etc/digest/digest.conf`,
`~/.config/digest/digest.conf`, `--env`/`.env/digest.env`, then environment
variables.