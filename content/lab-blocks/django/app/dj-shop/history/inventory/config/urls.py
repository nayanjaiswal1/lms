from django.contrib import admin
from django.urls import include, path
from rest_framework.authtoken.views import obtain_auth_token

from config.extensions import url_modules
from core import views as core_views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("healthz/", core_views.healthz, name="healthz"),
    path("readyz/", core_views.readyz, name="readyz"),
    path("api/csrf/", core_views.csrf_token, name="csrf-token"),
    path("api/auth/token/", obtain_auth_token, name="auth-token"),
    path("api/", include("customers.api_urls")),
    path("api/", include("catalog.api_urls")),
    path("api/", include("inventory.api_urls")),
    path("accounts/", include("customers.urls")),
    path("", include("catalog.urls")),
]

urlpatterns += [path("", include(module)) for module in url_modules()]
