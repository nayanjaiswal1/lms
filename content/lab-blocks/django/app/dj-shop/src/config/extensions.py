"""Discovery of optional feature modules under ``ext/``.

A subpackage with an ``apps.py`` is added to INSTALLED_APPS; if it also has a
``urls.py`` the URLconf includes it. Adding a feature module is just adding a
directory.
"""

from pathlib import Path

EXT_DIR = Path(__file__).resolve().parent.parent / "ext"


def _modules(marker):
    if not EXT_DIR.is_dir():
        return []
    return sorted(p.name for p in EXT_DIR.iterdir() if (p / marker).is_file())


def installed_apps():
    return [f"ext.{name}" for name in _modules("apps.py")]


def url_modules():
    return [f"ext.{name}.urls" for name in _modules("urls.py")]
