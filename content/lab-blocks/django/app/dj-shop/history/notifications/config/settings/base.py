"""Settings shared by every environment. Environment specifics live in dev/prod/test."""

from pathlib import Path

from config.extensions import installed_apps

from .env import database_from_url, env_bool, env_int, env_str, require_env

BASE_DIR = Path(__file__).resolve().parent.parent.parent

SECRET_KEY = require_env("DJANGO_SECRET_KEY")
DEBUG = False
ALLOWED_HOSTS = ["*"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework.authtoken",
    "core",
    "customers",
    "catalog",
    "inventory",
    "cart",
    "notifications",
]
INSTALLED_APPS += installed_apps()

AUTH_USER_MODEL = "customers.Customer"

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    # mf:slot settings.middleware.static
    "whitenoise.middleware.WhiteNoiseMiddleware",
    # mf:endslot
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    # mf:slot settings.middleware.auth
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "core.middleware.RequestContextMiddleware",
    # mf:endslot
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "core.context_processors.current_customer",
            ],
        },
    },
]

# mf:slot settings.database
DATABASES = {"default": database_from_url(require_env("DATABASE_URL"))}
# mf:endslot

# mf:slot settings.database.connection
DATABASES["default"]["CONN_MAX_AGE"] = env_int("DB_CONN_MAX_AGE", 60)
DATABASES["default"]["CONN_HEALTH_CHECKS"] = True
# mf:endslot

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = @@mf:value settings.time_zone="America/New_York"@@
USE_I18N = False
USE_TZ = @@mf:value settings.use_tz=True@@

# mf:slot settings.static
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"]
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}
# mf:endslot

# mf:slot settings.cache
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": env_str("REDIS_URL", "redis://127.0.0.1:6379/1"),
        "KEY_PREFIX": "shop",
    }
}
# mf:endslot

# mf:slot settings.rest_framework
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.SessionAuthentication",
        "rest_framework.authentication.TokenAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticatedOrReadOnly"],
    "DEFAULT_PAGINATION_CLASS": "core.pagination.StandardPagination",
    "PAGE_SIZE": 25,
}
# mf:endslot

LOGIN_URL = "/accounts/login/"
LOGIN_REDIRECT_URL = "/"

# Celery (broker is Redis; tasks are defined in each app's tasks.py)
CELERY_BROKER_URL = env_str("CELERY_BROKER_URL", "redis://127.0.0.1:6379/0")
CELERY_TASK_ACKS_LATE = True
CELERY_TASK_ALWAYS_EAGER = env_bool("CELERY_TASK_ALWAYS_EAGER", False)
CELERY_TASK_TIME_LIMIT = 60

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
DEFAULT_FROM_EMAIL = "Shop <orders@shop.mindforge.test>"

# Business configuration
SALES_TAX_RATE = env_str("SALES_TAX_RATE", "0.0825")
CURRENCY = "USD"
LOW_STOCK_THRESHOLD = env_int("LOW_STOCK_THRESHOLD", 5)
DEFAULT_WAREHOUSE_CODE = "MAIN"
PAYMENTS_BASE_URL = require_env("PAYMENTS_BASE_URL")
PAYMENTS_TIMEOUT = (2, 5)  # (connect, read) seconds
WEBHOOK_SECRET = require_env("WEBHOOK_SECRET")
