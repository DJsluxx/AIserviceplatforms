# AI Service Platforms — Monorepo

A collection of AI-powered SaaS platforms sharing a common backend library.

## Architecture

```
AIserviceplatforms/
├── shared/                 # Reusable Python modules (auth, payments, AI, DB)
├── propertiesgenie/        # Platform 1 — AI real-estate listing descriptions
├── <future-platform>/      # Platform 2 — (add new folder per platform)
└── README.md
```

### Shared Module (`shared/`)

| Module            | Purpose                                         |
|-------------------|-------------------------------------------------|
| `config_base.py`  | Base Flask config (DB, PayPal, OpenAI, Mail)    |
| `database.py`     | SQLAlchemy instance + model mixins              |
| `auth.py`         | Blueprint factory for register / login / logout |
| `payments.py`     | PayPal server-side order verification           |
| `ai_client.py`    | OpenAI API wrapper                              |
| `factory.py`      | App setup helper (CORS, login, errors, etc.)    |

Every platform imports from `shared/` — no code duplication.

---

## Platforms

### Properties Genie — [propertiesgenie.com](https://propertiesgenie.com)

AI-powered real-estate listing description generator.

- **Stack:** Flask · PostgreSQL (Neon) · OpenAI GPT-4o-mini · PayPal
- **Plans:** Free (3/mo) · Pro $9.99 (100/mo) · Unlimited $19.99

---

## Getting Started

### Prerequisites

- Python 3.11+
- PostgreSQL (or Neon free tier)
- OpenAI API key
- PayPal Business account

### Environment Variables

Create a `.env` file in the platform folder:

```env
DATABASE_URL=postgresql://user:pass@host/db
SECRET_KEY=your-secret-key
OPENAI_API_KEY=sk-...
PAYPAL_CLIENT_ID=...
PAYPAL_CLIENT_SECRET=...
PAYPAL_MODE=sandbox          # or "live"
```

### Run Locally

```bash
cd propertiesgenie
pip install -r requirements.txt
python app.py
# → http://localhost:5001
```

### Deploy to Render

| Setting          | Value                                              |
|------------------|----------------------------------------------------|
| Root Directory   | *(leave blank — repo root)*                        |
| Build Command    | `pip install -r propertiesgenie/requirements.txt`  |
| Start Command    | `cd propertiesgenie && gunicorn wsgi:application`  |

---

## Adding a New Platform

1. Create a new folder: `newplatform/`
2. Add `config.py` extending `shared.config_base.BaseConfig`
3. Add `models.py` using mixins from `shared.database`
4. Add `app.py` using `shared.factory.setup_app()` and `shared.auth.create_auth_blueprint()`
5. Add templates, static assets, `wsgi.py`, `requirements.txt`
6. Create a new Render Web Service pointing to the same repo

---

## License

Proprietary — All rights reserved.
