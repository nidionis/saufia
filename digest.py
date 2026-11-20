#!/usr/bin/env python3
"""Digest a source tree and route queries to relevant files."""

import argparse
import configparser
import json
import os
import re
import sys
import tarfile
import time
import urllib.error
import urllib.request
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterator

try:
    import sacremoses
    _HAS_MOSES = True
except ImportError:
    _HAS_MOSES = False


@dataclass
class Config:
    semantic_ratio: float = 0.1
    tolerance: float = 0.3
    lambda_mmr: float = 0.7
    min_sentence_words: int = 5
    lang: str = "fr"
    source_root: Path = field(default_factory=lambda: Path.home() / "context")
    corpus_root: Path = field(default_factory=lambda: Path("/var/lib/digest"))
    archive_dir: Path = field(default_factory=lambda: Path("/var/lib/digest/.archive"))
    top_k_files: int = 3
    max_context_chars: int = 8000
    min_score: float = 0.02
    llm_host: str = "127.0.0.1:11434"
    llm_model: str = ""
    llm_api: str = "ollama"
    llm_api_key: str = ""
    llm_temperature: float = 0.3
    llm_top_p: float = 0.9
    llm_top_k: int = 40
    llm_max_tokens: int = 512
    llm_repeat_penalty: float = 1.1
    llm_ctx: int = 4096
    llm_timeout: float = 120.0
    llm_system: str = "Tu es un assistant de raisonnement. Réponds de façon concise. Utilise uniquement le contexte fourni."


def load_config(env_file: str | None = None) -> Config:
    cfg = Config()
    for ini in (
        Path("/etc/digest/digest.conf"),
        Path("/etc/env/digest.default"),
        Path.home() / ".config/digest/digest.conf",
    ):
        if ini.exists():
            if ini.suffix in (".conf", ".ini"):
                parser = configparser.ConfigParser()
                parser.read(ini)
                _ini(cfg, parser)
            else:
                _dotenv(cfg, ini)
    for dot in (
        Path.home() / ".config/digest/digest.env",
        Path.home() / ".config/digest.env",
    ):
        if dot.exists():
            _dotenv(cfg, dot)
    dot = Path(env_file) if env_file else Path(".env/digest.env")
    if dot.exists():
        _dotenv(cfg, dot)
    _environ(cfg)
    return cfg


def _ini(cfg: Config, parser: configparser.ConfigParser):
    if parser.has_section("digest"):
        section = parser["digest"]
        cfg.semantic_ratio = section.getfloat("SEMANTIC_RATIO", cfg.semantic_ratio)
        cfg.tolerance = section.getfloat("TOLERANCE", cfg.tolerance)
        cfg.lambda_mmr = section.getfloat("LAMBDA_MMR", cfg.lambda_mmr)
        cfg.min_sentence_words = section.getint("MIN_SENTENCE_WORDS", cfg.min_sentence_words)
        cfg.lang = section.get("LANG", cfg.lang)
    if parser.has_section("paths"):
        section = parser["paths"]
        cfg.source_root = Path(section.get("SOURCE_ROOT", str(cfg.source_root))).expanduser()
        cfg.corpus_root = Path(section.get("CORPUS_ROOT", str(cfg.corpus_root))).expanduser()
        cfg.archive_dir = Path(section.get("ARCHIVE_DIR", str(cfg.archive_dir))).expanduser()
    if parser.has_section("router"):
        section = parser["router"]
        cfg.top_k_files = section.getint("TOP_K_FILES", cfg.top_k_files)
        cfg.max_context_chars = section.getint("MAX_CONTEXT_CHARS", cfg.max_context_chars)
        cfg.min_score = section.getfloat("MIN_SCORE", cfg.min_score)
    if parser.has_section("llm"):
        section = parser["llm"]
        cfg.llm_host = section.get("HOST", cfg.llm_host)
        cfg.llm_model = section.get("MODEL", cfg.llm_model)
        cfg.llm_api = section.get("API", cfg.llm_api)
        cfg.llm_api_key = section.get("API_KEY", cfg.llm_api_key)
        cfg.llm_temperature = section.getfloat("TEMPERATURE", cfg.llm_temperature)
        cfg.llm_top_p = section.getfloat("TOP_P", cfg.llm_top_p)
        cfg.llm_top_k = section.getint("TOP_K", cfg.llm_top_k)
        cfg.llm_max_tokens = section.getint("MAX_TOKENS", cfg.llm_max_tokens)
        cfg.llm_repeat_penalty = section.getfloat("REPEAT_PENALTY", cfg.llm_repeat_penalty)
        cfg.llm_ctx = section.getint("CTX", cfg.llm_ctx)
        cfg.llm_timeout = section.getfloat("TIMEOUT", cfg.llm_timeout)
        cfg.llm_system = section.get("SYSTEM", cfg.llm_system)


