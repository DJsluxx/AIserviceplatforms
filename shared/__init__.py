"""
AIserviceplatforms — Shared Module
====================================
Common utilities shared across all AI service platforms:
  • config_base   – Base configuration (DB, PayPal, OpenAI, Email)
  • database      – SQLAlchemy instance & common model mixins
  • auth          – Reusable auth blueprint factory (register / login / logout)
  • payments      – PayPal server-side verification
  • ai_client     – OpenAI API wrapper

Usage from any platform:
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from shared.auth import create_auth_blueprint
    from shared.payments import verify_paypal_order
"""
