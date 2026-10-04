"""The interactive docs must find the OpenAPI document under whatever path prefix the reverse proxy adds."""

import pytest
from fastapi.testclient import TestClient

from app.testing import *  # noqa: F401,F403


@pytest.mark.parametrize("prefix", ["", "/api", "/orders-service/v2"])
def test_docs_page_points_at_the_openapi_document_under_the_prefix(db, prefix):
    from app.main import create_app

    with TestClient(create_app(), root_path=prefix) as client:
        page = client.get("/docs")
    assert page.status_code == 200
    assert f"{prefix}/openapi.json" in page.text
