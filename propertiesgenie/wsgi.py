"""Properties Genie — WSGI entry-point for Gunicorn / Render."""

import os
import sys

# Ensure repo root is on the path so `shared.*` imports work
_repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _repo_root not in sys.path:
    sys.path.insert(0, _repo_root)

# Ensure platform folder is on the path
_platform = os.path.dirname(os.path.abspath(__file__))
if _platform not in sys.path:
    sys.path.insert(0, _platform)

from app import create_app  # noqa: E402

application = create_app()

if __name__ == "__main__":
    application.run()
