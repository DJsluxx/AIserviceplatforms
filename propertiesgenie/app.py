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
    flash, jsonify, abort, Response, make_response,
)
from flask_login import login_required, current_user
from werkzeug.security import check_password_hash, generate_password_hash

from config import Config
from models import PGUser, PGSubscription, PGCreditPurchase, PGListing, PGUsageLog, PGContact
from shared.database import db
from shared.factory import setup_app
from shared.auth import create_auth_blueprint
from shared.payments import verify_paypal_order, create_paypal_order, capture_paypal_order
from shared.ai_client import call_openai


# ╔══════════════════════════════════════════════════════════════╗
# ║  APP FACTORY                                                 ║
# ╚══════════════════════════════════════════════════════════════╝

def get_launch_price(original_price, annual=False):
    """Return the discounted price if a launch discount is active, else the original.
    Annual plans get an extra discount (30% launch + 10% annual = 40% total)."""
    discount = getattr(Config, "LAUNCH_DISCOUNT", None)
    if discount and discount.get("enabled"):
        pct = discount.get("percent", 0)
        if annual:
            pct += discount.get("annual_extra", 0)
        return round(original_price * (1 - pct / 100), 2)
    return original_price


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
        welcome_message=f"Welcome to Properties Genie! You have {Config.FREE_CREDITS} free listings.",
    )
    app.register_blueprint(auth_bp)

    # ── Jinja2 Filters ────────────────────────────────────────
    @app.template_filter("launch_price")
    def launch_price_filter(value):
        """Jinja2 filter: {{ some_price|launch_price }}"""
        try:
            return get_launch_price(float(value))
        except (TypeError, ValueError):
            return value

    @app.template_filter("launch_price_annual")
    def launch_price_annual_filter(value):
        """Jinja2 filter: {{ some_price|launch_price_annual }} — 40% for annual plans."""
        try:
            return get_launch_price(float(value), annual=True)
        except (TypeError, ValueError):
            return value

    # ── Context Processors ─────────────────────────────────────
    @app.context_processor
    def inject_globals():
        return {
            "site_name": Config.SITE_NAME,
            "site_url": Config.SITE_URL,
            "year": datetime.now(timezone.utc).year,
            "paypal_client_id": Config.PAYPAL_CLIENT_ID,
            "credit_packs": Config.CREDIT_PACKS,
            "subscriptions": Config.SUBSCRIPTIONS,
            "launch_discount": getattr(Config, "LAUNCH_DISCOUNT", {}),
        }

    # ════════════════════════════════════════════════════════════
    #  PUBLIC PAGES
    # ════════════════════════════════════════════════════════════

    @app.route("/")
    def index():
        return render_template("index.html")

    @app.route("/pricing")
    @app.route("/store")
    def store():
        return render_template("store.html")

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
            flash("You've used all your credits. Buy more or upgrade your plan!", "error")
            return redirect(url_for("store"))

        data = {k: request.form.get(k, "") for k in (
            "property_type", "listing_type", "bedrooms", "bathrooms",
            "sqft", "lot_size", "year_built", "price", "address",
            "city", "state", "zip_code", "features",
            "neighborhood_info", "tone", "additional_notes", "language",
        )}

        prompt = _build_prompt(data, include_social=(current_user.plan != 'free'))

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
        social_kit = ai.get("social_media_kit", None)
        marketing = ai.get("marketing_booster", None)

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
            generated_social_kit=json.dumps(social_kit) if social_kit else None,
            generated_marketing=json.dumps(marketing) if marketing else None,
            tokens_used=tokens,
        )
        db.session.add(listing)

        # Consume credit: plan credits first, then bonus credits
        plan_limit = current_user.credit_limit
        if current_user.credits_used < plan_limit:
            current_user.credits_used += 1
        else:
            current_user.bonus_credits = max(0, (current_user.bonus_credits or 0) - 1)

        db.session.add(PGUsageLog(
            user_id=current_user.id, action="generate",
            tokens_used=tokens, model=Config.OPENAI_MODEL,
        ))
        db.session.commit()

        return render_template("result.html", listing=listing, highlights=highlights, social_kit=social_kit, marketing=marketing)

    @app.route("/listing/<int:lid>")
    @login_required
    def view_listing(lid):
        listing = PGListing.query.filter_by(id=lid, user_id=current_user.id).first_or_404()
        hl = json.loads(listing.generated_highlights) if listing.generated_highlights else []
        sk = json.loads(listing.generated_social_kit) if listing.generated_social_kit else None
        mk = json.loads(listing.generated_marketing) if listing.generated_marketing else None
        return render_template("result.html", listing=listing, highlights=hl, social_kit=sk, marketing=mk)

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
    #  PAYMENTS  (server-side PayPal create → capture → verify)
    # ════════════════════════════════════════════════════════════

    @app.route("/checkout/credits/<pack_id>")
    @login_required
    def checkout_credits(pack_id):
        pack = next((p for p in Config.CREDIT_PACKS if p["id"] == pack_id), None)
        if not pack:
            abort(404)
        return render_template("checkout.html", purchase_type="credits", pack=pack)

    @app.route("/checkout/subscription/<sub_key>")
    @login_required
    def checkout_subscription(sub_key):
        sub = Config.SUBSCRIPTIONS.get(sub_key)
        if not sub:
            abort(404)
        is_annual = sub.get("billing") == "annual"
        return render_template("checkout.html", purchase_type="subscription", sub_key=sub_key, sub=sub, is_annual=is_annual)

    # ── Server-side order creation (price set by server, not client) ──

    @app.route("/api/paypal/create-order", methods=["POST"])
    @login_required
    def paypal_create_order():
        data = request.get_json() or {}
        purchase_type = data.get("type", "")
        item_id = data.get("item_id", "")

        if purchase_type == "credits":
            pack = next((p for p in Config.CREDIT_PACKS if p["id"] == item_id), None)
            if not pack:
                return jsonify({"error": "Invalid credit pack"}), 400
            amount = get_launch_price(pack["price"])
            description = f"Properties Genie — {pack['credits']} Credit Pack"
        elif purchase_type == "subscription":
            sub = Config.SUBSCRIPTIONS.get(item_id)
            if not sub:
                return jsonify({"error": "Invalid subscription"}), 400
            is_annual = sub.get("billing") == "annual"
            amount = get_launch_price(sub["price"], annual=is_annual)
            description = f"Properties Genie — {sub['label']}"
        else:
            return jsonify({"error": "Invalid purchase type"}), 400

        order_id, error = create_paypal_order(
            amount, "USD", description,
            client_id=Config.PAYPAL_CLIENT_ID,
            client_secret=Config.PAYPAL_CLIENT_SECRET,
            mode=Config.PAYPAL_MODE,
        )
        if error:
            return jsonify({"error": error}), 500
        return jsonify({"orderID": order_id})

    # ── Server-side capture + fulfilment ──

    @app.route("/api/paypal/capture-order", methods=["POST"])
    @login_required
    def paypal_capture_order():
        data = request.get_json() or {}
        order_id = data.get("orderID", "")
        purchase_type = data.get("type", "")
        item_id = data.get("item_id", "")

        if not order_id:
            return jsonify({"error": "Missing order ID"}), 400

        # ── Credit pack purchase ──
        if purchase_type == "credits":
            pack = next((p for p in Config.CREDIT_PACKS if p["id"] == item_id), None)
            if not pack:
                return jsonify({"error": "Invalid credit pack"}), 400

            # Duplicate check
            existing = PGCreditPurchase.query.filter_by(paypal_order_id=order_id).first()
            if existing:
                return jsonify({
                    "success": True,
                    "credits_added": existing.credits,
                    "total_credits": current_user.credits_remaining,
                    "message": "Credits already added (duplicate detected).",
                })

            captured, info = capture_paypal_order(
                order_id, get_launch_price(pack["price"]),
                client_id=Config.PAYPAL_CLIENT_ID,
                client_secret=Config.PAYPAL_CLIENT_SECRET,
                mode=Config.PAYPAL_MODE,
            )
            if not captured:
                return jsonify({"error": "Payment capture failed. Please contact support."}), 400

            current_user.bonus_credits = (current_user.bonus_credits or 0) + pack["credits"]
            db.session.add(PGCreditPurchase(
                user_id=current_user.id,
                paypal_order_id=order_id,
                pack_id=item_id,
                credits=pack["credits"],
                amount=pack["price"],
            ))
            db.session.commit()

            return jsonify({
                "success": True,
                "credits_added": pack["credits"],
                "total_credits": current_user.credits_remaining,
                "message": f"{pack['credits']} credits added to your account!",
            })

        # ── Subscription purchase ──
        elif purchase_type == "subscription":
            sub = Config.SUBSCRIPTIONS.get(item_id)
            if not sub:
                return jsonify({"error": "Invalid subscription"}), 400

            # Duplicate check
            existing = PGSubscription.query.filter_by(paypal_order_id=order_id).first()
            if existing:
                return jsonify({
                    "success": True, "plan": existing.plan,
                    "message": "Subscription already activated (duplicate detected).",
                })

            captured, info = capture_paypal_order(
                order_id, get_launch_price(sub["price"], annual=(sub.get("billing") == "annual")),
                client_id=Config.PAYPAL_CLIENT_ID,
                client_secret=Config.PAYPAL_CLIENT_SECRET,
                mode=Config.PAYPAL_MODE,
            )
            if not captured:
                return jsonify({"error": "Payment capture failed. Please contact support."}), 400

            is_annual = sub["billing"] == "annual"
            duration = timedelta(days=365) if is_annual else timedelta(days=30)
            now = datetime.now(timezone.utc)

            existing_sub = PGSubscription.query.filter_by(user_id=current_user.id, status="active").first()
            if existing_sub:
                existing_sub.plan = sub["plan"]
                existing_sub.amount = sub["price"]
                existing_sub.paypal_order_id = order_id
                existing_sub.started_at = now
                existing_sub.expires_at = now + duration
            else:
                db.session.add(PGSubscription(
                    user_id=current_user.id, paypal_order_id=order_id,
                    plan=sub["plan"], amount=sub["price"], status="active",
                    started_at=now, expires_at=now + duration,
                ))

            current_user.plan = sub["plan"]
            current_user.billing_cycle = sub["billing"]
            current_user.credits_used = 0
            current_user.credits_reset_at = now
            db.session.commit()

            return jsonify({
                "success": True, "plan": sub["plan"],
                "message": f"Welcome to {sub['label']}! Your credits have been refreshed.",
            })

        return jsonify({"error": "Invalid purchase type"}), 400

    # ════════════════════════════════════════════════════════════
    #  PROGRAMMATIC SEO LANDING PAGES
    # ════════════════════════════════════════════════════════════

    SEO_PAGES = {
        "ai-real-estate-listing-generator": {
            "title": "AI Real Estate Listing Generator — Write Listings in Seconds",
            "description": "Generate professional real estate listings with AI. Our tool creates compelling property descriptions, social media captions, and SEO metadata in under 4 seconds.",
            "h1": "AI Real Estate Listing Generator",
            "content": "Stop wasting hours writing property listings. Properties Genie uses advanced AI to generate professional, compelling real estate descriptions that sell. Enter your property details — bedrooms, bathrooms, square footage, features — and get a polished listing in seconds. Supports 20+ languages, 4 writing tones, and all property types.",
        },
        "ai-property-description-writer": {
            "title": "AI Property Description Writer — Professional Listings Fast",
            "description": "Write stunning property descriptions with AI. Perfect for realtors, agents, and property managers who want professional copy without the hassle.",
            "h1": "AI Property Description Writer",
            "content": "Properties Genie is the #1 AI property description writer used by real estate professionals worldwide. Generate MLS-ready descriptions, social media captions, and marketing copy in one click. Works for houses, apartments, condos, commercial properties, and land.",
        },
        "real-estate-listing-tool-for-agents": {
            "title": "Real Estate Listing Tool for Agents — Save 30+ Minutes Per Listing",
            "description": "The best listing tool for real estate agents. AI-powered descriptions, social media kit, SEO metadata, and email marketing copy. Free to start.",
            "h1": "The #1 Listing Tool for Real Estate Agents",
            "content": "Real estate agents save an average of 30 minutes per listing with Properties Genie. Instead of staring at a blank page, enter your property details and get a professional, ready-to-publish listing in seconds. Includes Instagram, Facebook, and Twitter captions plus SEO optimization.",
        },
        "mls-listing-description-generator": {
            "title": "MLS Listing Description Generator — AI-Powered & Free to Try",
            "description": "Generate MLS-ready property descriptions with AI. Professional quality, instant results. Perfect for agents posting to Zillow, Realtor.com, and MLS.",
            "h1": "MLS Listing Description Generator",
            "content": "Generate polished, MLS-compliant property descriptions in seconds. Properties Genie creates listings optimized for Zillow, Realtor.com, Redfin, and your local MLS. Choose from professional, luxury, friendly, or minimal tones to match every property.",
        },
        "luxury-real-estate-listing-writer": {
            "title": "Luxury Real Estate Listing Writer — Elegant AI-Generated Copy",
            "description": "Create luxurious, aspirational property listings with our AI luxury writing mode. Perfect for high-end homes, estates, and premium properties.",
            "h1": "Luxury Real Estate Listing Writer",
            "content": "Elevate your luxury listings with AI-crafted descriptions that capture elegance and exclusivity. Properties Genie's luxury tone mode creates aspirational copy perfect for high-end homes, penthouses, waterfront estates, and exclusive properties. Impress your most discerning clients.",
        },
        "rental-listing-generator": {
            "title": "Rental Listing Generator — AI-Powered Descriptions for Landlords",
            "description": "Generate professional rental property listings with AI. Perfect for landlords and property managers posting to Zillow, Apartments.com, and Craigslist.",
            "h1": "Rental Listing Generator",
            "content": "Attract quality tenants with professional rental listings. Properties Genie generates compelling descriptions for apartments, houses, condos, and commercial rentals. Highlight amenities, location benefits, and move-in specials — all optimized for rental platforms.",
        },
        "real-estate-social-media-captions": {
            "title": "Real Estate Social Media Captions — AI-Generated Instagram & Facebook Posts",
            "description": "Generate ready-to-post real estate captions for Instagram, Facebook, and Twitter/X. Includes hashtags, CTAs, and engagement-optimized copy.",
            "h1": "Real Estate Social Media Captions Generator",
            "content": "Every Properties Genie listing includes a full social media kit. Get Instagram captions with 20 relevant hashtags, Facebook posts with calls-to-action, and Twitter/X posts under 280 characters. Copy, paste, and post — grow your following while you list.",
        },
        "multilingual-real-estate-listings": {
            "title": "Multilingual Real Estate Listings — Generate in 20+ Languages",
            "description": "Create property listings in Spanish, French, Chinese, Arabic, Portuguese, and 15+ more languages. Reach international buyers with AI-powered translations.",
            "h1": "Generate Listings in 20+ Languages",
            "content": "Reach international buyers in their language. Properties Genie generates native-quality real estate listings in 20+ languages including Spanish, French, Mandarin Chinese, Arabic, Portuguese, German, Japanese, Korean, Italian, Russian, and more. Expand your market instantly.",
        },
        "commercial-property-listing-generator": {
            "title": "Commercial Property Listing Generator — AI Descriptions for CRE",
            "description": "Generate professional commercial real estate listings with AI. Office spaces, retail, warehouses, industrial, and mixed-use properties.",
            "h1": "Commercial Property Listing Generator",
            "content": "Create compelling commercial property listings in seconds. Properties Genie handles office buildings, retail spaces, warehouses, industrial properties, mixed-use developments, and vacant commercial land. Professional tone optimized for commercial real estate buyers and tenants.",
        },
        "real-estate-email-marketing-generator": {
            "title": "Real Estate Email Marketing Generator — AI Property Emails",
            "description": "Generate email subject lines and marketing copy for your property listings. AI-powered email templates that drive showings and offers.",
            "h1": "Real Estate Email Marketing Generator",
            "content": "Every Properties Genie listing can include an email marketing booster: a compelling subject line and 3-4 sentence email body designed to drive showing requests. Plus SEO meta tags and 10 targeted keywords for your listing pages.",
        },
        "zillow-listing-description-generator": {
            "title": "Zillow Listing Description Generator — AI-Powered & Instant",
            "description": "Write better Zillow listing descriptions with AI. Optimized for the Zillow platform, compelling, and ready to copy-paste in seconds.",
            "h1": "Zillow Listing Description Generator",
            "content": "Get Zillow-optimized property descriptions in seconds. Properties Genie creates listings designed to stand out on Zillow, with compelling headlines, sensory language, and clear calls-to-action that drive buyer inquiries.",
        },
        "airbnb-listing-description-generator": {
            "title": "Airbnb Listing Description Generator — Write Better Listings",
            "description": "Generate compelling Airbnb listing descriptions with AI. Highlight amenities, location, and guest experience. Perfect for hosts and property managers.",
            "h1": "Airbnb Listing Description Generator",
            "content": "Create Airbnb listings that attract 5-star guests. Properties Genie crafts compelling descriptions, highlights unique amenities, and emphasizes the guest experience. Works for vacation rentals, short-term stays, and unique accommodations.",
        },
    }

    @app.route("/tools/<slug>")
    def seo_landing(slug):
        """Programmatic SEO landing pages for maximum organic traffic."""
        page = SEO_PAGES.get(slug)
        if not page:
            abort(404)
        return render_template("seo_landing.html", page=page, slug=slug)

    # ════════════════════════════════════════════════════════════
    #  SEO — SITEMAP, ROBOTS, INDEXNOW
    # ════════════════════════════════════════════════════════════

    @app.route("/robots.txt")
    def robots():
        lines = [
            "User-agent: *",
            "Allow: /",
            "",
            "# Private pages",
            "Disallow: /dashboard",
            "Disallow: /account",
            "Disallow: /history",
            "Disallow: /listing/",
            "Disallow: /checkout/",
            "Disallow: /api/",
            "Disallow: /login",
            "Disallow: /register",
            "",
            f"Sitemap: {Config.SITE_URL}/sitemap.xml",
        ]
        return "\n".join(lines) + "\n", 200, {"Content-Type": "text/plain"}

    @app.route("/sitemap.xml")
    def sitemap():
        base = Config.SITE_URL
        pages = [
            ("", "1.0", "weekly"),
            ("pricing", "0.9", "weekly"),
            ("store", "0.8", "weekly"),
            ("about", "0.6", "monthly"),
            ("contact", "0.5", "monthly"),
            ("terms", "0.3", "yearly"),
            ("privacy", "0.3", "yearly"),
        ]
        # Add SEO landing pages
        for slug in SEO_PAGES:
            pages.append((f"tools/{slug}", "0.8", "monthly"))

        xml = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"',
            '        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">',
        ]
        for entry in pages:
            path, priority, freq = entry[0], entry[1], entry[2]
            xml.append(f"  <url>")
            xml.append(f"    <loc>{base}/{path}</loc>")
            xml.append(f"    <priority>{priority}</priority>")
            xml.append(f"    <changefreq>{freq}</changefreq>")
            # Add image for homepage
            if path == "":
                xml.append(f"    <image:image>")
                xml.append(f"      <image:loc>{base}/static/img/og-cover.png</image:loc>")
                xml.append(f"      <image:title>Properties Genie — AI Real Estate Listing Generator</image:title>")
                xml.append(f"    </image:image>")
            xml.append(f"  </url>")
        xml.append("</urlset>")
        resp = make_response("\n".join(xml))
        resp.headers["Content-Type"] = "application/xml"
        return resp

    # ── IndexNow — Auto-submit URLs to Bing/Yandex ─────────
    INDEXNOW_KEY = "pg2026indexnow8f3a5b7c9d"

    @app.route(f"/{INDEXNOW_KEY}.txt")
    def indexnow_key_file():
        return INDEXNOW_KEY, 200, {"Content-Type": "text/plain"}

    def _pg_get_all_urls():
        base = Config.SITE_URL
        urls = [f"{base}/", f"{base}/pricing", f"{base}/store",
                f"{base}/about", f"{base}/contact"]
        for slug in SEO_PAGES:
            urls.append(f"{base}/tools/{slug}")
        return urls

    def _pg_ping_indexnow():
        import requests as req
        urls = _pg_get_all_urls()
        base = Config.SITE_URL
        host = base.replace("https://", "").replace("http://", "")
        payload = {
            "host": host, "key": INDEXNOW_KEY,
            "keyLocation": f"{base}/{INDEXNOW_KEY}.txt",
            "urlList": urls[:10000],
        }
        for engine in ["api.indexnow.org", "www.bing.com", "yandex.com"]:
            try:
                req.post(f"https://{engine}/indexnow", json=payload,
                         headers={"Content-Type": "application/json; charset=utf-8"}, timeout=15)
            except Exception:
                pass

    import threading
    def _pg_startup_ping():
        import time
        time.sleep(10)
        with app.app_context():
            try:
                _pg_ping_indexnow()
                app.logger.info("[IndexNow] Startup ping sent")
            except Exception as e:
                app.logger.warning(f"[IndexNow] Startup ping failed: {e}")
    threading.Thread(target=_pg_startup_ping, daemon=True).start()

    # ═══════════════════════════════════════════════════════════
    #  HIDDEN TEST PURCHASE — Google Ads Conversion Verification
    # ═══════════════════════════════════════════════════════════

    @app.route("/test-purchase-gads-verify")
    def test_purchase_page():
        """Hidden page for verifying Google Ads conversion tracking with a real $0.50 purchase."""
        return render_template("test_purchase.html",
            paypal_client_id=Config.PAYPAL_CLIENT_ID,
            paypal_mode=Config.PAYPAL_MODE,
            gads_id=os.environ.get("GOOGLE_ADS_ID", ""),
            gads_conversion_label=os.environ.get("GOOGLE_ADS_CONVERSION_LABEL", ""),
        )

    @app.route("/api/test-paypal/create-order", methods=["POST"])
    def test_paypal_create_order():
        """Create a $0.50 test PayPal order for conversion verification."""
        order_id, error = create_paypal_order(
            0.50, "USD", "Google Ads Conversion Test — $0.50",
            client_id=Config.PAYPAL_CLIENT_ID,
            client_secret=Config.PAYPAL_CLIENT_SECRET,
            mode=Config.PAYPAL_MODE,
        )
        if error:
            return jsonify({"error": error}), 500
        return jsonify({"orderID": order_id})

    @app.route("/api/test-paypal/capture-order", methods=["POST"])
    def test_paypal_capture_order():
        """Capture a test PayPal order (no credits/subscription added)."""
        data = request.get_json() or {}
        order_id = data.get("orderID", "")
        if not order_id:
            return jsonify({"error": "Missing order ID"}), 400

        captured, info = capture_paypal_order(
            order_id, 0.50,
            client_id=Config.PAYPAL_CLIENT_ID,
            client_secret=Config.PAYPAL_CLIENT_SECRET,
            mode=Config.PAYPAL_MODE,
        )
        if not captured:
            return jsonify({"error": f"Capture failed: {info.get('status', 'unknown')}"}), 400

        app.logger.info(f"[TEST] Conversion test payment captured: {order_id}")
        return jsonify({"success": True, "order_id": order_id})

    return app


