"""
Properties Genie — Main Flask Application
=============================================
AI-powered real estate listing description generator.
Only platform-specific routes live here; auth, payments, AI, and
app setup are imported from the shared/ library.
"""

import os
import sys
import json
from datetime import datetime, timedelta, timezone

# ── Make shared/ importable ────────────────────────────────────
_root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
if _root not in sys.path:
    sys.path.insert(0, _root)

from flask import (
    Flask, render_template, request, redirect, url_for,
    flash, jsonify, abort,
)
from flask_login import login_required, current_user
from werkzeug.security import check_password_hash, generate_password_hash

from config import Config
from models import PGUser, PGSubscription, PGListing, PGUsageLog, PGContact
from shared.database import db
from shared.factory import setup_app
from shared.auth import create_auth_blueprint
from shared.payments import verify_paypal_order
from shared.ai_client import call_openai


# ╔══════════════════════════════════════════════════════════════╗
# ║  APP FACTORY                                                 ║
# ╚══════════════════════════════════════════════════════════════╝

def create_app():
    app = Flask(__name__)

    # Shared setup (DB, login manager, CORS, credit reset, error handlers)
    setup_app(app, user_model=PGUser, config_class=Config)

    # Auth blueprint (register / login / logout)
    auth_bp = create_auth_blueprint(
        user_model=PGUser,
        db=db,
        site_name=Config.SITE_NAME,
        free_credits=Config.FREE_CREDITS,
        welcome_message=f"Welcome to Properties Genie! You have {Config.FREE_CREDITS} free descriptions.",
    )
    app.register_blueprint(auth_bp)

    # ── Context Processors ─────────────────────────────────────
    @app.context_processor
    def inject_globals():
        return {
            "site_name": Config.SITE_NAME,
            "site_url": Config.SITE_URL,
            "year": datetime.now(timezone.utc).year,
            "paypal_client_id": Config.PAYPAL_CLIENT_ID,
            "pro_price": Config.PRO_PRICE,
            "unlimited_price": Config.UNLIMITED_PRICE,
        }

    # ════════════════════════════════════════════════════════════
    #  PUBLIC PAGES
    # ════════════════════════════════════════════════════════════

    @app.route("/")
    def index():
        return render_template("index.html")

    @app.route("/pricing")
    def pricing():
        return render_template("pricing.html")

    @app.route("/about")
    def about():
        return render_template("about.html")

    @app.route("/contact", methods=["GET", "POST"])
    def contact():
        if request.method == "POST":
            msg = PGContact(
                name=request.form.get("name", "").strip(),
                email=request.form.get("email", "").strip(),
                subject=request.form.get("subject", "").strip(),
                message=request.form.get("message", "").strip(),
            )
            db.session.add(msg)
            db.session.commit()
            flash("Message sent! We'll get back to you soon.", "success")
            return redirect(url_for("contact"))
        return render_template("contact.html")

    @app.route("/terms")
    def terms():
        return render_template("terms.html")

    @app.route("/privacy")
    def privacy():
        return render_template("privacy.html")

    # ════════════════════════════════════════════════════════════
    #  DASHBOARD
    # ════════════════════════════════════════════════════════════

    @app.route("/dashboard")
    @login_required
    def dashboard():
        recent = PGListing.query.filter_by(user_id=current_user.id)\
            .order_by(PGListing.created_at.desc()).limit(5).all()
        total = PGListing.query.filter_by(user_id=current_user.id).count()
        return render_template("dashboard.html", recent_listings=recent, total_listings=total)

    # ════════════════════════════════════════════════════════════
    #  GENERATOR — The Core Feature
    # ════════════════════════════════════════════════════════════

    @app.route("/generate", methods=["GET", "POST"])
    @login_required
    def generate():
        if request.method == "GET":
            return render_template("generator.html")

        if current_user.credits_remaining <= 0:
            flash("You've used all your credits this month. Upgrade for more!", "error")
            return redirect(url_for("pricing"))

        data = {k: request.form.get(k, "") for k in (
            "property_type", "listing_type", "bedrooms", "bathrooms",
            "sqft", "lot_size", "year_built", "price", "address",
            "city", "state", "zip_code", "features",
            "neighborhood_info", "tone", "additional_notes",
        )}

        prompt = _build_prompt(data)

        try:
            result = call_openai(
                system_prompt=(
                    "You are an expert real estate copywriter with 20 years of experience. "
                    "You write compelling, accurate property descriptions that sell. "
                    "Always respond with valid JSON only."
                ),
                user_prompt=prompt,
                api_key=Config.OPENAI_API_KEY,
                model=Config.OPENAI_MODEL,
            )
            ai = result["content"]
            tokens = result["tokens_used"]
        except Exception as e:
            app.logger.error(f"OpenAI error: {e}")
            flash("AI service temporarily unavailable. Please try again.", "error")
            return render_template("generator.html", form_data=data)

        title = ai.get("title", "Beautiful Property Listing")
        description = ai.get("description", "")
        highlights = ai.get("highlights", [])

        listing = PGListing(
            user_id=current_user.id,
            property_type=data["property_type"],
            listing_type=data["listing_type"],
            bedrooms=int(data["bedrooms"]) if data["bedrooms"] else None,
            bathrooms=float(data["bathrooms"]) if data["bathrooms"] else None,
            sqft=int(data["sqft"]) if data["sqft"] else None,
            lot_size=data["lot_size"] or None,
            year_built=int(data["year_built"]) if data["year_built"] else None,
            price=data["price"] or None,
            address=data["address"] or None,
            city=data["city"] or None,
            state=data["state"] or None,
            zip_code=data["zip_code"] or None,
            features=data["features"] or None,
            neighborhood_info=data["neighborhood_info"] or None,
            tone=data.get("tone", "professional"),
            additional_notes=data["additional_notes"] or None,
            generated_title=title,
            generated_description=description,
            generated_highlights=json.dumps(highlights),
            tokens_used=tokens,
        )
        db.session.add(listing)
        current_user.credits_used += 1
        db.session.add(PGUsageLog(
            user_id=current_user.id, action="generate",
            tokens_used=tokens, model=Config.OPENAI_MODEL,
        ))
        db.session.commit()

        return render_template("result.html", listing=listing, highlights=highlights)

    @app.route("/listing/<int:lid>")
    @login_required
    def view_listing(lid):
        listing = PGListing.query.filter_by(id=lid, user_id=current_user.id).first_or_404()
        hl = json.loads(listing.generated_highlights) if listing.generated_highlights else []
        return render_template("result.html", listing=listing, highlights=hl)

    @app.route("/listing/<int:lid>/favorite", methods=["POST"])
    @login_required
    def toggle_favorite(lid):
        listing = PGListing.query.filter_by(id=lid, user_id=current_user.id).first_or_404()
        listing.is_favorite = not listing.is_favorite
        db.session.commit()
        return jsonify({"is_favorite": listing.is_favorite})

    @app.route("/listing/<int:lid>/delete", methods=["POST"])
    @login_required
    def delete_listing(lid):
        listing = PGListing.query.filter_by(id=lid, user_id=current_user.id).first_or_404()
        db.session.delete(listing)
        db.session.commit()
        flash("Listing deleted.", "info")
        return redirect(url_for("history"))

    # ════════════════════════════════════════════════════════════
    #  HISTORY
    # ════════════════════════════════════════════════════════════

    @app.route("/history")
    @login_required
    def history():
        page = request.args.get("page", 1, type=int)
        listings = PGListing.query.filter_by(user_id=current_user.id)\
            .order_by(PGListing.created_at.desc())\
            .paginate(page=page, per_page=12, error_out=False)
        return render_template("history.html", listings=listings)

    # ════════════════════════════════════════════════════════════
    #  ACCOUNT
    # ════════════════════════════════════════════════════════════

    @app.route("/account", methods=["GET", "POST"])
    @login_required
    def account():
        if request.method == "POST":
            action = request.form.get("action")
            if action == "update_profile":
                current_user.name = request.form.get("name", "").strip()
                new_email = request.form.get("email", "").strip().lower()
                if new_email != current_user.email:
                    if PGUser.query.filter_by(email=new_email).first():
                        flash("That email is already in use.", "error")
                        return redirect(url_for("account"))
                    current_user.email = new_email
                db.session.commit()
                flash("Profile updated.", "success")
            elif action == "change_password":
                old_pw = request.form.get("old_password", "")
                new_pw = request.form.get("new_password", "")
                if not check_password_hash(current_user.password_hash, old_pw):
                    flash("Current password is incorrect.", "error")
                elif len(new_pw) < 6:
                    flash("New password must be at least 6 characters.", "error")
                else:
                    current_user.password_hash = generate_password_hash(new_pw)
                    db.session.commit()
                    flash("Password changed.", "success")
            return redirect(url_for("account"))
        return render_template("account.html")

    # ════════════════════════════════════════════════════════════
    #  PAYMENTS  (uses shared PayPal verification)
    # ════════════════════════════════════════════════════════════

    @app.route("/upgrade/<plan>")
    @login_required
    def upgrade(plan):
        if plan not in ("pro", "unlimited"):
            abort(404)
        price = Config.PRO_PRICE if plan == "pro" else Config.UNLIMITED_PRICE
        return render_template("checkout.html", plan=plan, price=price)

    @app.route("/api/payment-success", methods=["POST"])
    @login_required
    def payment_success():
        data = request.get_json() or {}
        order_id = data.get("orderID", "")
        plan = data.get("plan", "")
        if plan not in ("pro", "unlimited"):
            return jsonify({"error": "Invalid plan"}), 400

        expected = Config.PRO_PRICE if plan == "pro" else Config.UNLIMITED_PRICE

        verified, info = verify_paypal_order(
            order_id, expected,
            client_id=Config.PAYPAL_CLIENT_ID,
            client_secret=Config.PAYPAL_CLIENT_SECRET,
            mode=Config.PAYPAL_MODE,
        )
        if not verified:
            return jsonify({"error": "Payment verification failed"}), 400

        # Activate / update subscription
        sub = PGSubscription.query.filter_by(user_id=current_user.id, status="active").first()
        now = datetime.now(timezone.utc)
        if sub:
            sub.plan, sub.amount, sub.paypal_order_id = plan, expected, order_id
            sub.started_at, sub.expires_at = now, now + timedelta(days=30)
        else:
            db.session.add(PGSubscription(
                user_id=current_user.id, paypal_order_id=order_id,
                plan=plan, amount=expected, status="active",
                started_at=now, expires_at=now + timedelta(days=30),
            ))

        current_user.plan = plan
        current_user.credits_used = 0
        current_user.credits_reset_at = now
        db.session.commit()

        return jsonify({
            "success": True, "plan": plan,
            "message": f"Welcome to {plan.title()}! Your credits have been refreshed.",
        })

    # ════════════════════════════════════════════════════════════
    #  SEO
    # ════════════════════════════════════════════════════════════

    @app.route("/robots.txt")
    def robots():
        return (
            f"User-agent: *\nAllow: /\nSitemap: {Config.SITE_URL}/sitemap.xml\n",
            200, {"Content-Type": "text/plain"},
        )

    @app.route("/sitemap.xml")
    def sitemap():
        pages = ["", "pricing", "about", "contact", "terms", "privacy"]
        xml = ['<?xml version="1.0" encoding="UTF-8"?>',
               '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
        for p in pages:
            xml.append(f"  <url><loc>{Config.SITE_URL}/{p}</loc></url>")
        xml.append("</urlset>")
        return "\n".join(xml), 200, {"Content-Type": "application/xml"}

    return app


# ════════════════════════════════════════════════════════════════
#  PROMPT BUILDER  (platform-specific)
# ════════════════════════════════════════════════════════════════

def _build_prompt(data):
    """Build a detailed prompt from property form data."""
    parts = ["Generate a professional real estate listing description.\n"]
    prop_type = data.get("property_type", "house").replace("_", " ").title()
    listing_type = "For Sale" if data.get("listing_type") == "sale" else "For Rent"
    parts.append(f"Property Type: {prop_type}")
    parts.append(f"Listing Type: {listing_type}")

    field_map = {
        "bedrooms": "Bedrooms", "bathrooms": "Bathrooms",
        "sqft": "Square Footage", "lot_size": "Lot Size",
        "year_built": "Year Built",
    }
    for key, label in field_map.items():
        if data.get(key):
            suffix = " sq ft" if key == "sqft" else ""
            parts.append(f"{label}: {data[key]}{suffix}")
    if data.get("price"):
        parts.append(f"Price: ${data['price']}")

    loc = [data.get(k) for k in ("address", "city", "state", "zip_code") if data.get(k)]
    if loc:
        parts.append(f"Location: {', '.join(loc)}")
    if data.get("features"):
        parts.append(f"Key Features: {data['features']}")
    if data.get("neighborhood_info"):
        parts.append(f"Neighborhood: {data['neighborhood_info']}")
    if data.get("additional_notes"):
        parts.append(f"Additional Notes: {data['additional_notes']}")

    tone_map = {
        "professional": "Professional and authoritative",
        "luxury": "Luxurious, elegant, and aspirational",
        "friendly": "Warm, inviting, and approachable",
        "minimal": "Clean, concise, and modern",
    }
    parts.append(f"\nTone: {tone_map.get(data.get('tone', 'professional'), 'Professional')}")

    parts.append("""
Please respond with valid JSON containing:
{
  "title": "An eye-catching listing headline (max 15 words)",
  "description": "A compelling 2-4 paragraph listing description (200-400 words). Include sensory language, highlight key features, and create urgency.",
  "highlights": ["Feature 1", "Feature 2", "Feature 3", "Feature 4", "Feature 5"]
}

Rules:
- Sound natural, not AI-generated
- Use power words that sell (stunning, pristine, meticulously, turnkey, etc.)
- Mention location benefits if provided
- End with a call to action
- Return ONLY valid JSON, no markdown""")

    return "\n".join(parts)


# ── Dev Server ─────────────────────────────────────────────────
if __name__ == "__main__":
    app = create_app()
    app.run(debug=True, port=5001)
