"""
Shared — Auth Blueprint Factory
================================
Creates a reusable Flask blueprint that handles register / login / logout.
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

from datetime import datetime, timezone

from flask import Blueprint, render_template, request, redirect, url_for, flash
from flask_login import login_user, logout_user, login_required, current_user
from werkzeug.security import generate_password_hash, check_password_hash


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
    Returns a Blueprint with /register, /login, /logout routes.
    Templates are platform-specific (looked up from the platform's template folder).
    """
    bp = Blueprint("auth", __name__)

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

            user = user_model(
                email=email,
                name=name,
                password_hash=generate_password_hash(password),
                plan="free",
                credits_used=0,
                credits_reset_at=datetime.now(timezone.utc),
            )
            db.session.add(user)
            db.session.commit()
            login_user(user)

            msg = welcome_message or f"Welcome to {site_name}! You have {free_credits} free credits."
            flash(msg, "success")
            return redirect(url_for("dashboard"))

        return render_template(register_template)

    @bp.route("/login", methods=["GET", "POST"])
    def login():
        if current_user.is_authenticated:
            return redirect(url_for("dashboard"))

        if request.method == "POST":
            email = request.form.get("email", "").strip().lower()
            password = request.form.get("password", "")
            user = user_model.query.filter_by(email=email).first()

            if user and check_password_hash(user.password_hash, password):
                login_user(user, remember=True)
                next_page = request.args.get("next")
                return redirect(next_page or url_for("dashboard"))
            else:
                flash("Invalid email or password.", "error")

        return render_template(login_template)

    @bp.route("/logout")
    @login_required
    def logout():
        logout_user()
        flash("You've been logged out.", "info")
        return redirect(url_for("index"))

    return bp
