import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent
REPO_DIR = BASE_DIR.parent


def env_bool(name: str, default: bool = False) -> bool:
    return os.environ.get(name, "1" if default else "0") == "1"


DEBUG = env_bool("SCAMSAATHI_DEBUG")
SECRET_KEY = os.environ.get("SCAMSAATHI_SECRET_KEY", "")
if not SECRET_KEY:
    if not DEBUG:
        raise ImproperlyConfigured("Set SCAMSAATHI_SECRET_KEY (or SCAMSAATHI_DEBUG=1 for local development)")
    SECRET_KEY = "dev-only-not-a-secret"

# localhost is always allowed so container health checks work; real hostnames come from the environment
ALLOWED_HOSTS = ["localhost", "127.0.0.1"] + [h for h in os.environ.get("SCAMSAATHI_ALLOWED_HOSTS", "").split(",") if h]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "intel",
    "orgs",
    "dashboard",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",  # serves the admin's static files from the container
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "scamsaathi_api.urls"
WSGI_APPLICATION = "scamsaathi_api.wsgi.application"

TEMPLATES = [{
    "BACKEND": "django.template.backends.django.DjangoTemplates",
    "DIRS": [],
    "APP_DIRS": True,
    "OPTIONS": {"context_processors": [
        "django.template.context_processors.request",
        "django.contrib.auth.context_processors.auth",
        "django.contrib.messages.context_processors.messages",
    ]},
}]

DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3",
                         "NAME": os.environ.get("SCAMSAATHI_DB", str(BASE_DIR / "db.sqlite3"))}}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 12}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
]

LANGUAGE_CODE = "en"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {"BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage"},
}
WHITENOISE_USE_FINDERS = True      # serve the dashboard's files straight from the app, no collectstatic needed in development or tests
WHITENOISE_AUTOREFRESH = DEBUG
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],  # deny by default
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    "UNAUTHENTICATED_USER": None,
}

# Rule packs: signed offline by a maintainer, served as-is. The private key is never on the server.
PACKS_DIR = Path(os.environ.get("SCAMSAATHI_PACKS_DIR", REPO_DIR / "packs" / "core"))
PACK_PUBLIC_KEY = Path(os.environ.get("SCAMSAATHI_PACK_PUBLIC_KEY", REPO_DIR / "packs" / "keys" / "release.pub"))

REPORT_QUORUM = 3          # distinct reporters before an indicator is confirmed (a verified organisation counts as all of them)
FEED_PAGE_SIZE = 5000

# the admin site behind an HTTPS proxy needs the public origin, e.g. https://api.example.org
CSRF_TRUSTED_ORIGINS = [o for o in os.environ.get("SCAMSAATHI_CSRF_TRUSTED_ORIGINS", "").split(",") if o]

if not DEBUG:
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_SSL_REDIRECT = env_bool("SCAMSAATHI_SSL_REDIRECT")
    SECURE_REDIRECT_EXEMPT = [r"^healthz$"]  # the container health check talks plain HTTP to itself
    if env_bool("SCAMSAATHI_BEHIND_PROXY"):
        SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