def _dotenv(cfg: Config, path: Path):
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        _env(cfg, key.strip(), value.strip().strip('"').strip("'"))


def _environ(cfg: Config):
    keys = (
        "SEMANTIC_RATIO", "TOLERANCE", "LAMBDA_MMR",
        "MIN_SENTENCE_WORDS", "LANG", "SOURCE_ROOT", "CORPUS_ROOT",
        "ARCHIVE_DIR", "LLM_HOST", "LLM_MODEL", "LLM_API", "LLM_API_KEY",
        "LLM_TEMPERATURE", "LLM_TOP_P", "LLM_TOP_K", "LLM_MAX_TOKENS",
        "LLM_REPEAT_PENALTY", "LLM_CTX", "LLM_TIMEOUT", "LLM_SYSTEM",
        "TOP_K_FILES", "MAX_CONTEXT_CHARS", "MIN_SCORE",
    )
    for key in keys:
        value = os.environ.get(key)
        if value:
            _env(cfg, key, value)


def _env(cfg: Config, key: str, value: str):
    setters = {
        "SEMANTIC_RATIO": lambda: setattr(cfg, "semantic_ratio", float(value)),
        "TOLERANCE": lambda: setattr(cfg, "tolerance", float(value)),
        "LAMBDA_MMR": lambda: setattr(cfg, "lambda_mmr", float(value)),
        "MIN_SENTENCE_WORDS": lambda: setattr(cfg, "min_sentence_words", int(value)),
        "LANG": lambda: setattr(cfg, "lang", value),
        "SOURCE_ROOT": lambda: setattr(cfg, "source_root", Path(value).expanduser()),
        "CORPUS_ROOT": lambda: setattr(cfg, "corpus_root", Path(value).expanduser()),
        "ARCHIVE_DIR": lambda: setattr(cfg, "archive_dir", Path(value).expanduser()),
        "LLM_HOST": lambda: setattr(cfg, "llm_host", value),
        "LLM_MODEL": lambda: setattr(cfg, "llm_model", value),
        "LLM_API": lambda: setattr(cfg, "llm_api", value),
        "LLM_API_KEY": lambda: setattr(cfg, "llm_api_key", value),
        "LLM_TEMPERATURE": lambda: setattr(cfg, "llm_temperature", float(value)),
        "LLM_TOP_P": lambda: setattr(cfg, "llm_top_p", float(value)),
        "LLM_TOP_K": lambda: setattr(cfg, "llm_top_k", int(value)),
        "LLM_MAX_TOKENS": lambda: setattr(cfg, "llm_max_tokens", int(value)),
        "LLM_REPEAT_PENALTY": lambda: setattr(cfg, "llm_repeat_penalty", float(value)),
        "LLM_CTX": lambda: setattr(cfg, "llm_ctx", int(value)),
        "LLM_TIMEOUT": lambda: setattr(cfg, "llm_timeout", float(value)),
        "LLM_SYSTEM": lambda: setattr(cfg, "llm_system", value),
        "TOP_K_FILES": lambda: setattr(cfg, "top_k_files", int(value)),
        "MAX_CONTEXT_CHARS": lambda: setattr(cfg, "max_context_chars", int(value)),
        "MIN_SCORE": lambda: setattr(cfg, "min_score", float(value)),
    }
    if key in setters:
        setters[key]()


