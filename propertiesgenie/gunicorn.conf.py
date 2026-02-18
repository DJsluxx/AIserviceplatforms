"""Gunicorn configuration for Properties Genie."""

import multiprocessing

# Bind
bind = "0.0.0.0:10000"

# Workers — Render free tier has limited RAM; keep conservative
workers = multiprocessing.cpu_count() * 2 + 1
workers = min(workers, 4)

# Timeouts
timeout = 120
graceful_timeout = 30

# Logging
accesslog = "-"
errorlog = "-"
loglevel = "info"

# Preload for faster worker boot
preload_app = True
