"""Quick script to list all registered PropertiesGenie users.
Run from the propertiesgenie/ directory:  python _list_users.py
"""
import sys, os

# Ensure correct working directory so .env is found
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from shared.database import db
from models import PGUser

app = create_app()
with app.app_context():
    users = PGUser.query.order_by(PGUser.created_at.desc()).all()
    total = len(users)
    print(f"\n{'='*60}")
    print(f"  PropertiesGenie — Total Registered Users: {total}")
    print(f"{'='*60}\n")
    
    fmt = "{:<4} {:<22} {:<32} {:<8} {:<9} {:<8} {}"
    print(fmt.format("#", "Name", "Email", "Plan", "Verified", "Credits", "Registered"))
    print("-" * 110)
    for i, u in enumerate(users, 1):
        dt = u.created_at.strftime("%Y-%m-%d %H:%M") if u.created_at else "N/A"
        name = (u.name or "-")[:21]
        email = u.email[:31]
        verified = "Yes" if u.email_verified else "No"
        print(fmt.format(i, name, email, u.plan, verified, u.credits_remaining, dt))
    
    # Stats
    plans = {}
    for u in users:
        plans[u.plan] = plans.get(u.plan, 0) + 1
    verified_count = sum(1 for u in users if u.email_verified)
    google_count = sum(1 for u in users if u.google_id)
    
    print(f"\n{'='*60}")
    print(f"  Stats:")
    print(f"    Plans: {plans}")
    print(f"    Email verified: {verified_count}/{total}")
    print(f"    Google sign-in: {google_count}/{total}")
    print(f"{'='*60}")
