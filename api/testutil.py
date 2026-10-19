import shutil
import sys
import tempfile
from pathlib import Path

from django.core.cache import cache
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "tools"))
import packsign  # noqa: E402


def hx(c: str) -> str:
    return c * 64


class ApiTestCase(TestCase):
    """Every test runs against a copy of the real pack, signed with a throwaway key (never the release key)."""

    def setUp(self):
        cache.clear()  # throttle counters live in the cache
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        self.pack_dir = tmp / "core"
        self.pack_dir.mkdir()
        shutil.copy(REPO / "packs" / "core" / "pack.json", self.pack_dir / "pack.json")
        self.private, self.public = tmp / "k.private", tmp / "k.pub"
        packsign.genkey(self.private, self.public)
        packsign.sign(self.private, self.pack_dir / "pack.json")
        self.enterContext(override_settings(PACKS_DIR=self.pack_dir, PACK_PUBLIC_KEY=self.public))
        self.client = APIClient()
