from django.db import connection
from django.http import JsonResponse
from django.middleware.csrf import get_token
from django.views.decorators.http import require_GET


@require_GET
def healthz(request):
    """Liveness: the process is up. Does not touch the database."""
    return JsonResponse({"status": "ok"})


@require_GET
def readyz(request):
    """Readiness: the database answers; reports which engine is in use."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception:
        return JsonResponse({"status": "unavailable"}, status=503)
    return JsonResponse({"status": "ok", "database": connection.vendor})


@require_GET
def csrf_token(request):
    """SPA bootstrap: returns the CSRF token and sets the csrftoken cookie."""
    return JsonResponse({"csrfToken": get_token(request)})
