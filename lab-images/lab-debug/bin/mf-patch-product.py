#!/usr/bin/env python3
"""Build-time patch of openvscode-server's product.json.

Disables the extension marketplace (the runtime sandbox has no egress) and,
when a template is given, self-hosts webview content
(webviewContentExternalBaseUrlTemplate) instead of *.vscode-cdn.net.
"""
import json
import sys

PRODUCT_JSON = "/opt/openvscode-server/product.json"


def main() -> int:
    template = sys.argv[1] if len(sys.argv) > 1 else ""
    with open(PRODUCT_JSON, encoding="utf-8") as f:
        product = json.load(f)
    product.pop("extensionsGallery", None)
    if template:
        product["webviewContentExternalBaseUrlTemplate"] = template
    with open(PRODUCT_JSON, "w", encoding="utf-8") as f:
        json.dump(product, f, indent=2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