_STOP = {
    "fr": frozenset("le la les un une des du de d au aux et ou mais donc or ni car que qui ce cet cette ces dans par pour sur sous avec sans chez entre vers dès je tu il elle on nous vous ils elles me te se lui leur y en dont a à été être avoir faire dire aller voir savoir pouvoir vouloir ceci cela celui celle ceux plus moins très trop bien mal tout tous ne pas est sont".split()),
    "en": frozenset("the a an is are was were be been being have has had do does did will would shall should can could may might must this that these those in on at to for of with by from as it its he she they we you not".split()),
}


class Tok:
    def __init__(self, lang: str = "fr"):
        self.lang = lang
        self._mt = None
        self._ms = None
        if _HAS_MOSES:
            self._mt = sacremoses.MosesTokenizer(lang=lang)
            self._ms = sacremoses.MosesSentenceDetector(
                lang=lang,
                non_breaking=("M.", "Mme", "Mlle", "Dr", "Pr", "St", "Ste",
                              "av.", "janv.", "févr.", "avr.", "juil.", "sept.",
                              "oct.", "nov.", "déc.", "etc.", "cf.",
                              "Mr.", "Mrs.", "Prof.", "vs.", "e.g.", "i.e."),
            )

    def words(self, text: str) -> list[str]:
        if self._mt:
            return self._mt.tokenize(text, return_str=False, escape=False)
        return re.findall(r"\w+", text)

    def content(self, text: str) -> list[str]:
        stop = _STOP.get(self.lang, frozenset())
        return [token.lower() for token in self.words(text)
                if len(token) > 1 and token.lower() not in stop]

    def sentences(self, text: str) -> list[str]:
        if self._ms:
            return self._ms.sent_tokenize(text)
        return [part.strip() for part in re.split(
            r'(?<=[.!?;:])\s+(?=[A-ZÀ-Ü0-9«"\'])', text) if part.strip()]


@dataclass
class _S:
    text: str
    idx: int
    wc: int
    tf: dict = field(default_factory=dict)
    score: float = 0.0


def _cos(a: dict, b: dict) -> float:
    if not a or not b:
        return 0.0
    common = set(a) & set(b)
    if not common:
        return 0.0
    dot = sum(a[token] * b[token] for token in common)
    norm_a = sum(value * value for value in a.values()) ** 0.5
    norm_b = sum(value * value for value in b.values()) ** 0.5
    return dot / (norm_a * norm_b) if norm_a and norm_b else 0.0


def _prank(sim: list[list[float]], damping: float = 0.85,
           iterations: int = 50, tolerance: float = 1e-6) -> list[float]:
    count = len(sim)
    if count == 0:
        return []
    scores = [1.0 / count] * count
    for _ in range(iterations):
        new_scores = [0.0] * count
        for i in range(count):
            incoming = 0.0
            for j in range(count):
                if i == j:
                    continue
                row_sum = sum(sim[j]) - sim[j][j]
                if row_sum > 0:
                    incoming += (sim[j][i] / row_sum) * scores[j]
            new_scores[i] = (1 - damping) / count + damping * incoming
        if sum(abs(new_scores[i] - scores[i]) for i in range(count)) < tolerance:
            scores = new_scores
            break
        scores = new_scores
    return scores


def _mmr(candidates: list[_S], budget: int, lam: float) -> list[_S]:
    selected = []
    remaining = list(candidates)
    used = 0
    while remaining and used < budget:
        best = -1.0
        best_index = 0
        for i, candidate in enumerate(remaining):
            redundancy = max((_cos(candidate.tf, selected_sentence.tf)
                              for selected_sentence in selected), default=0.0)
            mmr_score = lam * candidate.score - (1 - lam) * redundancy
            if mmr_score > best:
                best = mmr_score
                best_index = i
        chosen = remaining.pop(best_index)
        selected.append(chosen)
        used += chosen.wc
    selected.sort(key=lambda sentence: sentence.idx)
    return selected


