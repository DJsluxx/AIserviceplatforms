"""
Shared — Flask App Factory Helpers
====================================
Common setup (login manager, CORS, credit reset middleware, error handlers)
that every platform needs. Keeps each platform's app.py lean.

Usage:
    from shared.factory import setup_app
    app = Flask(__name__)
    setup_app(app, user_model=PGUser, config=PlatformConfig)
"""

from datetime import datetime, timezone

from flask_login import LoginManager, current_user
from flask_cors import CORS

from shared.database import db, init_db


def setup_app(app, *, user_model, config_class):
    """
    Apply shared configuration and middleware to a Flask app.
    Call this right after creating the Flask instance.
    """
    # Config
    app.config.from_object(config_class)
    app.config["SQLALCHEMY_DATABASE_URI"] = config_class._build_db_url()

    # Extensions
    CORS(app)
    init_db(app)

    # Login manager
    login_manager = LoginManager()
    login_manager.login_view = "auth.login"
    login_manager.login_message_category = "info"
    login_manager.init_app(app)

    @login_manager.user_loader
    def load_user(user_id):
        return user_model.query.get(int(user_id))

    # Monthly credit reset
    @app.before_request
    def reset_monthly_credits():
        if current_user.is_authenticated:
            now = datetime.now(timezone.utc)
            reset = current_user.credits_reset_at
            if reset and (now - reset).days >= 30:
                current_user.credits_used = 0
                current_user.credits_reset_at = now
                db.session.commit()

    # Common error handlers
    from flask import render_template

    @app.errorhandler(404)
    def not_found(e):
        return render_template("errors/404.html"), 404

    @app.errorhandler(500)
    def server_error(e):
        return render_template("errors/500.html"), 500

    return app
