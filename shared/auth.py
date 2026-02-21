"""
Shared — Auth Blueprint Factory
================================
Creates a reusable Flask blueprint that handles:
  - Email/password register / login / logout
  - Google OAuth sign-in (one-click)
  - Email verification to prevent abuse

Each platform calls create_auth_blueprint() with its own User model.

Usage:
    from shared.auth import create_auth_blueprint
    auth_bp = create_auth_blueprint(
        user_model=PGUser,
        db=db,
        site_name="Properties Genie",
        free_credits=3,
        welcome_message="Welcome! You have 3 free descriptions.",
    )
    app.register_blueprint(auth_bp)
"""

import secrets
from datetime import datetime, timezone

from flask import Blueprint, render_template, request, redirect, url_for, flash, session, current_app
from flask_login import login_user, logout_user, login_required, current_user
from werkzeug.security import generate_password_hash, check_password_hash
from authlib.integrations.flask_client import OAuth

# Single OAuth instance — configured per-app in create_auth_blueprint
oauth = OAuth()


def create_auth_blueprint(
    *,
    user_model,
    db,
    site_name="AI Platform",
    free_credits=3,
    welcome_message=None,
    login_template="login.html",
    register_template="register.html",
):
    """
    Returns a Blueprint with /register, /login, /logout, /auth/google, /auth/google/callback.
    """
    bp = Blueprint("auth", __name__)

    # ── Email/Password Register ─────────────────────────────
    @bp.route("/register", methods=["GET", "POST"])
    def register():
        if current_user.is_authenticated:
            return redirect(url_for("dashboard"))

        if request.method == "POST":
            name = request.form.get("name", "").strip()
            email = request.form.get("email", "").strip().lower()
            password = request.form.get("password", "")
            confirm = request.form.get("confirm_password", "")

            if not email or not password:
                flash("Email and password are required.", "error")
                return redirect(url_for("auth.register"))
            if password != confirm:
                flash("Passwords don't match.", "error")
                return redirect(url_for("auth.register"))
            if len(password) < 6:
                flash("Password must be at least 6 characters.", "error")
                return redirect(url_for("auth.register"))
            if user_model.query.filter_by(email=email).first():
                flash("An account with this email already exists.", "error")
                return redirect(url_for("auth.register"))

            verify_token = secrets.token_urlsafe(32)
            user = user_model(
                email=email,
                name=name,
                password_hash=generate_password_hash(password),
                plan="free",
                credits_used=0,
                email_verified=False,
                email_verify_token=verify_token,
                credits_reset_at=datetime.now(timezone.utc),
            )
            db.session.add(user)
            db.session.commit()
            login_user(user)

            # Send verification email (best-effort)
            _send_verification_email(user, site_name)

            flash(
                "Account created! Please check your email to verify your address and unlock your free credit.",
                "success",
            )
            return redirect(url_for("dashboard"))

        return render_template(register_template)

    # ── Email Verification ──────────────────────────────────
    @bp.route("/verify-email/<token>")
    def verify_email(token):
        user = user_model.query.filter_by(email_verify_token=token).first()
        if not user:
            flash("Invalid or expired verification link.", "error")
            return redirect(url_for("index"))
        if user.email_verified:
            flash("Your email is already verified.", "info")
            return redirect(url_for("dashboard"))

        user.email_verified = True
        user.email_verify_token = None
        db.session.commit()

        if current_user.is_authenticated and current_user.id == user.id:
            pass  # already logged in
        else:
            login_user(user)

        flash(f"Email verified! You now have {free_credits} free credit(s). Enjoy!", "success")
        return redirect(url_for("dashboard"))

    @bp.route("/resend-verification")
    @login_required
    def resend_verification():
        if current_user.email_verified:
            flash("Your email is already verified.", "info")
            return redirect(url_for("dashboard"))
        token = secrets.token_urlsafe(32)
        current_user.email_verify_token = token
        db.session.commit()
        _send_verification_email(current_user, site_name)
        flash("Verification email resent. Check your inbox!", "success")
        return redirect(url_for("dashboard"))

    # ── Email/Password Login ────────────────────────────────
    @bp.route("/login", methods=["GET", "POST"])
    def login():
        if current_user.is_authenticated:
            return redirect(url_for("dashboard"))

        if request.method == "POST":
            email = request.form.get("email", "").strip().lower()
            password = request.form.get("password", "")
            user = user_model.query.filter_by(email=email).first()

            if user and user.password_hash and check_password_hash(user.password_hash, password):
                login_user(user, remember=True)
                next_page = request.args.get("next")
                return redirect(next_page or url_for("dashboard"))
            else:
                flash("Invalid email or password.", "error")

        return render_template(login_template)

    # ── Logout ──────────────────────────────────────────────
    @bp.route("/logout")
    @login_required
    def logout():
        logout_user()
        flash("You've been logged out.", "info")
        return redirect(url_for("index"))

    # ── Google OAuth ────────────────────────────────────────
    @bp.route("/auth/google")
    def google_login():
        """Redirect user to Google's OAuth consent screen."""
        google = oauth.create_client("google")
        if not google:
            flash("Google login is not configured.", "error")
            return redirect(url_for("auth.login"))
        redirect_uri = url_for("auth.google_callback", _external=True)
        return google.authorize_redirect(redirect_uri)

    @bp.route("/auth/google/callback")
    def google_callback():
        """Handle the callback from Google after user consents."""
        google = oauth.create_client("google")
        if not google:
            flash("Google login is not configured.", "error")
            return redirect(url_for("auth.login"))

        try:
            token = google.authorize_access_token()
        except Exception as e:
            current_app.logger.error(f"Google OAuth error: {e}")
            flash("Google sign-in failed. Please try again.", "error")
            return redirect(url_for("auth.login"))

        # Get user info from Google
        user_info = token.get("userinfo")
        if not user_info:
            user_info = google.userinfo()

        google_id = user_info.get("sub")
        email = user_info.get("email", "").lower()
        name = user_info.get("name", "")
        avatar = user_info.get("picture", "")

        if not email:
            flash("Could not retrieve email from Google.", "error")
            return redirect(url_for("auth.login"))

        # Check if user exists by google_id first, then by email
        user = user_model.query.filter_by(google_id=google_id).first()

        if not user:
            # Check if email already registered (e.g. via email/password)
            user = user_model.query.filter_by(email=email).first()
            if user:
                # Link Google account to existing user
                user.google_id = google_id
                user.avatar_url = avatar or user.avatar_url
                if not user.name and name:
                    user.name = name
                db.session.commit()
            else:
                # Brand new user via Google — email already verified by Google
                user = user_model(
                    email=email,
                    name=name,
                    google_id=google_id,
                    avatar_url=avatar,
                    password_hash=None,
                    plan="free",
                    credits_used=0,
                    email_verified=True,
                    credits_reset_at=datetime.now(timezone.utc),
                )
                db.session.add(user)
                db.session.commit()

                msg = welcome_message or f"Welcome to {site_name}! You have {free_credits} free credits."
                flash(msg, "success")

        login_user(user, remember=True)
        return redirect(url_for("dashboard"))

    # ── Register OAuth with app on first request ────────────
    @bp.record_once
    def _init_oauth(state):
        app = state.app
        client_id = app.config.get("GOOGLE_CLIENT_ID")
        client_secret = app.config.get("GOOGLE_CLIENT_SECRET")
        if client_id and client_secret:
            oauth.init_app(app)
            oauth.register(
                name="google",
                client_id=client_id,
                client_secret=client_secret,
                server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
                client_kwargs={"scope": "openid email profile"},
            )

    return bp