def digest(text: str, cfg: Config, tok: Tok) -> tuple[str, dict]:
    raw_sentences = tok.sentences(text)
    sentences: list[_S] = []
    total_words = 0
    for index, sentence in enumerate(raw_sentences):
        all_words = tok.words(sentence)
        word_count = len(all_words)
        if word_count < cfg.min_sentence_words:
            continue
        content = tok.content(sentence)
        norm = max(1, len(content)) ** 0.5
        tf = Counter(content)
        sentences.append(_S(sentence, index, word_count,
                            {word: value / norm for word, value in tf.items()}))
        total_words += word_count
    if not sentences:
        return "", {"ratio": 0.0, "kept": 0, "total": 0,
                    "original_words": 0, "compressed_words": 0}
    count = len(sentences)
    similarity = [[0.0] * count for _ in range(count)]
    for i in range(count):
        for j in range(i + 1, count):
            value = _cos(sentences[i].tf, sentences[j].tf)
            similarity[i][j] = similarity[j][i] = value
    scores = _prank(similarity)
    maximum = max(scores) if scores else 1.0
    for index, sentence in enumerate(sentences):
        sentence.score = scores[index] / maximum if maximum > 0 else 0.0
    budget = int(total_words * cfg.semantic_ratio * (1 + cfg.tolerance))
    candidates = sorted(sentences, key=lambda sentence: sentence.score, reverse=True)
    selected = _mmr(candidates, budget=budget, lam=cfg.lambda_mmr)
    while sum(sentence.wc for sentence in selected) > budget and len(selected) > 1:
        index = max(range(len(selected)), key=lambda i: selected[i].score,
                    default=0)
        selected.pop(index)
    selected.sort(key=lambda sentence: sentence.idx)
    output = " ".join(sentence.text for sentence in selected)
    compressed_words = sum(sentence.wc for sentence in selected)
    return output, {
        "ratio": round(compressed_words / total_words, 4) if total_words else 0,
        "target_ratio": cfg.semantic_ratio,
        "kept": len(selected),
        "total": len(sentences),
        "original_words": total_words,
        "compressed_words": compressed_words,
    }


EXTS = {".txt", ".md", ".rst", ".csv", ".json", ".yaml", ".yml",
        ".toml", ".html", ".xml", ".tex", ".org", ".adoc", ".py", ".sh"}


def walk(root: Path) -> Iterator[Path]:
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.suffix.lower() in EXTS:
            yield path


