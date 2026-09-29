"""Verification of webhook signatures sent by the payments provider.

The provider signs the raw request body with HMAC-SHA256 and sends
``X-Shop-Signature: sha256=<hexdigest>``.
"""

import hashlib
import hmac

from django.conf import settings

HEADER = "X-Shop-Signature"


def expected_signature(body):
    digest = hmac.new(settings.WEBHOOK_SECRET.encode(), body, hashlib.sha256).hexdigest()
    return f"sha256={digest}"


def is_valid(request):
    provided = request.headers.get(HEADER, "")
    # mf:slot webhooks.signature.verify
    expected = expected_signature(request.body)
    return hmac.compare_digest(provided.encode(), expected.encode())
    # mf:endslot