def _send_verification_email(user, site_name):
    """Send a verification email in a background thread so the request returns instantly."""
    import logging
    import threading
    logger = logging.getLogger(__name__)
    try:
        from flask import current_app, url_for

        app = current_app._get_current_object()
        if not app.config.get("MAIL_SERVER"):
            logger.info("MAIL_SERVER not configured — skipping verification email for %s", user.email)
            return

        # Build everything we need while still inside the request context
        verify_url = url_for("auth.verify_email", token=user.email_verify_token, _external=True)
        sender = app.config.get("MAIL_DEFAULT_SENDER", f"noreply@{site_name.lower().replace(' ', '')}.com")
        recipient = user.email
        html_body = (
            f"<h2>Welcome to {site_name}!</h2>"
            f"<p>Click the link below to verify your email and activate your free credit:</p>"
            f'<p><a href="{verify_url}" style="display:inline-block;padding:12px 28px;'
            f'background:#7c3aed;color:#fff;text-decoration:none;border-radius:8px;'
            f'font-weight:600;">Verify My Email</a></p>'
            f"<p>Or copy this link: {verify_url}</p>"
            f"<p>If you didn't create an account, you can ignore this email.</p>"
        )

        def _send_in_background(app, recipient, sender, html_body, site_name):
            try:
                from flask_mail import Mail, Message as MailMessage
                with app.app_context():
                    mail = Mail(app)
                    msg = MailMessage(
                        subject=f"Verify your {site_name} email",
                        sender=sender,
                        recipients=[recipient],
                        html=html_body,
                    )
                    mail.send(msg)
                    logger.info("Verification email sent to %s", recipient)
            except Exception as e:
                logger.warning("Could not send verification email to %s: %s", recipient, e)

        thread = threading.Thread(
            target=_send_in_background,
            args=(app, recipient, sender, html_body, site_name),
            daemon=True,
        )
        thread.start()
    except Exception as e:
        logger.warning("Could not prepare verification email for %s: %s", user.email, e)