def densify(cfg: Config, force: bool = False) -> dict:
    tok = Tok(lang=cfg.lang)
    cfg.corpus_root.mkdir(parents=True, exist_ok=True)
    manifest = {
        "version": 2,
        "created": time.strftime("%Y-%m-%dT%H:%M:%S"),
        "config": {"semantic_ratio": cfg.semantic_ratio,
                   "lang": cfg.lang, "lambda_mmr": cfg.lambda_mmr},
        "files": {},
    }
    stats = {"processed": 0, "skipped": 0, "errors": 0}
    for source in walk(cfg.source_root):
        rel = source.relative_to(cfg.source_root)
        destination = cfg.corpus_root / rel.parent / f"{rel.name}.digest"
        destination.parent.mkdir(parents=True, exist_ok=True)
        if (not force and destination.exists()
                and destination.stat().st_mtime > source.stat().st_mtime):
            stats["skipped"] += 1
            manifest["files"][str(rel)] = {
                "digest_path": str(destination.relative_to(cfg.corpus_root)),
                "status": "cached",
            }
            continue
        try:
            text = source.read_text(encoding="utf-8", errors="replace")
            if len(text.strip()) < 50:
                stats["skipped"] += 1
                continue
            compressed, metadata = digest(text, cfg, tok)
            destination.write_text(compressed, encoding="utf-8")
            manifest["files"][str(rel)] = {
                "digest_path": str(destination.relative_to(cfg.corpus_root)),
                "status": "densified",
                **metadata,
            }
            stats["processed"] += 1
        except Exception as error:
            stats["errors"] += 1
            manifest["files"][str(rel)] = {"status": "error", "msg": str(error)}
    manifest["stats"] = stats
    (cfg.corpus_root / ".digest_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    return manifest


def archive(cfg: Config) -> Path:
    cfg.archive_dir.mkdir(parents=True, exist_ok=True)
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    path = cfg.archive_dir / f"corpus_{timestamp}.tar.gz"
    with tarfile.open(path, "w:gz") as tar:
        for file in sorted(cfg.corpus_root.rglob("*.digest")):
            tar.add(file, arcname=str(file.relative_to(cfg.corpus_root)))
        manifest = cfg.corpus_root / ".digest_manifest.json"
        if manifest.exists():
            tar.add(manifest, arcname=".digest_manifest.json")
    return path


class Router:
    def __init__(self, cfg: Config):
        self.cfg = cfg
        self.tok = Tok(lang=cfg.lang)
        self._idx: dict[str, dict] = {}
        self._loaded = False

    def _load(self):
        if self._loaded:
            return
        manifest = self.cfg.corpus_root / ".digest_manifest.json"
        if not manifest.exists():
            raise FileNotFoundError("No manifest. Run: digest densify")
        data = json.loads(manifest.read_text(encoding="utf-8"))
        for rel, info in data.get("files", {}).items():
            if info.get("status") not in ("densified", "cached"):
                continue
            digest_path = self.cfg.corpus_root / info["digest_path"]
            if not digest_path.exists():
                continue
            digest_text = digest_path.read_text(encoding="utf-8")
            content = self.tok.content(digest_text)
            norm = max(1, len(content)) ** 0.5
            tf = Counter(content)
            self._idx[rel] = {
                "tf": {word: value / norm for word, value in tf.items()},
                "digest_text": digest_text,
            }
        self._loaded = True

    def select(self, query: str, top_k: int | None = None,
               min_score: float | None = None) -> list[tuple[str, float]]:
        self._load()
        query_terms = self.tok.content(query)
        norm = max(1, len(query_terms)) ** 0.5
        tf = Counter(query_terms)
        query_vector = {word: value / norm for word, value in tf.items()}
        top_k = top_k if top_k is not None else self.cfg.top_k_files
        threshold = min_score if min_score is not None else self.cfg.min_score
        scored = [(rel, _cos(query_vector, entry["tf"]))
                  for rel, entry in self._idx.items()]
        scored = [(rel, score) for rel, score in scored if score >= threshold]
        scored.sort(key=lambda item: item[1], reverse=True)
        return scored[:top_k]

    def load_context(self, query: str) -> str:
        selected = self.select(query)
        if not selected:
            return ""
        parts = []
        budget = self.cfg.max_context_chars
        for rel, score in selected:
            full_path = self.cfg.source_root / rel
            if not full_path.exists():
                continue
            text = full_path.read_text(encoding="utf-8", errors="replace")
            per_file = budget // max(1, len(selected))
            snippet = text[:per_file]
            parts.append(f"[{rel} | {score:.3f}]\n{snippet}")
            budget -= len(snippet)
            if budget <= 0:
                break
        return "\n\n".join(parts)


def llm_chat(cfg: Config, messages: list[dict]) -> str:
    if cfg.llm_api == "openai":
        url = f"http://{cfg.llm_host}/v1/chat/completions"
        body = {"model": cfg.llm_model, "messages": messages,
                "temperature": cfg.llm_temperature, "top_p": cfg.llm_top_p,
                "max_tokens": cfg.llm_max_tokens}
        headers = {"Content-Type": "application/json"}
        if cfg.llm_api_key:
            headers["Authorization"] = "Bearer " + cfg.llm_api_key
    else:
        url = f"http://{cfg.llm_host}/api/chat"
        body = {"model": cfg.llm_model, "messages": messages, "stream": False,
                "options": {"temperature": cfg.llm_temperature,
                            "top_p": cfg.llm_top_p, "top_k": cfg.llm_top_k,
                            "num_predict": cfg.llm_max_tokens,
                            "repeat_penalty": cfg.llm_repeat_penalty,
                            "num_ctx": cfg.llm_ctx}}
        headers = {"Content-Type": "application/json"}
    request = urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"), method="POST")
    for key, value in headers.items():
        request.add_header(key, value)
    try:
        with urllib.request.urlopen(request, timeout=cfg.llm_timeout) as response:
            data = json.loads(response.read().decode("utf-8"))
            if cfg.llm_api == "openai":
                return data["choices"][0]["message"]["content"]
            return data.get("message", {}).get("content", "")
    except urllib.error.HTTPError as error:
        raise ConnectionError(f"HTTP {error.code}: {error.read().decode('utf-8')}")
    except urllib.error.URLError as error:
        raise ConnectionError(f"Cannot reach {url}: {error.reason}")


def main():
    parser = argparse.ArgumentParser(
        prog="digest", description="Densify tree → route context → LLM")
    parser.add_argument("--env", default=None, help="Path to .env file")
    subparsers = parser.add_subparsers(dest="cmd")

    densify_parser = subparsers.add_parser(
        "densify", help="Compress source tree into .digest mirror")
    densify_parser.add_argument("--force", action="store_true")
    densify_parser.add_argument("--ratio", type=float, default=None)

    subparsers.add_parser("archive", help="Pack corpus into .tar.gz")
    subparsers.add_parser("stats", help="Show corpus summary")

    ask_parser = subparsers.add_parser("ask", help="Route + query LLM")
    ask_parser.add_argument("-v", "--verbose", action="store_true")
    ask_parser.add_argument("--model", default=None)
    ask_parser.add_argument("--top-k", type=int, default=None)
    ask_parser.add_argument("--route-only", action="store_true")
    ask_parser.add_argument("question", nargs="*")

    show_parser = subparsers.add_parser("show", help="Show a digest file")
    show_parser.add_argument("relpath")

    args = parser.parse_args()
    cfg = load_config(args.env)

    if args.cmd == "densify":
        if args.ratio is not None:
            cfg.semantic_ratio = args.ratio
        print(f"Source: {cfg.source_root}")
        print(f"Corpus: {cfg.corpus_root}")
        print(f"Ratio:  {cfg.semantic_ratio} | Lang: {cfg.lang}")
        print(f"Tok:    {'sacremoses' if _HAS_MOSES else 'regex'}")
        print()
        manifest = densify(cfg, force=args.force)
        stats = manifest["stats"]
        print(f"✓ {stats['processed']} densified, "
              f"{stats['skipped']} cached, {stats['errors']} errors")
    elif args.cmd == "archive":
        archive_path = archive(cfg)
        print(f"✓ {archive_path} "
              f"({archive_path.stat().st_size / 1024 / 1024:.1f} MB)")
    elif args.cmd == "stats":
        manifest_path = cfg.corpus_root / ".digest_manifest.json"
        if not manifest_path.exists():
            print("No manifest. Run densify first.")
            sys.exit(1)
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        files = manifest.get("files", {})
        densified = [entry for entry in files.values()
                     if entry.get("status") == "densified"]
        original = sum(entry.get("original_words", 0) for entry in densified)
        compressed = sum(entry.get("compressed_words", 0) for entry in densified)
        ratio = compressed / original if original else 0
        print(f"Files: {len(files)} | Densified: {len(densified)}")
        print(f"Words: {original:,} → {compressed:,} "
              f"({ratio:.1%} kept, {1-ratio:.1%} cut)")
        print(f"Config: ratio={manifest['config']['semantic_ratio']} "
              f"lang={manifest['config']['lang']}")
    elif args.cmd == "ask":
        if args.model:
            cfg.llm_model = args.model
        if args.top_k is not None:
            cfg.top_k_files = args.top_k
        question = (" ".join(args.question) if args.question
                    else sys.stdin.read().strip())
        if not question:
            parser.error("Provide a question")
        router = Router(cfg)
        if args.route_only:
            selected = router.select(question, top_k=20, min_score=0.0)
            print(json.dumps(
                [{"file": file, "score": round(score, 4)}
                 for file, score in selected],
                indent=2,
            ))
            return
        context = router.load_context(question)
        if args.verbose:
            selected = router.select(question, top_k=20, min_score=0.0)
            print("── ROUTER ──", file=sys.stderr)
            for file, score in selected[:5]:
                print(f"  {score:.4f}  {file}", file=sys.stderr)
            print(f"  ctx={len(context)} chars\n", file=sys.stderr)
        messages = []
        if cfg.llm_system:
            messages.append({"role": "system", "content": cfg.llm_system})
        user_message = (f"Contexte:\n{context}\n\nQuestion: {question}"
                        if context else question)
        messages.append({"role": "user", "content": user_message})
        print(llm_chat(cfg, messages))
    elif args.cmd == "show":
        destination = cfg.corpus_root / args.relpath
        destination = destination.parent / f"{destination.name}.digest"
        if not destination.exists():
            print(f"Not found: {destination}")
            sys.exit(1)
        print(destination.read_text(encoding="utf-8"))
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
