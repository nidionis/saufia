import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import digest


class ConfigTests(unittest.TestCase):
    def test_dotenv_overrides_ini_and_then_environment_wins(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            ini = root / "digest.conf"
            ini.write_text(
                "[digest]\nSEMANTIC_RATIO = 0.2\n"
                "[llm]\nMODEL = ini-model\n",
                encoding="utf-8",
            )
            env = root / "digest.env"
            env.write_text(
                "SEMANTIC_RATIO=0.08\nLLM_MODEL=dotenv-model\n",
                encoding="utf-8",
            )
            cfg = digest.Config()
            parser = digest.configparser.ConfigParser()
            parser.read(ini)
            digest._ini(cfg, parser)
            digest._dotenv(cfg, env)
            with patch.dict(os.environ, {"LLM_MODEL": "environment-model"}):
                digest._environ(cfg)

            self.assertEqual(cfg.semantic_ratio, 0.08)
            self.assertEqual(cfg.llm_model, "environment-model")


class DigestTests(unittest.TestCase):
    def test_densify_archive_route_and_context(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "context"
            corpus = root / "corpus"
            archive_dir = root / "archive"
            source.mkdir()
            source.joinpath("guide.md").write_text(
                "A Python guide explains routing and semantic indexing. "
                "It describes Python configuration and source mirroring. "
                "This final sentence contains a separate cooking recipe.",
                encoding="utf-8",
            )
            source.joinpath("recipe.txt").write_text(
                "A cooking recipe explains tomatoes and onions. "
                "It describes preparation and serving the meal.",
                encoding="utf-8",
            )
            cfg = digest.Config(
                source_root=source,
                corpus_root=corpus,
                archive_dir=archive_dir,
                lang="en",
                top_k_files=2,
                min_score=0.0,
                max_context_chars=1000,
            )

            manifest = digest.densify(cfg)
            self.assertIn("guide.md", manifest["files"])
            self.assertEqual(manifest["stats"]["processed"], 2)

            archive = digest.archive(cfg)
            self.assertTrue(archive.exists())

            router = digest.Router(cfg)
            selected = router.select("Python routing", top_k=2)
            self.assertTrue(selected)
            self.assertEqual(selected[0][0], "guide.md")
            context = router.load_context("Python routing")
            self.assertIn("guide.md", context)


if __name__ == "__main__":
    unittest.main()
