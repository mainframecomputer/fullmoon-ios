# Created by Sébastien DAGUIN
"""Run SearXNG inside the iOS interpreter, without a process or HTTP listener."""

import json
import logging
import os
from pathlib import Path
import secrets


def initialize(cache_directory):
    root = Path(cache_directory)
    root.mkdir(parents=True, exist_ok=True)
    os.environ["XDG_CACHE_HOME"] = str(root)
    os.environ["XDG_CONFIG_HOME"] = str(root)
    settings = root / "settings.yml"
    settings.write_text("""use_default_settings: true
general:
  debug: false
  enable_metrics: false
server:
  secret_key: "%s"
  limiter: false
  public_instance: false
  image_proxy: false
search:
  formats: [json]
outgoing:
  request_timeout: 5.0
  max_request_timeout: 10.0
""" % secrets.token_hex(32))
    os.environ["SEARXNG_SETTINGS_PATH"] = str(settings)
    import certifi
    os.environ["SSL_CERT_FILE"] = certifi.where()
    logging.disable(logging.CRITICAL)
    from searx.webapp import app
    return app


_app = None


def search(query, cache_directory):
    global _app
    if _app is None:
        _app = initialize(cache_directory)
    # Flask's WSGI client invokes the real search pipeline without opening a socket.
    with _app.test_client() as client:
        response = client.get("/search", query_string={"q": query, "format": "json"})
        if response.status_code != 200 or response.mimetype != "application/json":
            raise RuntimeError("SearXNG search failed")
        if len(response.data) > 2 * 1024 * 1024:
            raise RuntimeError("SearXNG response too large")
        payload = response.get_json()
        return json.dumps({"results": payload["results"]}, ensure_ascii=False)