# ════════════════════════════════════════════════════════════════
#  PROMPT BUILDER  (platform-specific)
# ════════════════════════════════════════════════════════════════

def _build_prompt(data, include_social=False):
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

    # Language selection
    language = data.get("language", "English") or "English"
    if language != "English":
        parts.append(f"\nIMPORTANT — Output Language: Write the ENTIRE listing (title, description, and highlights) in {language}. Do NOT write in English.")
    else:
        parts.append("\nOutput Language: English")

    social_block = ""
    if include_social:
        social_block = """,
  "social_media_kit": {
    "instagram": "An engaging Instagram caption (2-3 sentences with emojis, then a blank line, then 20 relevant hashtags starting with # separated by spaces)",
    "facebook": "A Facebook post (3-4 sentences, conversational, with a call to action to schedule a showing)",
    "twitter": "A Twitter/X post (max 280 characters, punchy, with 2-3 hashtags)"
  },
  "marketing_booster": {
    "seo_title": "An SEO-optimized title tag for this listing page (50-60 characters, include location and property type)",
    "seo_description": "An SEO meta description optimized for Google search (150-160 characters, compelling, include key selling points)",
    "keywords": ["keyword1", "keyword2", "keyword3", "keyword4", "keyword5", "keyword6", "keyword7", "keyword8", "keyword9", "keyword10"],
    "email_subject": "A compelling email subject line to promote this listing (max 60 characters, use urgency or curiosity)",
    "email_body": "A 3-4 sentence email body promoting this listing with a call to action to schedule a viewing"
  }"""

    parts.append(f"""
Please respond with valid JSON containing:
{{
  "title": "An eye-catching listing headline (max 15 words)",
  "description": "A compelling 2-4 paragraph listing description (200-400 words). Include sensory language, highlight key features, and create urgency.",
  "highlights": ["Feature 1", "Feature 2", "Feature 3", "Feature 4", "Feature 5"]{social_block}
}}

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
