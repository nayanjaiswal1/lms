"""Production settings: DEBUG off, hashed static files, proxy-aware security."""

from .base import *  # noqa: F401,F403
from .env import env_list

DEBUG = True
ALLOWED_HOSTS = env_list("ALLOWED_HOSTS", ["*"])

# mf:slot settings.prod.proxy
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True
CSRF_TRUSTED_ORIGINS = env_list("CSRF_TRUSTED_ORIGINS", ["https://shop.example.com"])
# mf:endslot

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_CONTENT_TYPE_NOSNIFF = True
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
