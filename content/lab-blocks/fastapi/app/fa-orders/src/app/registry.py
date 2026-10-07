"""Feature discovery: every package under app/ may ship models, a router and a lifecycle hook.

A feature is a sub-package of ``app``. It is picked up automatically:

* ``app.<feature>.models``     imported so Alembic and the tests see its tables
* ``app.<feature>.router``     its ``router`` (an APIRouter) is mounted
* ``app.<feature>.lifecycle``  ``startup(app)`` / ``shutdown(app)`` run with the application
* ``app.ext.<module>``         small add-on endpoints; each module's ``router`` is mounted
"""

import importlib
import importlib.util
import pkgutil
from types import ModuleType

import app as app_package
from app import ext


def _feature_names() -> list[str]:
    return sorted(m.name for m in pkgutil.iter_modules(app_package.__path__) if m.ispkg)


def _optional(module_name: str) -> ModuleType | None:
    if importlib.util.find_spec(module_name) is None:
        return None
    return importlib.import_module(module_name)


def load_models() -> None:
    for name in _feature_names():
        _optional(f"app.{name}.models")


def routers() -> list:
    found = []
    for name in _feature_names():
        module = _optional(f"app.{name}.router")
        if module is not None and hasattr(module, "router"):
            found.append(module.router)
    for info in sorted(pkgutil.iter_modules(ext.__path__), key=lambda m: m.name):
        module = importlib.import_module(f"app.ext.{info.name}")
        if hasattr(module, "router"):
            found.append(module.router)
    return found


def lifecycles() -> list[ModuleType]:
    modules = (_optional(f"app.{name}.lifecycle") for name in _feature_names())
    return [m for m in modules if m is not None]
