"""Extensions: every module in this package that defines register(app) is loaded at startup."""

import importlib
import pkgutil

from fastapi import FastAPI


def load(app: FastAPI) -> None:
    for info in sorted(pkgutil.iter_modules(__path__), key=lambda i: i.name):
        register = getattr(importlib.import_module(f"{__name__}.{info.name}"), "register", None)
        if register is not None:
            register(app)
